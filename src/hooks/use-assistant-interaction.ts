import { getConversationContext } from '@/services/conversation-context.service';
import { VoiceEngine } from '@/services/voice/VoiceEngine';
import { useAssistantStore } from '@/store/assistantStore';
import {
  cancel,
  submitText
} from '@modules/kritha/src';
import { useCallback } from 'react';

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
  const setTtsState = useAssistantStore((s) => s.setTtsState);
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

  const handleDictatePress = useCallback(() => {
    if (canonicalState === 'LISTENING') {
      handleStopDictation();
      return;
    }
    setDraftText('');
    setTranscript('');
    handleStartDictation();
  }, [canonicalState, setDraftText, setTranscript, handleStartDictation, handleStopDictation]);

    const handleLiveTalkToggle = useCallback(async () => {
    if (isLiveTalk) {
      setIsLiveTalk(false);
      setIsLiveTalkHeld(false);
      setLiveTalkState(null);
      VoiceEngine.stopListening();
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
      }
    }
  }, [isLiveTalk, setIsLiveTalk, setIsLiveTalkHeld, setLiveTalkState, chatSessionId]);

    const handleLiveTalkMicToggle = useCallback(async () => {
    if (liveTalkState === 'LISTENING' || canonicalState === 'LISTENING') {
      setIsLiveTalkHeld(false);
      VoiceEngine.stopListening();
      return;
    }
    setTtsState(false, false, null);
    setIsLiveTalkHeld(false);
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
    setTtsState,
    chatSessionId,
  ]);

  const handleStopResponse = useCallback(() => {
    cancel();
  }, []);

    const handleSpeakerPress = useCallback(async (messageId: string, text: string) => {
    const isCurrentMessage = !currentTtsMsgId || currentTtsMsgId === messageId;

    if (isTtsSpeaking && isCurrentMessage) {
      VoiceEngine.stopTTS();
      return;
    }

    if (isTtsPaused && isCurrentMessage) {
      VoiceEngine.playTTS(text);
      return;
    }

    if (!text) return;

    if (!useAssistantStore.getState().selectedTtsModelId) { 
      useAssistantStore.getState().setVoiceModalOpen(true); 
      return; 
    }

    try {
      await VoiceEngine.playTTS(text);
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
    handleDictatePress,
    handleLiveTalkToggle,
    handleLiveTalkMicToggle,
    handleStopResponse,
    handleSpeakerPress,
  };
}