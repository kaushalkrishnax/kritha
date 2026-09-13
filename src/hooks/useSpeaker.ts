import { useCallback } from 'react';
import * as assistantRuntime from '@/services/assistantRuntime.service';
import {
  useAssistantStore,
  useIsTtsPaused,
  useIsTtsSpeaking,
  useVoiceStore,
} from '@/stores';

export { useVoiceStore };

export function useSpeaker() {
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();

  const currentTtsMsgId = useAssistantStore(
    (s) => s.currentTtsMessageId,
  );

  const setVoiceModalOpen = useVoiceStore(
    (s) => s.setVoiceModalOpen,
  );

  const selectedTtsModelId = useVoiceStore(
    (s) => s.selectedTtsModelId,
  );

  const handleSpeakerPress = useCallback(
    (messageId: string, text: string) => {
      const isCurrentMessage =
        !currentTtsMsgId || currentTtsMsgId === messageId;

      if (isTtsSpeaking && isCurrentMessage) {
        assistantRuntime.stopSpeaking();
        return;
      }

      if (!text) return;

      if (!selectedTtsModelId) {
        setVoiceModalOpen(true);
        return;
      }

      assistantRuntime.speakMessage(text, messageId);
    },
    [
      currentTtsMsgId,
      isTtsSpeaking,
      selectedTtsModelId,
      setVoiceModalOpen,
    ],
  );

  const openVoiceModal = useCallback(
    () => setVoiceModalOpen(true),
    [setVoiceModalOpen],
  );

  const closeVoiceModal = useCallback(
    () => setVoiceModalOpen(false),
    [setVoiceModalOpen],
  );

  const setSelectedSttModelId = useCallback(
    (id: string | null) =>
      useVoiceStore.getState().setSelectedSttModelId(id),
    [],
  );

  const setSelectedTtsModelId = useCallback(
    (id: string | null) =>
      useVoiceStore.getState().setSelectedTtsModelId(id),
    [],
  );

  return {
    handleSpeakerPress,
    openVoiceModal,
    closeVoiceModal,
    setSelectedSttModelId,
    setSelectedTtsModelId,
    isTtsSpeaking,
    isTtsPaused,
  };
}
