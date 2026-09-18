import {
  ChatMode,
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
import uuid from 'react-native-uuid';
import { ChatSessionService } from './chat.service';
import {
  buildConversationContext,
  ContextMessage,
} from './conversation.service';
import { modelDownloadService } from './model.service';
import {
  LlmMessage,
  pickLlmProvider,
  sttProvider,
  ttsProvider,
} from './providers';
import { VoiceModelMissingError } from './speechRuntime.service';

let activeLlmHandle: { cancel: () => void } | null = null;

let activeSttRequestId: string | null = null;
let activeTtsRequestId: string | null = null;
let activeTtsMessageId: string | null = null;
let ttsEventSubscribed = false;
let sttLevelSmoothed = 0;

function ensureTtsEventSubscription(): void {
  if (ttsEventSubscribed) return;
  ttsEventSubscribed = true;
  ttsProvider.subscribe((event) => {
    if (event.requestId !== activeTtsRequestId) {
      console.warn(
        {
          eventRequestId: event.requestId,
          activeTtsRequestId,
        },
      );
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
    });
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

export async function startLiveTalk(options?: {
  sessionId?: string | null;
}): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    let sessionId = options?.sessionId ?? useChatStore.getState().chatSessionId;
    if (sessionId) {
      useChatStore.getState().setChatSessionId(sessionId);
    }

    store.setChatMode(ChatMode.LIVE_TALK);
    store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    const requestId = await sttProvider.startListening();
    activeSttRequestId = requestId;
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to start Live Talk.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setLiveTalkPhase(null);
    store.setMic(MicOwner.NONE);
    if (!error?.message?.includes('not downloaded')) {
      const message =
        error instanceof Error ? error.message : 'Failed to start Live Talk.';
      store.setError(message);
    }
  }
}

export async function pauseLiveTalk(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setLiveTalkPhase(LiveTalkPhase.PAUSED);
    store.setSttPhase(SttPhase.IDLE);
    store.setMic(MicOwner.NONE);
    store.setTtsPhase(TtsPhase.PAUSED);
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to pause Live Talk.';
    useAssistantStore.getState().setError(message);
  }
}

export async function resumeLiveTalk(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
    store.setTtsPhase(TtsPhase.IDLE);
    store.setCurrentTtsMessageId(null);
    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    const requestId = await sttProvider.startListening();
    activeSttRequestId = requestId;
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to resume Live Talk.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setMic(MicOwner.NONE);
  }
}

export function stopLiveTalk(): void {
  cancelRun();

  const ttsRequestId = activeTtsRequestId;
  activeTtsRequestId = null;
  activeTtsMessageId = null;
  ttsProvider.stop(ttsRequestId ?? undefined).catch(() => {});

  activeSttRequestId = null;
  sttProvider.cancelListening().catch(() => {});

  const store = useAssistantStore.getState();

  store.setChatMode(ChatMode.TEXTING);
  store.setLiveTalkPhase(null);
  store.setSttPhase(SttPhase.IDLE);
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
    console.warn(
      {
        activeTtsRequestId,
      activeTtsMessageId,
      messageId,
    },
  );
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

  ttsProvider.stop(requestId).catch((error) => {
  });
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
