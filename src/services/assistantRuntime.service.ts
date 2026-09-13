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
import uuid from 'react-native-uuid';
import { ChatSessionService } from './chat.service';
import { buildConversationContext, ContextMessage } from './conversation.service';
import { modelDownloadService } from './model.service';
import {
  LlmMessage,
  pickLlmProvider,
  sttProvider,
  ttsProvider,
} from './providers';

let activeLlmHandle: { cancel: () => void } | null = null;

export async function submitPrompt(options: {
  text: string;
  origin: RequestOrigin;
  modelId: string;
}): Promise<void> {
  const { text, origin, modelId } = options;
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

    let sessionId = useChatStore.getState().chatSessionId;

    if (!sessionId) {
      sessionId = uuid.v4();
      useChatStore.getState().setChatSessionId(sessionId);
      await ChatSessionService.createSession({
        title: trimmed.slice(0, 60),
        customId: sessionId,
      });
    }

    const userMessageId = uuid.v4();
    const now = Date.now();

    await ChatSessionService.saveMessage({
      sessionId,
      role: 'user',
      content: trimmed,
      customId: userMessageId,
      createdAt: now,
    });

    useChatStore.getState().upsertMessage({
      id: userMessageId,
      sessionId,
      role: 'user',
      text: trimmed,
      createdAt: now,
      status: 'sent',
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

    const modelPath = await modelDownloadService.getDownloadedModelPath(modelId);

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
          useChatStore.getState().appendMessageChunk(current.assistantRunId!, chunk);
        },

        onComplete: (fullText: string) => {
          const current = useAssistantStore.getState();
          if (current.assistantRunId !== runId) return;

          const assistantMessageId = uuid.v4();
          const ts = Date.now();

          ChatSessionService.saveMessage({
            sessionId: sessionId!,
            role: 'assistant',
            content: fullText,
            customId: assistantMessageId,
            createdAt: ts,
          }).catch((err) => console.error('[Runtime] Failed to persist assistant message:', err));

          useChatStore.getState().completeMessageStream(current.assistantRunId!, fullText);
          useChatStore.getState().upsertMessage({
            id: assistantMessageId,
            sessionId: sessionId!,
            role: 'assistant',
            text: fullText,
            createdAt: ts,
            status: 'sent',
          });

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
  try {
    const store = useAssistantStore.getState();

    store.setChatMode(ChatMode.DICTATION);
    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    await sttProvider.startListening();
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to start dictation.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);
  }
}

export function cancelDictation(): void {
  const store = useAssistantStore.getState();

  store.setSttPhase(SttPhase.IDLE);
  store.setChatMode(ChatMode.TEXTING);
  store.setMic(MicOwner.NONE);
  store.setDraftText('');
  store.setTranscript('');
}

export async function stopDictation(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setSttPhase(SttPhase.TRANSCRIBING);

    const transcript = await sttProvider.stopListening();

    const trimmed = transcript.trim();
    if (trimmed) {
      store.setTranscript(trimmed);
      store.setDraftText(trimmed);
    }

    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to stop dictation.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);
  }
}

export async function sendDictation(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setSttPhase(SttPhase.TRANSCRIBING);
    const result = await sttProvider.stopListening();
    
    const transcript = result.trim() || store.transcript.trim() || store.draftText.trim();

    if (!transcript) {
      cancelDictation();
      return;
    }

    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);

    const modelId = useModelStore.getState().selectedModelId;

    await submitPrompt({
      text: transcript,
      origin: RequestOrigin.MANUAL_DICTATION,
      modelId,
    });
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to send dictation.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setMic(MicOwner.NONE);
  }
}

export async function startLiveTalk(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setChatMode(ChatMode.LIVE_TALK);
    store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    await sttProvider.startListening();
  } catch (error: any) {
    const message =
      error instanceof Error ? error.message : 'Failed to start Live Talk.';
    const store = useAssistantStore.getState();

    store.setError(message);
    store.setSttPhase(SttPhase.IDLE);
    store.setChatMode(ChatMode.TEXTING);
    store.setLiveTalkPhase(null);
    store.setMic(MicOwner.NONE);
  }
}

export async function pauseLiveTalk(): Promise<void> {
  try {
    const store = useAssistantStore.getState();

    store.setLiveTalkPhase(LiveTalkPhase.PAUSED);
    store.setSttPhase(SttPhase.IDLE);
    store.setMic(MicOwner.NONE);

    ttsProvider.pause();
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

    ttsProvider.stop();
    store.setTtsPhase(TtsPhase.IDLE);
    store.setCurrentTtsMessageId(null);

    store.setSttPhase(SttPhase.LISTENING);
    store.setMic(MicOwner.STT);

    await sttProvider.startListening();
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

  ttsProvider.stop();
  sttProvider.stopListening().catch(() => {});

  const store = useAssistantStore.getState();

  store.setChatMode(ChatMode.TEXTING);
  store.setLiveTalkPhase(null);
  store.setSttPhase(SttPhase.IDLE);
  store.setTtsPhase(TtsPhase.IDLE);
  store.setCurrentTtsMessageId(null);
  store.setMic(MicOwner.NONE);
}

export function speakMessage(text: string, messageId: string): void {
  const store = useAssistantStore.getState();

  const currentId = store.currentTtsMessageId;
  if (currentId && currentId !== messageId) {
    ttsProvider.stop();
  }

  store.setCurrentTtsMessageId(messageId);
  store.setTtsPhase(TtsPhase.SPEAKING);

  ttsProvider.speak(text, messageId, () => {
    const current = useAssistantStore.getState();
    if (current.currentTtsMessageId !== messageId) return;

    current.setTtsPhase(TtsPhase.IDLE);
    current.setCurrentTtsMessageId(null);
  });
}

export function stopSpeaking(): void {
  ttsProvider.stop();

  const store = useAssistantStore.getState();
  store.setTtsPhase(TtsPhase.IDLE);
  store.setCurrentTtsMessageId(null);
}
