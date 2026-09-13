import { useCallback } from 'react';
import { SttEngine, TtsEngine } from '@/services';
import { useVoiceStore } from '@/store';

export { useVoiceStore, TtsEngine, SttEngine };

export function useSpeaker() {
  const isTtsSpeaking = useVoiceStore((s) => s.isTtsSpeaking);
  const currentTtsMsgId = useVoiceStore((s) => s.currentTtsMsgId);
  const setVoiceModalOpen = useVoiceStore((s) => s.setVoiceModalOpen);
  const selectedTtsModelId = useVoiceStore((s) => s.selectedTtsModelId);

  const handleSpeakerPress = useCallback(
    async (messageId: string, text: string) => {
      const isCurrentMessage =
        !currentTtsMsgId || currentTtsMsgId === messageId;

      if (isTtsSpeaking && isCurrentMessage) {
        await TtsEngine.stopTTS();
        return;
      }

      if (!text) return;

      if (!selectedTtsModelId) {
        setVoiceModalOpen(true);
        return;
      }

      try {
        await TtsEngine.playTTS(text, messageId);
      } catch (e: any) {
        if (
          e.message?.includes('No TTS model selected') ||
          e.message?.includes('TTS model not downloaded')
        ) {
          setVoiceModalOpen(true);
        } else {
          console.warn('Failed to play TTS:', e);
        }
      }
    },
    [currentTtsMsgId, isTtsSpeaking, selectedTtsModelId, setVoiceModalOpen],
  );

  const openVoiceModal = useCallback(() => setVoiceModalOpen(true), [setVoiceModalOpen]);
  const closeVoiceModal = useCallback(() => setVoiceModalOpen(false), [setVoiceModalOpen]);

  const setSelectedSttModelId = useCallback(
    (id: string | null) => useVoiceStore.getState().setSelectedSttModelId(id),
    []
  );

  const setSelectedTtsModelId = useCallback(
    (id: string | null) => useVoiceStore.getState().setSelectedTtsModelId(id),
    []
  );

  return { handleSpeakerPress, openVoiceModal, closeVoiceModal, setSelectedSttModelId, setSelectedTtsModelId };
}
