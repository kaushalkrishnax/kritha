import { useVoiceStore } from '@/stores/voice.store';
import { SoniqoSpeech } from '@modules/kritha/src';
import { TtsProvider } from './types';

let currentOnDone: (() => void) | null = null;

export const soniqoTtsProvider: TtsProvider = {
  speak: async (text, _messageId, onDone) => {
    currentOnDone = onDone;
    try {
      const selectedTtsId = useVoiceStore.getState().selectedTtsModelId;
      const models = await SoniqoSpeech.listVoiceModels();
      const ttsModel = models.find((m) => m.id === selectedTtsId);

      if (!ttsModel?.isDownloaded) {
        useVoiceStore.getState().setVoiceModalOpen(true);
        if (currentOnDone === onDone) {
          currentOnDone();
          currentOnDone = null;
        }
        return;
      }

      await SoniqoSpeech.speak(text);
    } catch (e) {
      console.warn('Soniqo TTS speak error', e);
    } finally {
      if (currentOnDone === onDone) {
        currentOnDone();
        currentOnDone = null;
      }
    }
  },

  pause: () => {
    SoniqoSpeech.stopSpeaking().catch(() => {});
  },

  resume: () => {
    // Soniqo streaming playback
  },

  stop: () => {
    currentOnDone = null;
    SoniqoSpeech.stopSpeaking().catch(() => {});
  },
};
