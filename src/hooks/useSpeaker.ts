import { useCallback } from 'react';

import * as assistantRuntime from '@/services/assistantRuntime.service';
import { listVoiceModels } from '@/services/speechRuntime.service';
import {
  useAssistantStore,
  useIsTtsPaused,
  useIsTtsSpeaking,
  useVoiceStore,
} from '@/stores';

export function useSpeaker() {
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMessageId);
  const setVoiceModalOpen = useVoiceStore((s) => s.setVoiceModalOpen);
  const selectedTtsModelId = useVoiceStore((s) => s.selectedTtsModelId);

  const handleSpeakerPress = useCallback(
    async (messageId: string, text: string) => {
      const isCurrentMessage =
        !currentTtsMsgId || currentTtsMsgId === messageId;

      if (isCurrentMessage) {
        if (isTtsSpeaking) {
          assistantRuntime.pauseSpeaking();
          return;
        }

        if (isTtsPaused) {
          assistantRuntime.resumeSpeaking();
          return;
        }
      }

      if (!text) {
        return;
      }

      if (!selectedTtsModelId) {
        setVoiceModalOpen(true);
        return;
      }

      try {
        const models = await listVoiceModels();
        const tts = models.find((m) => m.id === selectedTtsModelId);

        if (!tts?.isDownloaded) {
          setVoiceModalOpen(true);
          return;
        }
      } catch {
        setVoiceModalOpen(true);
        return;
      }

      assistantRuntime.speakMessage(text, messageId);
    },
    [
      currentTtsMsgId,
      isTtsPaused,
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
    (id: string | null) => useVoiceStore.getState().setSelectedSttModelId(id),
    [],
  );

  const setSelectedTtsModelId = useCallback(
    (id: string | null) => useVoiceStore.getState().setSelectedTtsModelId(id),
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
