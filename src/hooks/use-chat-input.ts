import { useCallback, useRef } from 'react';
import { isCloudModel } from '@/constants';
import { useConversationContext } from '@/hooks';
import { AssistantBridge, ChatSessionService, SttEngine, TtsEngine, modelDownloadService } from '@/services';
import { useAssistantSessionStore, useChatInputStore, useChatStore, useVoiceStore } from '@/store';

export function useChatInput(modelId?: string) {
  const mode = useChatInputStore((s) => s.mode);
  const liveTalkPhase = useChatInputStore((s) => s.liveTalkPhase);
  const draftText = useChatInputStore((s) => s.draftText);
  const setMode = useChatInputStore((s) => s.setMode);
  const setLiveTalkPhase = useChatInputStore((s) => s.setLiveTalkPhase);
  const setDraftText = useChatInputStore((s) => s.setDraftText);

  const chatSessionId = useChatStore((s) => s.chatSessionId);
  const canonicalState = useAssistantSessionStore((s) => s.canonicalState);
  const setTranscript = useAssistantSessionStore((s) => s.setTranscript);
  const getConversationContext = useConversationContext();

  const submitText = useCallback(async () => {
    const userText = draftText.trim();
    const isSending =
      canonicalState === 'THINKING' || canonicalState === 'GENERATING';

    if (!userText || isSending) return;

    setDraftText('');
    setTranscript('');

    try {
      let isCloud = false;
      let modelPath = undefined;

      if (modelId) {
        isCloud = isCloudModel(modelId);
        modelPath =
          (await modelDownloadService.getDownloadedModelPath(modelId)) ||
          undefined;
      }

      ChatSessionService.addOptimisticUserMessage(userText);

      // :: TODO:: Use a high valued Submit function here
      // AssistantBridge.submitText(userText, {
      //   origin: 'MANUAL_TYPING',
      //   ...(chatSessionId && { chatSessionId }),
      //   ...(modelId && { modelId, modelPath, isCloud }),
      //   history: getConversationContext(),
      // });
      setMode('TEXTING');
    } catch (e) {
      console.warn('Failed to submit text:', e);
    }
  }, [
    modelId,
    draftText,
    canonicalState,
    chatSessionId,
    setDraftText,
    setTranscript,
    setMode,
  ]);

  const startDictation = useCallback(async () => {
    try {
      await SttEngine.startListening();
      setMode('DICTATION');
    } catch (e: any) {
      if (
        e.message?.includes('No STT model selected') ||
        e.message?.includes('STT model not downloaded')
      ) {
        useVoiceStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to start dictation:', e);
      }
    }
  }, [setMode]);

  const cancelDictation = useCallback(() => {
    try {
      SttEngine.stopListening();
      setDraftText('');
      setTranscript('');
      setMode('TEXTING');
    } catch (e) {
      console.warn('Failed to cancel dictation:', e);
    }
  }, [setDraftText, setTranscript, setMode]);

  const stopDictation = useCallback(() => {
    try {
      SttEngine.stopListening();
      const transcript = useAssistantSessionStore.getState().transcript;
      if (transcript) setDraftText(transcript);
      setMode('TEXTING');
    } catch (e) {
      console.warn('Failed to stop dictation:', e);
    }
  }, [setDraftText, setMode]);

  const sendDictation = useCallback(async () => {
    const text = draftText.trim();
    if (!text) return;

    try {
      await SttEngine.stopListening();
      await new Promise((r) => setTimeout(r, 100));

      let isCloud = false;
      let modelPath = undefined;

      if (modelId) {
        isCloud = isCloudModel(modelId);
        modelPath =
          (await modelDownloadService.getDownloadedModelPath(modelId)) ||
          undefined;
      }

      ChatSessionService.addOptimisticUserMessage(text);

      // ::TODO:: Use a high valued Submit function here
      // AssistantBridge.submitText(text, {
      //   origin: 'MANUAL_DICTATION',
      //   ...(chatSessionId && { chatSessionId }),
      //   ...(modelId && { modelId, modelPath, isCloud }),
      //   history: getConversationContext(),
      // });
      setMode('TEXTING');
    } catch (e) {
      console.warn('Failed to send dictation:', e);
    }
  }, [draftText, chatSessionId, modelId, setMode]);

  const isTogglingRef = useRef(false);

  const startLiveTalk = useCallback(async () => {
    if (isTogglingRef.current) return;
    isTogglingRef.current = true;
    try {
      await SttEngine.startListening();
      setMode('LIVE_TALK');
      setLiveTalkPhase('LISTENING');
    } catch (e: any) {
      if (
        e.message?.includes('No STT model selected') ||
        e.message?.includes('STT model not downloaded')
      ) {
        useVoiceStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to start Live Talk:', e);
      }
    } finally {
      isTogglingRef.current = false;
    }
  }, [setMode, setLiveTalkPhase]);

  const pauseLiveTalk = useCallback(async () => {
    setLiveTalkPhase('PAUSED');
    await SttEngine.stopListening();
    await TtsEngine.stopTTS();
  }, [setLiveTalkPhase]);

  const resumeLiveTalk = useCallback(async () => {
    setLiveTalkPhase('LISTENING');
    await TtsEngine.stopTTS();
    try {
      await SttEngine.startListening();
    } catch (e: any) {
      if (
        e.message?.includes('No STT model selected') ||
        e.message?.includes('STT model not downloaded')
      ) {
        useVoiceStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to toggle Live Talk mic:', e);
      }
    }
  }, [setLiveTalkPhase]);

  const stopLiveTalk = useCallback(async () => {
    // ::TODO:: Implement assistant runtime and fix this type to use 'IDLE' instead of 'null'
    // useAssistantSessionStore.getState().setCanonicalState('IDLE');
    useAssistantSessionStore.getState().setCanonicalState(null);
    useVoiceStore.getState().setTtsState(false, false, null);
    useAssistantSessionStore.getState().setMicState('NONE', true, 0);

    TtsEngine.stopTTS().catch(console.warn);
    SttEngine.stopListening(true).catch(console.warn);

    // ::TODO:: Cancel the current run if any
    // AssistantBridge.cancelRun();

    setMode('TEXTING');
    setLiveTalkPhase(null);
  }, [setMode, setLiveTalkPhase]);

  return {
    mode,
    liveTalkPhase,
    draftText,
    setDraftText,
    submitText,
    startDictation,
    cancelDictation,
    stopDictation,
    sendDictation,
    startLiveTalk,
    pauseLiveTalk,
    resumeLiveTalk,
    stopLiveTalk,
  };
}
