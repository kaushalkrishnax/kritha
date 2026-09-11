import { getConversationContext } from '@/services/conversation-context.service';
import { VoiceEngine } from '@/services/voice/VoiceEngine';
import { useAssistantStore } from '@/store/assistantStore';
import {
  cancel,
  submitText
} from '@modules/kritha/src';
import { useCallback, useRef } from 'react';

export function useAssistantActions(modelId?: string) {
  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const liveTalkState = useAssistantStore((s) => s.liveTalkState);
  const setLiveTalkState = useAssistantStore((s) => s.setLiveTalkState);
  const draftText = useAssistantStore((s) => s.draftText);
  const chatSessionId = useAssistantStore((s) => s.chatSessionId);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMsgId);
  const isTtsSpeaking = useAssistantStore((s) => s.isTtsSpeaking);
  const isTtsPaused = useAssistantStore((s) => s.isTtsPaused);
  const isLiveTalk = useAssistantStore((s) => s.isLiveTalk);
  const setDraftText = useAssistantStore((s) => s.setDraftText);
  const setTranscript = useAssistantStore((s) => s.setTranscript);
  const setIsLiveTalk = useAssistantStore((s) => s.setIsLiveTalk);
  const isLiveTalkHeld = useAssistantStore((s) => s.isLiveTalkHeld);
  const setIsLiveTalkHeld = useAssistantStore((s) => s.setIsLiveTalkHeld);

  const handleSendMessage = useCallback(() => {
    const userText = draftText.trim();
    const isSending = canonicalState === 'THINKING' || canonicalState === 'GENERATING';

    if (!userText || isSending) return;

    setDraftText('');
    setTranscript('');

    try {
      submitText(userText, {
        origin: 'MANUAL_TYPING',
        ...(chatSessionId && { chatSessionId: chatSessionId }),
        ...(modelId && { modelId }),
        history: getConversationContext(),
      });
    } catch (e) {
      console.warn('Failed to submit text:', e);
    }
  }, [modelId, draftText, canonicalState, chatSessionId, setDraftText, setTranscript]);

  const handleStartDictation = useCallback(async () => {
    try {
      await VoiceEngine.startListening();
    } catch (e: any) {
      if (e.message?.includes('No STT model selected') || e.message?.includes('STT model not downloaded')) {
        useAssistantStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to start listening:', e);
      }
    }
  }, [chatSessionId]);

  const handleStopDictation = useCallback(() => {
    try {
      VoiceEngine.stopListening();
    } catch (e) {
      console.warn('Failed to stop listening:', e);
    }
  }, []);

  const handleSendDictation = useCallback(async () => {
    const text = draftText.trim();
    if (!text) return;

    try {
      // Stop listening first
      await VoiceEngine.stopListening();
      // Small delay to let the state settle
      await new Promise(r => setTimeout(r, 100));
      // Then submit the text
      submitText(text, {
        origin: 'MANUAL_DICTATION',
        ...(chatSessionId && { chatSessionId: chatSessionId }),
        history: getConversationContext(),
      });
    } catch (e) {
      console.warn('Failed to send dictation:', e);
    }
  }, [draftText, chatSessionId]);

  const handleDictatePress = useCallback(() => {
    if (canonicalState === 'LISTENING') {
      handleStopDictation();
      return;
    }
    setDraftText('');
    setTranscript('');
    handleStartDictation();
  }, [canonicalState, setDraftText, setTranscript, handleStartDictation, handleStopDictation]);

  const isTogglingRef = useRef(false);
  const handleLiveTalkToggle = useCallback(async () => {
    if (isTogglingRef.current) return;
    isTogglingRef.current = true;
    try {
      const currentIsLiveTalk = useAssistantStore.getState().isLiveTalk;
      if (currentIsLiveTalk) {
        setIsLiveTalk(false);
        setIsLiveTalkHeld(false);
        setLiveTalkState(null);
        useAssistantStore.getState().setCanonicalState('IDLE');
        useAssistantStore.getState().setTtsState(false, false, null);
        useAssistantStore.getState().setMicState('NONE', true, 0);

        VoiceEngine.stopTTS().catch(console.warn);
        VoiceEngine.stopListening(true).catch(console.warn);
        cancel();
        return;
      }
    setIsLiveTalk(true);
    try {
      await VoiceEngine.startListening();
    } catch (e: any) {
      if (e.message?.includes('No STT model selected') || e.message?.includes('STT model not downloaded')) {
        setIsLiveTalk(false);
        useAssistantStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to start Live Talk:', e);
        setIsLiveTalk(false);
      }
    }
    } finally {
      isTogglingRef.current = false;
    }
  }, [isLiveTalk, setIsLiveTalk, setIsLiveTalkHeld, setLiveTalkState, chatSessionId]);

  const handleLiveTalkMicToggle = useCallback(async () => {
    if (liveTalkState === 'LISTENING' || canonicalState === 'LISTENING') {
      // Currently listening — stop STT
      setIsLiveTalkHeld(false);
      await VoiceEngine.stopListening();
      return;
    }
    // Currently idle or speaking — stop TTS and start listening
    setIsLiveTalkHeld(false);
    await VoiceEngine.stopTTS();
    try {
      await VoiceEngine.startListening();
    } catch (e: any) {
      if (e.message?.includes('No STT model selected') || e.message?.includes('STT model not downloaded')) {
        useAssistantStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to toggle Live Talk mic:', e);
      }
    }
  }, [
    liveTalkState,
    canonicalState,
    setIsLiveTalkHeld,
    chatSessionId,
  ]);

  const handleStopResponse = useCallback(() => {
    VoiceEngine.stopTTS();
    cancel();
  }, []);

  const handleSpeakerPress = useCallback(async (messageId: string, text: string) => {
    const isCurrentMessage = !currentTtsMsgId || currentTtsMsgId === messageId;

    // If currently speaking this message — stop
    if (isTtsSpeaking && isCurrentMessage) {
      await VoiceEngine.stopTTS();
      return;
    }

    if (!text) return;

    // Check model is selected
    if (!useAssistantStore.getState().selectedTtsModelId) {
      useAssistantStore.getState().setVoiceModalOpen(true);
      return;
    }

    try {
      await VoiceEngine.playTTS(text, messageId);
    } catch (e: any) {
      if (e.message?.includes('No TTS model selected') || e.message?.includes('TTS model not downloaded')) {
        useAssistantStore.getState().setVoiceModalOpen(true);
      } else {
        console.warn('Failed to play TTS:', e);
      }
    }
  }, [currentTtsMsgId, isTtsSpeaking, isTtsPaused, chatSessionId]);

  return {
    handleSendMessage,
    handleStartDictation,
    handleStopDictation,
    handleSendDictation,
    handleDictatePress,
    handleLiveTalkToggle,
    handleLiveTalkMicToggle,
    handleStopResponse,
    handleSpeakerPress,
  };
}