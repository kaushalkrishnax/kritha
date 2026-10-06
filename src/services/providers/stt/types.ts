export interface SttResult {
  requestId: string;
  text: string;
}

export interface SttStartOptions {
  onPartial?: (text: string, requestId: string) => void;
  onAudioLevel?: (level: number, requestId: string) => void;
  /** fatal=true means capture died and the session must be torn down. */
  onError?: (message: string, fatal: boolean) => void;
}

export interface SttProvider {
  startListening: (options?: SttStartOptions) => Promise<string>;
  stopListening: () => Promise<SttResult>;
  cancelListening: () => Promise<void>;
}
