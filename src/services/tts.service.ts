import { stubAction } from '@/utils';
// Not implemented - requires react-native-sherpa-onnx wiring, see Kotlin/native follow-up.

export const TtsEngine = {
  playTTS: async (text: string, messageId?: string): Promise<void> => {
    stubAction('TtsEngine.playTTS');
  },
  stopTTS: async (): Promise<void> => {
    stubAction('TtsEngine.stopTTS');
  },
  destroy: async (): Promise<void> => {
    stubAction('TtsEngine.destroy');
  },
};
