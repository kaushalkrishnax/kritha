import { SttProvider } from './types';

const STUB_TRANSCRIBE_DELAY_MS = 600;

export const stubSttProvider: SttProvider = {
  startListening: async () => {},

  stopListening: async () => {
    await new Promise((resolve) =>
      setTimeout(resolve, STUB_TRANSCRIBE_DELAY_MS),
    );

    return '';
  },
};
