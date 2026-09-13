export type LlmMessageRole = 'system' | 'user' | 'assistant';

export interface LlmMessage {
  role: LlmMessageRole;
  content: string;
}

export interface LlmGenerateRequest {
  requestId: string;
  messages: LlmMessage[];
  modelId: string;
  modelPath?: string;
}

export interface LlmGenerateCallbacks {
  onDelta: (chunk: string) => void;
  onComplete: (fullText: string) => void;
  onError: (error: Error) => void;
}

export interface LlmProvider {
  /**
   * Starts generation.
   *
   * Must call exactly one terminal callback:
   *   onComplete OR onError
   *
   * May call onDelta zero or more times before the terminal callback.
   *
   * Returns a cancellation handle. Calling cancel() after completion
   * must be safe and must not throw.
   */
  generate: (
    request: LlmGenerateRequest,
    callbacks: LlmGenerateCallbacks,
  ) => { cancel: () => void };
}
