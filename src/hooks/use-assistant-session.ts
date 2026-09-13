import { useAssistantSessionStore, useChatInputStore } from '@/store';

export { useAssistantSessionStore };

export function useAssistantSession() {
  const store = useAssistantSessionStore();

  const clearInputAndTranscript = () => {
    useChatInputStore.getState().setDraftText('');
    store.setTranscript('');
  };

  return {
    canonicalState: store.canonicalState,
    isThinking: store.canonicalState === 'THINKING',
    isGenerating: store.canonicalState === 'GENERATING',
    isListening: store.canonicalState === 'LISTENING',
    isTranscribing: store.canonicalState === 'TRANSCRIBING',
    isError: store.canonicalState === 'ERROR',
    response: store.response,
    transcript: store.transcript,
    error: store.error,
    micOwner: store.micOwner,
    volumeRms: store.volumeRms,
    requestOrigin: store.requestOrigin,
    assistantRunId: store.assistantRunId,
    requestId: store.requestId,
    clearInputAndTranscript,
  };
}
