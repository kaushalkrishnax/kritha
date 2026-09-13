export interface TtsProvider {
  speak: (
    text: string,
    messageId: string,
    onDone: () => void,
  ) => void;

  pause: () => void;
  resume: () => void;
  stop: () => void;
}
