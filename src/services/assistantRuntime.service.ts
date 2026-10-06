import uuid from 'react-native-uuid';

import {
  ChatMode,
  isCloudModel,
  LiveTalkPhase,
  LlmPhase,
  MicOwner,
  RequestOrigin,
  SttPhase,
  TtsPhase,
} from '@/constants';
import { useAssistantStore } from '@/stores/assistant.store';
import { useChatStore } from '@/stores/chat.store';
import { useModelStore } from '@/stores/model.store';
import { useSettingsStore } from '@/stores/settings.store';
import { useVoiceStore } from '@/stores/voice.store';

import { ChatSessionService } from './chat.service';
import {
  buildConversationContext,
  ContextMessage,
} from './conversation.service';
import { liveTalkService } from './liveTalk.service';
import { modelDownloadService } from './model.service';
import {
  LlmMessage,
  pickLlmProvider,
  sttProvider,
  ttsProvider,
} from './providers';
import { settingsService } from './settings.service';
import { VoiceModelMissingError } from './speechRuntime.service';

let activeLlmHandle: { cancel: () => void } | null = null;

let activeSttRequestId: string | null = null;
let activeTtsRequestId: string | null = null;
let activeTtsMessageId: string | null = null;
let ttsEventSubscribed = false;
let sttLevelSmoothed = 0;

let liveTalkConfigured = false;
let liveTalkTurnRunId: string | null = null;
let liveTalkSessionId: string | null = null;
let liveTalkResponseAcc = '';

function ensureTtsEventSubscription(): void {
  if (ttsEventSubscribed) return;
  ttsEventSubscribed = true;
  ttsProvider.subscribe((event) => {
    if (event.requestId !== activeTtsRequestId) {
      console.warn({
        eventRequestId: event.requestId,
        activeTtsRequestId,
      });
      return;
    }

    const current = useAssistantStore.getState();

    switch (event.kind) {
      case 'started':
        current.setTtsPhase(TtsPhase.SPEAKING);
        break;
      case 'paused':
        current.setTtsPhase(TtsPhase.PAUSED);
        break;
      case 'resumed':
        current.setTtsPhase(TtsPhase.SPEAKING);
        break;
      case 'completed':
      case 'stopped':
        activeTtsRequestId = null;
        activeTtsMessageId = null;
        current.setTtsPhase(TtsPhase.IDLE);
        current.setCurrentTtsMessageId(null);
        break;
      case 'error':
        activeTtsRequestId = null;
        activeTtsMessageId = null;
        current.setError(event.message);
        current.setTtsPhase(TtsPhase.ERROR);
        current.setCurrentTtsMessageId(null);
        break;
    }
  });
}

function openVoiceModalForMissingModel(): void {
  useVoiceStore.getState().setVoiceModalOpen(true);
}

export async function submitPrompt(options: {
  text: string;
  origin: RequestOrigin;
  modelId: string;
  sessionId?: string | null;
  msgId?: string | null;
}): Promise<void> {
  const {
    text,
    origin,
    modelId,
    sessionId: incomingSessionId,
    msgId: incomingMsgId,
  } = options;
  const trimmed = text.trim();

  if (!trimmed) {
    return;
  }

  const store = useAssistantStore.getState();

  if (store.llmPhase !== LlmPhase.IDLE && store.llmPhase !== LlmPhase.ERROR) {
    return;
  }

  try {
    const runId = store.startRun(origin);

    store.setLlmPhase(LlmPhase.SUBMITTING);
    store.setDraftText('');
    store.setTranscript('');

    let sessionId = incomingSessionId ?? useChatStore.getState().chatSessionId;

    if (!sessionId) {
      const session = await ChatSessionService.createNewChat(
        trimmed.slice(0, 60),
      );
      sessionId = session.id;
    } else {
      const currentSession = useChatStore
        .getState()
        .sessions.find((s) => s.id === sessionId);
      if (
        currentSession &&
        (currentSession.title === 'New Chat' || !currentSession.title.trim())
      ) {
        await ChatSessionService.renameChat(sessionId, trimmed.slice(0, 60));
      }
    }

    const userMessageId = incomingMsgId || String(uuid.v4());
    const now = Date.now();

    await ChatSessionService.saveMessage({
      sessionId,
      role: 'user',
      content: trimmed,
      customId: userMessageId,
      createdAt: now,
      runId,
    });

    useChatStore.getState().upsertMessage({
      id: userMessageId,
      sessionId,
      role: 'user',
      text: trimmed,
      createdAt: now,
      status: 'sent',
      runId,
    });

    const historical = useChatStore.getState().messages.map((m) => ({
      role: m.role as 'user' | 'assistant',
      text: m.text,
    }));

    const { userName, customInstructions } = useSettingsStore.getState();

    const context: ContextMessage[] = buildConversationContext({
      messages: historical,
      userName,
      customInstructions,
    });

    const messages: LlmMessage[] = context.map((m) => ({
      role: m.role,
      content: m.content,
    }));

    const modelPath =
      await modelDownloadService.getDownloadedModelPath(modelId);

    store.setLlmPhase(LlmPhase.THINKING);

    const provider = pickLlmProvider(modelId);

    activeLlmHandle = provider.generate(
      {
        requestId: runId,
        messages,
        modelId,
        modelPath: modelPath ?? undefined,
      },
      {
        onDelta: (chunk: string) => {
          const current = useAssistantStore.getState();
          if (current.assistantRunId !== runId) return;

          if (current.llmPhase !== LlmPhase.GENERATING) {
            current.setLlmPhase(LlmPhase.GENERATING);
          }

          current.appendResponse(chunk);
          useChatStore
            .getState()
            .appendMessageChunk(current.assistantRunId!, chunk, runId);
        },

        onComplete: (fullText: string) => {
          const current = useAssistantStore.getState();
          if (current.assistantRunId !== runId) return;

          const assistantMessageId = current.assistantRunId!;
          const ts = Date.now();

          ChatSessionService.saveMessage({
            sessionId: sessionId!,
            role: 'assistant',
            content: fullText,
            customId: assistantMessageId,
            createdAt: ts,
            runId,
          }).catch((err) =>
            console.error(
              '[Runtime] Failed to persist assistant message:',
              err,
            ),
          );

          useChatStore
            .getState()
            .completeMessageStream(assistantMessageId, fullText, ts, runId);

          current.setLlmPhase(LlmPhase.IDLE);
          activeLlmHandle = null;
        },

        onError: (error: Error) => {
          const current = useAssistantStore.getState();
          if (current.assistantRunId !== runId) return;

          current.setError(error.message);
          current.setLlmPhase(LlmPhase.ERROR);

          setTimeout(() => {
            const s = useAssistantStore.getState();
            if (s.llmPhase === LlmPhase.ERROR) {
              s.setLlmPhase(LlmPhase.IDLE);
            }
          }, 2000);

          activeLlmHandle = null;
        },
      },
    );
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'An unexpected error occurred.';
    const current = useAssistantStore.getState();
    current.setError(message);
    current.setLlmPhase(LlmPhase.ERROR);

    setTimeout(() => {
      const s = useAssistantStore.getState();
      if (s.llmPhase === LlmPhase.ERROR) {
        s.setLlmPhase(LlmPhase.IDLE);
      }
    }, 2000);
  }
}

export function cancelRun(): void {
  if (activeLlmHandle) {
    activeLlmHandle.cancel();
    activeLlmHandle = null;
  }

  const store = useAssistantStore.getState();
  store.setLlmPhase(LlmPhase.IDLE);
}

export async function startDictation(): Promise<void> {
  const store = useAssistantStore.getState();
  if (
    store.sttPhase === SttPhase.LISTENING ||
    store.sttPhase === SttPhase.TRANSCRIBING
  ) {
    return;
  }

  store.setChatMode(ChatMode.DICTATION);
  store.setSttPhase(SttPhase.LISTENING);
  store.setMic(MicOwner.STT);
  sttLevelSmoothed = 0;

  try {
    const requestId = await sttProvider.startListening({
      onPartial: (text, requestId) => {
        const current = useAssistantStore.getState();
        if (requestId !== activeSttRequestId) return;
        if (current.sttPhase !== SttPhase.LISTENING) return;
        current.setTranscript(text);
      },
      onAudioLevel: (level, requestId) => {
        if (requestId !== activeSttRequestId) return;
        sttLevelSmoothed += (level - sttLevelSmoothed) * 0.45;
        const current = useAssistantStore.getState();
        if (current.sttPhase !== SttPhase.LISTENING) return;
        current.setMic(MicOwner.STT, sttLevelSmoothed);
      },
      onError: (message, fatal) => {
        const current = useAssistantStore.getState();
        current.setError(message);
        if (!fatal) return;
        // Capture died: release native state and reset the UI exactly like
        // the start failure path does.
        activeSttRequestId = null;
        sttLevelSmoothed = 0;
        current.setSttPhase(SttPhase.ERROR);
        current.setChatMode(ChatMode.TEXTING);
        current.setMic(MicOwner.NONE);
        sttProvider.cancelListening().catch(() => {});
      },
    });
    if (useAssistantStore.getState().sttPhase === SttPhase.ERROR) {
      // onError fired while startListening was resolving; the session has
      // already been torn down.
      activeSttRequestId = null;
      sttLevelSmoothed = 0;
      return;
    }
    activeSttRequestId = requestId;
  } catch (error: any) {
    activeSttRequestId = null;
    sttLevelSmoothed = 0;
    const store = useAssistantStore.getState();
    if (error instanceof VoiceModelMissingError) {
      openVoiceModalForMissingModel();
      store.setSttPhase(SttPhase.IDLE);
      store.setChatMode(ChatMode.TEXTING);
      store.setMic(MicOwner.NONE);
      return;
    }
    const message =
      error instanceof Error ? error.message : 'Failed to start dictation.';
    store.setError(message);
    store.setSttPhase(SttPhase.ERROR);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);
  }
}

export async function cancelDictation(): Promise<void> {
  const requestId = activeSttRequestId;
  activeSttRequestId = null;

  try {
    await sttProvider.cancelListening();
  } catch (e) {
    console.warn('[Runtime] cancelDictation native cleanup failed', e);
  }

  const store = useAssistantStore.getState();
  if (requestId === null && store.sttPhase === SttPhase.IDLE) return;

  store.setSttPhase(SttPhase.IDLE);
  store.setChatMode(ChatMode.TEXTING);
  store.setMic(MicOwner.NONE);
  store.setDraftText('');
  store.setTranscript('');
}

export async function stopDictation(): Promise<string> {
  const store = useAssistantStore.getState();
  if (store.sttPhase !== SttPhase.LISTENING) {
    return '';
  }
  const requestId = activeSttRequestId;

  store.setSttPhase(SttPhase.TRANSCRIBING);

  try {
    const result = await sttProvider.stopListening();
    // Stale guard: ignore results from an operation that is no longer active.
    if (requestId !== null && result.requestId !== requestId) {
      return '';
    }
    activeSttRequestId = null;

    const trimmed = result.text.trim();
    const current = useAssistantStore.getState();
    if (trimmed) {
      current.setTranscript(trimmed);
      current.setDraftText(trimmed);
    } else {
      current.setTranscript('');
    }

    current.setSttPhase(SttPhase.IDLE);
    current.setChatMode(ChatMode.TEXTING);
    current.setMic(MicOwner.NONE);
    return trimmed;
  } catch (error: any) {
    activeSttRequestId = null;
    const message =
      error instanceof Error ? error.message : 'Failed to stop dictation.';
    const current = useAssistantStore.getState();

    current.setError(message);
    current.setSttPhase(SttPhase.ERROR);
    current.setChatMode(ChatMode.TEXTING);
    current.setMic(MicOwner.NONE);
    return '';
  }
}

export async function sendDictation(options?: {
  sessionId?: string | null;
  msgId?: string | null;
}): Promise<void> {
  const store = useAssistantStore.getState();
  if (store.sttPhase !== SttPhase.LISTENING) {
    return;
  }
  const requestId = activeSttRequestId;

  store.setSttPhase(SttPhase.TRANSCRIBING);

  try {
    const result = await sttProvider.stopListening();
    // Stale guard: never submit a transcript from a superseded operation.
    if (requestId !== null && result.requestId !== requestId) {
      return;
    }
    activeSttRequestId = null;

    const transcript = result.text.trim();

    if (!transcript) {
      const current = useAssistantStore.getState();
      current.setTranscript('');
      current.setSttPhase(SttPhase.IDLE);
      current.setChatMode(ChatMode.TEXTING);
      current.setMic(MicOwner.NONE);
      return;
    }

    const current = useAssistantStore.getState();
    current.setTranscript(transcript);
    current.setSttPhase(SttPhase.IDLE);
    current.setChatMode(ChatMode.TEXTING);
    current.setMic(MicOwner.NONE);

    const modelId = useModelStore.getState().selectedModelId;
    const sessionId =
      options?.sessionId ?? useChatStore.getState().chatSessionId;
    const msgId = options?.msgId || String(uuid.v4());

    await submitPrompt({
      text: transcript,
      origin: RequestOrigin.MANUAL_DICTATION,
      modelId,
      sessionId,
      msgId,
    });
  } catch (error: any) {
    activeSttRequestId = null;
    const message =
      error instanceof Error ? error.message : 'Failed to send dictation.';
    const current = useAssistantStore.getState();

    current.setError(message);
    current.setSttPhase(SttPhase.ERROR);
    current.setChatMode(ChatMode.TEXTING);
    current.setMic(MicOwner.NONE);
  }
}

// ---------------------------------------------------------------------------
// Live Talk (native real-time loop; this file remains the only phase writer)
// ---------------------------------------------------------------------------

const NATIVE_TO_LIVE_TALK_PHASE: Record<string, LiveTalkPhase | null> = {
  idle: null,
  listening: LiveTalkPhase.LISTENING,
  user_speaking: LiveTalkPhase.USER_SPEAKING,
  processing: LiveTalkPhase.PROCESSING,
  thinking: LiveTalkPhase.THINKING,
  speaking: LiveTalkPhase.SPEAKING,
  interrupted: LiveTalkPhase.INTERRUPTED,
  paused: LiveTalkPhase.PAUSED,
};

function buildLiveTalkContext(): ContextMessage[] {
  const historical = useChatStore.getState().messages.map((m) => ({
    role: m.role as 'user' | 'assistant',
    text: m.text,
  }));
  const { userName, customInstructions } = useSettingsStore.getState();
  return buildConversationContext({
    messages: historical,
    userName,
    customInstructions,
  });
}

async function persistLiveTalkUserMessage(text: string): Promise<void> {
  let sessionId = liveTalkSessionId ?? useChatStore.getState().chatSessionId;
  if (!sessionId) {
    const session = await ChatSessionService.createNewChat(text.slice(0, 60));
    sessionId = session.id;
  }
  liveTalkSessionId = sessionId;

  const messageId = String(uuid.v4());
  const now = Date.now();
  await ChatSessionService.saveMessage({
    sessionId,
    role: 'user',
    content: text,
    customId: messageId,
    createdAt: now,
    runId: liveTalkTurnRunId ?? undefined,
  });
  useChatStore.getState().upsertMessage({
    id: messageId,
    sessionId,
    role: 'user',
    text,
    createdAt: now,
    status: 'sent',
    runId: liveTalkTurnRunId ?? undefined,
  });
}

function persistLiveTalkAssistantMessage(
  text: string,
  completed: boolean,
): void {
  const sessionId = liveTalkSessionId ?? useChatStore.getState().chatSessionId;
  const messageId = liveTalkTurnRunId;
  if (!sessionId || !messageId || !text.trim()) return;

  const ts = Date.now();
  ChatSessionService.saveMessage({
    sessionId,
    role: 'assistant',
    content: text,
    customId: messageId,
    createdAt: ts,
    runId: messageId,
  }).catch((err) =>
    console.error('[LiveTalk] Failed to persist assistant message:', err),
  );
  useChatStore
    .getState()
    .completeMessageStream(messageId, text, ts, messageId);

  if (completed) {
    // Keep the native working context aligned with the canonical JS history.
    const context = buildLiveTalkContext().map((m) => ({
      role: m.role,
      content: m.content,
    }));
    liveTalkService.setContext(context);
  }
}

function handleLiveTalkEvent(event: {
  type: string;
  state?: string;
  text?: string;
  delta?: string;
  level?: number;
  turnId?: string;
  interrupted?: boolean;
  code?: string;
  message?: string;
  metric?: string;
  ms?: number;
}): void {
  const store = useAssistantStore.getState();
  if (store.chatMode !== ChatMode.LIVE_TALK && event.type !== 'error') return;

  switch (event.type) {
    case 'state': {
      const phase = event.state
        ? (NATIVE_TO_LIVE_TALK_PHASE[event.state] ?? null)
        : null;
      store.setLiveTalkPhase(phase);
      switch (event.state) {
        case 'listening':
          store.setSttPhase(SttPhase.LISTENING);
          store.setTtsPhase(TtsPhase.IDLE);
          store.setLlmPhase(LlmPhase.IDLE);
          store.setMic(MicOwner.STT);
          break;
        case 'user_speaking':
          store.setSttPhase(SttPhase.LISTENING);
          store.setTranscript('');
          break;
        case 'processing':
          store.setSttPhase(SttPhase.TRANSCRIBING);
          break;
        case 'thinking':
          store.setSttPhase(SttPhase.IDLE);
          store.setLlmPhase(LlmPhase.THINKING);
          break;
        case 'speaking':
          store.setLlmPhase(LlmPhase.IDLE);
          store.setTtsPhase(TtsPhase.SPEAKING);
          break;
        case 'interrupted':
          store.setTtsPhase(TtsPhase.IDLE);
          store.setLlmPhase(LlmPhase.IDLE);
          break;
        case 'paused':
          store.setSttPhase(SttPhase.IDLE);
          store.setTtsPhase(TtsPhase.IDLE);
          store.setMic(MicOwner.NONE);
          break;
        case 'idle':
          break;
      }
      break;
    }

    case 'transcription_completed': {
      const text = (event.text ?? '').trim();
      store.setTranscript(text);
      store.setSttPhase(SttPhase.IDLE);
      if (text) {
        persistLiveTalkUserMessage(text).catch((err) =>
          console.error('[LiveTalk] Failed to persist user message:', err),
        );
      }
      break;
    }

    case 'thinking_started': {
      liveTalkTurnRunId = String(uuid.v4());
      liveTalkResponseAcc = '';
      store.startRun(RequestOrigin.LIVE_TALK);
      store.setLlmPhase(LlmPhase.THINKING);
      break;
    }

    case 'assistant_text': {
      const delta = event.delta ?? '';
      liveTalkResponseAcc += delta;
      store.appendResponse(delta);
      if (store.llmPhase !== LlmPhase.GENERATING) {
        store.setLlmPhase(LlmPhase.GENERATING);
      }
      const messageId = liveTalkTurnRunId;
      const sessionId =
        liveTalkSessionId ?? useChatStore.getState().chatSessionId;
      if (messageId && sessionId) {
        useChatStore.getState().appendMessageChunk(messageId, delta, messageId);
      }
      break;
    }

    case 'thinking_completed': {
      persistLiveTalkAssistantMessage(
        (event.text ?? liveTalkResponseAcc).trim(),
        true,
      );
      store.setLlmPhase(LlmPhase.IDLE);
      liveTalkTurnRunId = null;
      liveTalkResponseAcc = '';
      break;
    }

    case 'interrupted': {
      persistLiveTalkAssistantMessage(liveTalkResponseAcc.trim(), true);
      store.setLlmPhase(LlmPhase.IDLE);
      store.setTtsPhase(TtsPhase.IDLE);
      liveTalkTurnRunId = null;
      liveTalkResponseAcc = '';
      break;
    }

    case 'tts_started':
      store.setTtsPhase(TtsPhase.SPEAKING);
      break;

    case 'tts_stopped':
      store.setTtsPhase(TtsPhase.IDLE);
      break;

    case 'audio_level':
      if (store.micOwner === MicOwner.STT) {
        store.setMic(MicOwner.STT, event.level ?? 0);
      }
      break;

    case 'latency':
      console.debug(`[LiveTalk] ${event.metric}: ${event.ms}ms`);
      break;

    case 'error': {
      const message = event.message ?? 'Live Talk error';
      if (event.code === 'MODEL_MISSING') {
        openVoiceModalForMissingModel();
      }
      store.setError(message);
      break;
    }

    case 'session_stopped': {
      if (store.chatMode === ChatMode.LIVE_TALK) {
        store.setChatMode(ChatMode.TEXTING);
        store.setLiveTalkPhase(null);
        store.setSttPhase(SttPhase.IDLE);
        store.setLlmPhase(LlmPhase.IDLE);
        store.setTtsPhase(TtsPhase.IDLE);
        store.setMic(MicOwner.NONE);
      }
      liveTalkTurnRunId = null;
      liveTalkResponseAcc = '';
      liveTalkSessionId = null;
      break;
    }
  }
}

function ensureLiveTalkConfigured(): void {
  if (liveTalkConfigured) return;
  liveTalkConfigured = true;
  liveTalkService.configureHandler(handleLiveTalkEvent);
  liveTalkService.enableBackgroundStop(() => stopLiveTalk());
}

export async function startLiveTalk(options?: {
  sessionId?: string | null;
}): Promise<void> {
  const store = useAssistantStore.getState();
  try {
    ensureLiveTalkConfigured();

    liveTalkSessionId =
      options?.sessionId ?? useChatStore.getState().chatSessionId;
    if (liveTalkSessionId) {
      useChatStore.getState().setChatSessionId(liveTalkSessionId);
    }

    const modelId = useModelStore.getState().selectedModelId;
    const cloud = isCloudModel(modelId);
    const [modelPath, apiKey] = await Promise.all([
      cloud
        ? Promise.resolve(null)
        : modelDownloadService.getDownloadedModelPath(modelId),
      cloud ? settingsService.readApiKey() : Promise.resolve(null),
    ]);

    const voice = useVoiceStore.getState();
    const context = buildLiveTalkContext().map((m) => ({
      role: m.role,
      content: m.content,
    }));

    store.setChatMode(ChatMode.LIVE_TALK);
    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    const intelligence: Record<string, string> = {
      kind: cloud ? 'cloud' : 'local',
      modelId,
      device: useSettingsStore.getState().deviceType,
    };
    if (modelPath) intelligence.modelPath = modelPath;
    if (apiKey) intelligence.apiKey = apiKey;

    await liveTalkService.start({
      intelligence: intelligence as any,
      context,
      tts: {
        enabled: voice.liveTalkTtsMode !== 'disabled',
        mode: voice.liveTalkTtsMode,
      },
      sttModelId: voice.selectedSttModelId,
    });
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to start Live Talk.';
    const current = useAssistantStore.getState();
    if (error?.code === 'MODEL_MISSING') {
      openVoiceModalForMissingModel();
    }
    current.setError(message);
    current.setSttPhase(SttPhase.IDLE);
    current.setChatMode(ChatMode.TEXTING);
    current.setLiveTalkPhase(null);
    current.setMic(MicOwner.NONE);
  }
}

export async function pauseLiveTalk(): Promise<void> {
  try {
    liveTalkService.pause();
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to pause Live Talk.';
    useAssistantStore.getState().setError(message);
  }
}

export async function resumeLiveTalk(): Promise<void> {
  try {
    liveTalkService.resume();
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to resume Live Talk.';
    useAssistantStore.getState().setError(message);
  }
}

export function interruptLiveTalk(): void {
  liveTalkService.interrupt();
}

export function stopLiveTalk(): void {
  liveTalkService.stop().catch((err) =>
    console.warn('[LiveTalk] Native stop failed', err),
  );

  liveTalkTurnRunId = null;
  liveTalkResponseAcc = '';
  liveTalkSessionId = null;

  const store = useAssistantStore.getState();

  store.setChatMode(ChatMode.TEXTING);
  store.setLiveTalkPhase(null);
  store.setSttPhase(SttPhase.IDLE);
  store.setLlmPhase(LlmPhase.IDLE);
  store.setTtsPhase(TtsPhase.IDLE);
  store.setCurrentTtsMessageId(null);
  store.setMic(MicOwner.NONE);
}

export function speakMessage(text: string, messageId: string): void {
  ensureTtsEventSubscription();
  const store = useAssistantStore.getState();

  if (activeTtsRequestId !== null && activeTtsMessageId !== messageId) {
    const stale = activeTtsRequestId;
    activeTtsRequestId = null;
    activeTtsMessageId = null;
    ttsProvider.stop(stale).catch(() => {});
  } else if (activeTtsRequestId !== null) {
    console.warn({
      activeTtsRequestId,
      activeTtsMessageId,
      messageId,
    });
    return;
  }

  if (!text.trim()) {
    return;
  }

  const requestId = String(uuid.v4());
  activeTtsRequestId = requestId;
  activeTtsMessageId = messageId;

  store.setCurrentTtsMessageId(messageId);
  ttsProvider.speak(text, { requestId }).catch((error: any) => {
    if (requestId !== activeTtsRequestId) {
      return;
    }
    activeTtsRequestId = null;
    activeTtsMessageId = null;
    const current = useAssistantStore.getState();
    if (error instanceof VoiceModelMissingError) {
      openVoiceModalForMissingModel();
      current.setTtsPhase(TtsPhase.IDLE);
      current.setCurrentTtsMessageId(null);
      return;
    }
    current.setError(
      error instanceof Error ? error.message : 'Failed to speak message.',
    );
    current.setTtsPhase(TtsPhase.ERROR);
    current.setCurrentTtsMessageId(null);
  });
}

export function pauseSpeaking(): void {
  ensureTtsEventSubscription();
  if (activeTtsRequestId === null) return;
  const store = useAssistantStore.getState();
  if (store.ttsPhase !== TtsPhase.SPEAKING) return;

  ttsProvider.pause(activeTtsRequestId).catch((error: any) => {
    useAssistantStore
      .getState()
      .setError(error instanceof Error ? error.message : 'Failed to pause.');
  });
}

export function resumeSpeaking(): void {
  ensureTtsEventSubscription();
  if (activeTtsRequestId === null) return;
  const store = useAssistantStore.getState();
  if (store.ttsPhase !== TtsPhase.PAUSED) return;

  ttsProvider.resume(activeTtsRequestId).catch((error: any) => {
    useAssistantStore
      .getState()
      .setError(error instanceof Error ? error.message : 'Failed to resume.');
  });
}

export function stopSpeaking(): void {
  ensureTtsEventSubscription();
  const requestId = activeTtsRequestId;
  if (requestId === null) {
    const store = useAssistantStore.getState();
    if (store.ttsPhase !== TtsPhase.IDLE) {
      store.setTtsPhase(TtsPhase.IDLE);
      store.setCurrentTtsMessageId(null);
    }
    return;
  }

  ttsProvider.stop(requestId).catch((error) => {});
}

export async function editAndResubmitPrompt(
  messageId: string,
  newText: string,
  modelId: string,
  incomingSessionId?: string | null,
  incomingMsgId?: string | null,
): Promise<void> {
  const chatStore = useChatStore.getState();
  const sessionId = incomingSessionId ?? chatStore.chatSessionId;
  if (!sessionId) return;

  const targetMessage = chatStore.messages.find((m) => m.id === messageId);
  if (
    !targetMessage ||
    targetMessage.role !== 'user' ||
    !targetMessage.createdAt
  )
    return;

  try {
    await ChatSessionService.truncateMessages(
      sessionId,
      targetMessage.createdAt,
      targetMessage.runId,
    );

    const assistantStore = useAssistantStore.getState();
    assistantStore.setEditingMessageId(null);
    assistantStore.setDraftText('');

    const msgId = incomingMsgId || String(uuid.v4());

    await submitPrompt({
      text: newText,
      origin: RequestOrigin.MANUAL_TYPING,
      modelId,
      sessionId,
      msgId,
    });
  } catch (error: any) {
    console.error('[Runtime] Failed to edit and resubmit:', error);
    useAssistantStore
      .getState()
      .setError(error.message || 'Failed to edit message');
  }
}
