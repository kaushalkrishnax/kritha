import { create } from 'zustand';
import uuid from 'react-native-uuid';
import {
  ChatMode,
  LiveTalkPhase,
  LlmPhase,
  MicOwner,
  RequestOrigin,
  SttPhase,
  TtsPhase,
} from '@/constants';

interface AssistantData {
  llmPhase: LlmPhase;
  sttPhase: SttPhase;
  ttsPhase: TtsPhase;
  chatMode: ChatMode;
  liveTalkPhase: LiveTalkPhase | null;
  isSttModelLoading: boolean;
  isTtsModelLoading: boolean;

  assistantRunId: string | null;
  requestOrigin: RequestOrigin | null;
  draftText: string;
  transcript: string;
  response: string;
  error: string | null;

  micOwner: MicOwner;
  volumeRms: number;
  currentTtsMessageId: string | null;
  editingMessageId: string | null;
}

interface AssistantActions {
  setLlmPhase: (phase: LlmPhase) => void;
  setSttPhase: (phase: SttPhase) => void;
  setTtsPhase: (phase: TtsPhase) => void;
  setChatMode: (mode: ChatMode) => void;
  setLiveTalkPhase: (phase: LiveTalkPhase | null) => void;
  setSttModelLoading: (loading: boolean) => void;
  setTtsModelLoading: (loading: boolean) => void;
  startRun: (origin: RequestOrigin) => string;
  setDraftText: (text: string) => void;
  setTranscript: (text: string) => void;
  setResponse: (text: string) => void;
  appendResponse: (chunk: string) => void;
  setError: (error: string | null) => void;
  setMic: (owner: MicOwner, volumeRms?: number) => void;
  setCurrentTtsMessageId: (id: string | null) => void;
  setEditingMessageId: (id: string | null) => void;
  reset: () => void;
}

export type AssistantState = AssistantData & AssistantActions;

const initialData: AssistantData = {
  llmPhase: LlmPhase.IDLE,
  sttPhase: SttPhase.IDLE,
  ttsPhase: TtsPhase.IDLE,
  chatMode: ChatMode.TEXTING,
  liveTalkPhase: null,
  isSttModelLoading: false,
  isTtsModelLoading: false,

  assistantRunId: null,
  requestOrigin: null,
  draftText: '',
  transcript: '',
  response: '',
  error: null,

  micOwner: MicOwner.NONE,
  volumeRms: 0,
  currentTtsMessageId: null,
  editingMessageId: null,
};

export const useAssistantStore = create<AssistantState>()((set, get) => ({
  ...initialData,

  setLlmPhase: (llmPhase) => set({ llmPhase }),
  setSttPhase: (sttPhase) => set({ sttPhase }),
  setTtsPhase: (ttsPhase) => set({ ttsPhase }),
  setChatMode: (chatMode) => set({ chatMode }),
  setLiveTalkPhase: (liveTalkPhase) => set({ liveTalkPhase }),
  setSttModelLoading: (isSttModelLoading) => set({ isSttModelLoading }),
  setTtsModelLoading: (isTtsModelLoading) => set({ isTtsModelLoading }),

  startRun: (origin) => {
    const assistantRunId = uuid.v4();
    set({ assistantRunId, requestOrigin: origin, response: '', error: null });
    return assistantRunId;
  },

  setDraftText: (draftText) => set({ draftText }),
  setTranscript: (transcript) => set({ transcript }),
  setResponse: (response) => set({ response }),
  appendResponse: (chunk) => set((s) => ({ response: s.response + chunk })),
  setError: (error) => set({ error }),
  setMic: (micOwner, volumeRms = 0) => set({ micOwner, volumeRms }),
  setCurrentTtsMessageId: (currentTtsMessageId) => set({ currentTtsMessageId }),
  setEditingMessageId: (editingMessageId) => set({ editingMessageId }),

  reset: () => set({ ...initialData }),
}));

export const selectIsLlmBusy = (s: AssistantState) =>
  s.llmPhase !== LlmPhase.IDLE && s.llmPhase !== LlmPhase.ERROR;
export const selectIsLlmThinking = (s: AssistantState) =>
  s.llmPhase === LlmPhase.SUBMITTING || s.llmPhase === LlmPhase.THINKING;
export const selectIsLlmGenerating = (s: AssistantState) =>
  s.llmPhase === LlmPhase.GENERATING;
export const selectIsLlmError = (s: AssistantState) =>
  s.llmPhase === LlmPhase.ERROR;

export const selectIsSttListening = (s: AssistantState) =>
  s.sttPhase === SttPhase.LISTENING;
export const selectIsSttTranscribing = (s: AssistantState) =>
  s.sttPhase === SttPhase.TRANSCRIBING;

export const selectIsTtsSpeaking = (s: AssistantState) =>
  s.ttsPhase === TtsPhase.SPEAKING;
export const selectIsTtsPaused = (s: AssistantState) =>
  s.ttsPhase === TtsPhase.PAUSED;

export const selectIsDictating = (s: AssistantState) =>
  s.chatMode === ChatMode.DICTATION;
export const selectIsLiveTalk = (s: AssistantState) =>
  s.chatMode === ChatMode.LIVE_TALK;

export const useIsLlmBusy = () => useAssistantStore(selectIsLlmBusy);
export const useIsLlmThinking = () => useAssistantStore(selectIsLlmThinking);
export const useIsLlmGenerating = () =>
  useAssistantStore(selectIsLlmGenerating);
export const useIsLlmError = () => useAssistantStore(selectIsLlmError);
export const useIsSttListening = () => useAssistantStore(selectIsSttListening);
export const useIsSttTranscribing = () =>
  useAssistantStore(selectIsSttTranscribing);
export const useIsTtsSpeaking = () => useAssistantStore(selectIsTtsSpeaking);
export const useIsTtsPaused = () => useAssistantStore(selectIsTtsPaused);
export const useIsTtsModelLoading = () =>
  useAssistantStore((s) => s.isTtsModelLoading);
export const useIsSttModelLoading = () =>
  useAssistantStore((s) => s.isSttModelLoading);
export const useIsDictating = () => useAssistantStore(selectIsDictating);
export const useIsLiveTalk = () => useAssistantStore(selectIsLiveTalk);
