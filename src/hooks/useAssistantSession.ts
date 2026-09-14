/**
 * Thin read-side wrapper around stores/assistant.store.ts for components
 * that want a convenient bundle of commonly used fields. New code should
 * prefer importing individual selectors from '@/stores' directly; this
 * hook exists for call sites that already expect this shape.
 */
import { useCallback } from 'react';
import {
  useAssistantStore,
  useIsLlmThinking,
  useIsLlmGenerating,
  useIsLlmError,
  useIsSttListening,
  useIsSttTranscribing,
} from '@/stores';

export function useAssistantSession() {
  const assistantRunId = useAssistantStore((s) => s.assistantRunId);
  const requestOrigin = useAssistantStore((s) => s.requestOrigin);
  const response = useAssistantStore((s) => s.response);
  const transcript = useAssistantStore((s) => s.transcript);
  const error = useAssistantStore((s) => s.error);
  const micOwner = useAssistantStore((s) => s.micOwner);
  const volumeRms = useAssistantStore((s) => s.volumeRms);

  const isThinking = useIsLlmThinking();
  const isGenerating = useIsLlmGenerating();
  const isError = useIsLlmError();
  const isListening = useIsSttListening();
  const isTranscribing = useIsSttTranscribing();

  const clearInputAndTranscript = useCallback(() => {
    useAssistantStore.getState().setDraftText('');
    useAssistantStore.getState().setTranscript('');
  }, []);

  return {
    isThinking,
    isGenerating,
    isListening,
    isTranscribing,
    isError,
    response,
    transcript,
    error,
    micOwner,
    volumeRms,
    requestOrigin,
    assistantRunId,
    clearInputAndTranscript,
  };
}
