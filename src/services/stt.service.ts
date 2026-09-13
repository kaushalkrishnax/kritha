import { stubAction } from '@/utils';
// Not implemented - requires react-native-sherpa-onnx wiring, see Kotlin/native follow-up.

export const SttEngine = {
  startListening: async (cancelPrevious = false): Promise<void> => {
    stubAction('SttEngine.startListening');
  },
  stopListening: async (force = false): Promise<void> => {
    stubAction('SttEngine.stopListening');
  },
};
