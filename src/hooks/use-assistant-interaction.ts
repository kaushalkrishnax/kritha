import { useAssistantStore } from '@/store/assistantStore';
import {
  cancel,
  pauseTts,
  playTts,
  resumeTts,
  setBargeInEnabled,
  startListening,
  stopListening,
  submitText,
} from '@modules/kritha/src';
import { useCallback } from 'react';

export function useAssistantActions(modelId?: string) {
  const canonicalState = useAssistantStore((s) => s.canonicalState);
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
      });
    } catch (e) {
      console.warn('Failed to submit text:', e);
    }
  }, [modelId, draftText, canonicalState, chatSessionId, setDraftText, setTranscript]);

  const handleStartDictation = useCallback(() => {
    try {
      startListening(chatSessionId || undefined);
    } catch (e) {
      console.warn('Failed to start listening:', e);
    }
  }, [chatSessionId]);

  const handleStopDictation = useCallback(() => {
    try {
      stopListening();
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

  const handleLiveTalkToggle = useCallback(() => {
    if (isLiveTalk) {
      setIsLiveTalk(false);
      setIsLiveTalkHeld(false);
      setBargeInEnabled(false);
      cancel();
      return;
    }
    setIsLiveTalk(true);
    setBargeInEnabled(true);
    handleStartDictation();
  }, [isLiveTalk, setIsLiveTalk, handleStartDictation]);

  const handleLiveTalkPauseResume = useCallback(() => {
    // Held or TTS-paused -> resume the conversation by reopening the mic.
    if (isLiveTalkHeld || isTtsPaused) {
      setIsLiveTalkHeld(false);
      setTtsState(false, false, null);
      handleStartDictation();
      return;
    }
    // Speaking -> pause playback (native emits TTS_PAUSE; icon flips to Mic).
    if (isTtsSpeaking) {
      pauseTts();
      return;
    }
    // Listening -> hold the session. cancel() fires a storm of events
    // (TTS_STOP included) that would reset isTtsPaused, so we use the
    // dedicated held flag which survives them; Mic stays up until resumed.
    if (canonicalState === 'LISTENING') {
      setIsLiveTalkHeld(true);
      cancel();
      return;
    }
    // Idle otherwise -> open the mic for the next live-talk turn.
    handleStartDictation();
  }, [
    isLiveTalkHeld,
    isTtsPaused,
    isTtsSpeaking,
    canonicalState,
    setIsLiveTalkHeld,
    setTtsState,
    handleStartDictation,
  ]);

  const handleStopResponse = useCallback(() => {
    cancel();
  }, []);

  const handleSpeakerPress = useCallback((messageId: string, text: string) => {
    const isCurrentMessage = !currentTtsMsgId || currentTtsMsgId === messageId;

    if (isTtsSpeaking && isCurrentMessage) {
      pauseTts();
      return;
    }

    if (isTtsPaused && isCurrentMessage) {
      resumeTts();
      return;
    }

    if (!text) return;

    try {
      playTts(text, {
        chatSessionId: chatSessionId || undefined,
        messageId,
      });
    } catch (e) {
      console.warn('Failed to play TTS:', e);
    }
  }, [currentTtsMsgId, isTtsSpeaking, isTtsPaused, chatSessionId]);

  return {
    handleSendMessage,
    handleStartDictation,
    handleStopDictation,
    handleDictatePress,
    handleLiveTalkToggle,
    handleLiveTalkPauseResume,
    handleStopResponse,
    handleSpeakerPress,
  };
}