export type TtsLifecycleEvent =
  | { kind: 'started'; requestId: string }
  | { kind: 'paused'; requestId: string }
  | { kind: 'resumed'; requestId: string }
  | { kind: 'completed'; requestId: string }
  | { kind: 'stopped'; requestId: string; replaced?: boolean }
  | { kind: 'error'; requestId: string | null; message: string };

export type TtsEventListener = (event: TtsLifecycleEvent) => void;

export interface TtsSpeakOptions {
  requestId: string;
  voice?: string;
}

export interface TtsProvider {
  speak: (text: string, options: TtsSpeakOptions) => Promise<void>;
  pause: (requestId?: string) => Promise<void>;
  resume: (requestId?: string) => Promise<void>;
  stop: (requestId?: string) => Promise<void>;
  subscribe: (listener: TtsEventListener) => () => void;
}
