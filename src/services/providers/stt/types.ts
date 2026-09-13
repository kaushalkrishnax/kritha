export interface SttProvider {
  startListening: () => Promise<void>;

  /**
   * Stops listening and resolves with the transcript.
   *
   * Providers with no captured speech must return an empty string.
   */
  stopListening: () => Promise<string>;
}
