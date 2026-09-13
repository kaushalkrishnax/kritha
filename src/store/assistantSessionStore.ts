import { create } from 'zustand';

export interface AssistantSessionStore {
  assistantRunId: string | null;
  requestId: string | null;
  // ::TODO:: Implement assistant runtime and fix this type to use RequestOrigin instead of 'null'
  // requestOrigin: RequestOrigin | null; 
  requestOrigin: null;
  sessionActive: boolean;
  // ::TODO:: Implement assistant runtime and fix this type to use CanonicalAssistantState instead of 'null'
  // canonicalState: CanonicalAssistantState;
  canonicalState: null;
  transcript: string;
  response: string;

  //  ::TODO:: Implement Mic management and fix this type to use MicOwner instead of 'NONE'
  micOwner: 'NONE';
  isMicAvailable: boolean;
  volumeRms: number;
  error: string | null;

  setAssistantRunId: (assistantRunId: string | null) => void;
  setRequestId: (requestId: string | null) => void;

  // ::TODO:: Implement assistant runtime and fix this type to use RequestOrigin instead of 'null'
  // setRequestOrigin: (requestOrigin: RequestOrigin | null) => void;
  setRequestOrigin: (requestOrigin: null) => void;
  setSessionActive: (active: boolean) => void;

  // ::TODO:: Implement assistant runtime and fix this type to use CanonicalAssistantState instead of 'null'
  // setCanonicalState: (canonicalState: CanonicalAssistantState) => void;
  setCanonicalState: (canonicalState: null) => void;
  setTranscript: (transcript: string) => void;
  setResponse: (response: string) => void;
  appendResponse: (chunk: string) => void;
  setMicState: (
    // ::TODO:: Implement Mic Management and fix this type to use MicOwner instead of 'NONE'
    // owner: MicOwner | 'NONE',
    owner: 'NONE',
    available: boolean,
    volumeRms?: number,
  ) => void;
  setError: (error: string | null) => void;
  reset: () => void;
}

export const useAssistantSessionStore = create<AssistantSessionStore>()(
  (set) => ({
    assistantRunId: null,
    requestId: null,
    requestOrigin: null,
    sessionActive: false,
    // ::TODO:: Implement assistant runtime and fix this to use 'IDLE' instead of 'null'
    // canonicalState: 'IDLE',
    canonicalState: null,
    transcript: '',
    response: '',
    micOwner: 'NONE',
    isMicAvailable: false,
    volumeRms: 0,
    error: null,

    setAssistantRunId: (assistantRunId) => set({ assistantRunId }),
    setRequestId: (requestId) => set({ requestId }),
    setRequestOrigin: (requestOrigin) => set({ requestOrigin }),
    setSessionActive: (active) => set({ sessionActive: active }),
    setCanonicalState: (canonicalState) => set({ canonicalState }),
    setTranscript: (transcript) => set({ transcript }),
    setResponse: (response) => set({ response }),
    appendResponse: (chunk) =>
      set((state) => ({ response: state.response + chunk })),

    setMicState: (owner, available, volumeRms = 0) =>
      set((state) =>
        state.micOwner === owner &&
          state.isMicAvailable === available &&
          state.volumeRms === volumeRms
          ? state
          : { micOwner: owner, isMicAvailable: available, volumeRms },
      ),

    setError: (error) =>
      // ::TODO:: Implement assistant runtime and fix this type to use 'ERROR'/'IDLE' instead of 'null'
      // set({ error, canonicalState: error ? 'ERROR' : 'IDLE' }),
      set({ error, canonicalState: error ? null : null }),

    reset: () => set({ response: '', transcript: '', error: null }),
  }),
);
