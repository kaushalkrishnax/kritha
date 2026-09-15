import { useAssistantStore } from '@/stores/assistant.store';
import { useVoiceStore } from '@/stores/voice.store';
import { SoniqoSpeech, SpeechEvent } from '@modules/kritha/src';
import { SttProvider } from './types';

let accumulatedTranscript = '';
let transcriptSub: { remove: () => void } | null = null;

export const soniqoSttProvider: SttProvider = {
  startListening: async () => {
    accumulatedTranscript = '';
    const sttModelId = useVoiceStore.getState().selectedSttModelId;
    const ttsModelId = useVoiceStore.getState().selectedTtsModelId;

    const models = await SoniqoSpeech.listVoiceModels();
    const sttModel = models.find((m) => m.id === sttModelId);
    if (!sttModel?.isDownloaded) {
      useVoiceStore.getState().setVoiceModalOpen(true);
      throw new Error(
        'STT model not downloaded. Please download it from Voice Models.',
      );
    }

    await SoniqoSpeech.initialize({
      sttModelId: sttModelId ?? undefined,
      ttsModelId: ttsModelId ?? undefined,
    });

    if (!transcriptSub) {
      transcriptSub = SoniqoSpeech.addTranscriptListener(
        (event: SpeechEvent) => {
          if (event.text) {
            accumulatedTranscript = event.text;
            useAssistantStore.getState().setTranscript(event.text);
            useAssistantStore.getState().setDraftText(event.text);
          }
        },
      );
    }

    // Start Soniqo in transcribe mode (no llmModelPath)
    await SoniqoSpeech.start(undefined, 'cpu');
  },

  stopListening: async () => {
    try {
      await SoniqoSpeech.stop();
    } catch (e) {
      console.warn('Failed to stop Soniqo STT', e);
    }
    const finalTranscript = accumulatedTranscript;
    accumulatedTranscript = '';
    return finalTranscript;
  },
};
