import * as assistantRuntime from '@/services/assistantRuntime.service';
import { listVoiceModels } from '@/services/speechRuntime.service';
import {
  useAssistantStore,
  useIsTtsPaused,
  useIsTtsSpeaking,
  useVoiceStore,
} from '@/stores';
import { useCallback } from 'react';

export { useVoiceStore };

export function useSpeaker() {
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();

  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMessageId);

  const setVoiceModalOpen = useVoiceStore((s) => s.setVoiceModalOpen);

  const selectedTtsModelId = useVoiceStore((s) => s.selectedTtsModelId);

  const handleSpeakerPress = useCallback(
    async (messageId: string, text: string) => {
      console.log('[TTS_DEBUG] useSpeaker: handleSpeakerPress invoked', {
        messageId,
        textPreview: text?.slice(0, 50),
        textLength: text?.length,
        currentTtsMsgId,
        isTtsSpeaking,
        isTtsPaused,
        selectedTtsModelId,
      });

      const isCurrentMessage =
        !currentTtsMsgId || currentTtsMsgId === messageId;

      if (isCurrentMessage) {
        if (isTtsSpeaking) {
          console.log('[TTS_DEBUG] useSpeaker: breaking to pauseSpeaking');
          assistantRuntime.pauseSpeaking();
          return;
        }
        if (isTtsPaused) {
          console.log('[TTS_DEBUG] useSpeaker: breaking to resumeSpeaking');
          assistantRuntime.resumeSpeaking();
          return;
        }
      }

      if (!text) return;
      if (!text) {
        console.warn('[TTS_DEBUG] useSpeaker: breaking early because text is empty');
        return;
      }

      if (!selectedTtsModelId) {
        console.warn(
          '[TTS_DEBUG] useSpeaker: breaking early because selectedTtsModelId is null -> opening voice modal',
        );
        setVoiceModalOpen(true);
        return;
      }

      try {
        console.log('[TTS_DEBUG] useSpeaker: checking voice models via listVoiceModels()...');
        const models = await listVoiceModels();
        console.log('[TTS_DEBUG] useSpeaker: available voice models:', models);
        const tts = models.find((m) => m.id === selectedTtsModelId);
        console.log('[TTS_DEBUG] useSpeaker: selected TTS model match:', tts);
        if (!tts?.isDownloaded) {
          console.warn(
            '[TTS_DEBUG] useSpeaker: breaking early because TTS model is not downloaded -> opening voice modal',
            {
              selectedTtsModelId,
              foundModel: tts,
            },
          );
          setVoiceModalOpen(true);
          return;
        }
      } catch (err) {
        console.error(
          '[TTS_DEBUG] useSpeaker: breaking early on error listing voice models -> opening voice modal',
          err,
        );
        setVoiceModalOpen(true);
        return;
      }

      console.log(
        '[TTS_DEBUG] useSpeaker: passed all checks, invoking assistantRuntime.speakMessage',
      );
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
