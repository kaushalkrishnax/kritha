export interface SttResult {
  requestId: string;
  text: string;
}

export interface SttStartOptions {
  onPartial?: (text: string, requestId: string) => void;
  onAudioLevel?: (level: number, requestId: string) => void;
}

export interface SttProvider {
  startListening: (options?: SttStartOptions) => Promise<string>;
  stopListening: () => Promise<SttResult>;
  cancelListening: () => Promise<void>;
}
