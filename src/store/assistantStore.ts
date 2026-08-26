import {
  CanonicalAssistantState,
  MicOwner,
  RequestOrigin,
} from '@modules/kritha/src';
import { Session } from '@/database';
import { create } from 'zustand';

export type AssistantMessage = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  sessionId?: string | null;
  createdAt?: number;
};

interface AssistantStore {
  chatSessionId: string | null;
  assistantRunId: string | null;
  requestId: string | null;
  requestOrigin: RequestOrigin | null;
  sessionActive: boolean;
  canonicalState: CanonicalAssistantState;

  transcript: string;
  draftText: string; 
  response: string;
  
  micOwner: MicOwner;
  isMicAvailable: boolean;
  volumeRms: number;
  
  isLiveTalk: boolean; 
  isLiveTalkHeld: boolean;
  isTtsSpeaking: boolean;
  isTtsPaused: boolean;
  currentTtsMsgId: string | null;
  
  error: string | null;
  userName: string;

  setUserName: (userName: string) => void;
  setChatSessionId: (id: string | null) => void;
  setAssistantRunId: (id: string | null) => void;
  setRequestId: (id: string | null) => void;
  setRequestOrigin: (origin: RequestOrigin | null) => void;
  setSessionActive: (active: boolean) => void;
  setCanonicalState: (state: CanonicalAssistantState) => void;
  
  setTranscript: (transcript: string) => void;
  setDraftText: (text: string) => void;
  setResponse: (response: string) => void;
  appendResponse: (chunk: string) => void;
  
  setIsLiveTalk: (isLive: boolean) => void;
  setIsLiveTalkHeld: (held: boolean) => void;

  setMicState: (owner: MicOwner, available: boolean, volumeRms?: number) => void;
  setTtsState: (speaking: boolean, paused: boolean, msgId?: string | null) => void;
  setError: (error: string | null) => void;

  sessions: Session[];
  messages: AssistantMessage[];
  setSessions: (sessions: Session[]) => void;
  setMessages: (messages: AssistantMessage[]) => void;
  upsertSession: (session: Session) => void;
  deleteSession: (sessionId: string) => void;
  archiveSession: (sessionId: string, archived: boolean) => void;
  pinSession: (sessionId: string, pinned: boolean) => void;
  renameSession: (sessionId: string, title: string) => void;
  upsertMessage: (message: AssistantMessage) => void;
  appendMessageChunk: (messageId: string, chunk: string) => void;
  completeMessageStream: (messageId: string, fullText: string) => void;

  reset: () => void;
}

export const useAssistantStore = create<AssistantStore>((set) => ({
  chatSessionId: null,
  assistantRunId: null,
  requestId: null,
  requestOrigin: null,
  sessionActive: false,
  canonicalState: 'IDLE',
  transcript: '',
  draftText: '',
  response: '',
  micOwner: 'NONE',
  isMicAvailable: false,
  volumeRms: 0,
  isLiveTalk: false,
  isLiveTalkHeld: false,
  isTtsSpeaking: false,
  isTtsPaused: false,
  currentTtsMsgId: null,
  error: null,
  userName: 'Your Name',
  sessions: [],
  messages: [],

  setUserName: (userName) => set({ userName }),
  setChatSessionId: (chatSessionId) => set({ chatSessionId }),
  setAssistantRunId: (assistantRunId) => set({ assistantRunId }),
  setRequestId: (requestId) => set({ requestId }),
  setRequestOrigin: (requestOrigin) => set({ requestOrigin }),
  setSessionActive: (active) => set({ sessionActive: active }),
  setCanonicalState: (canonicalState) => set({ canonicalState }),
  setTranscript: (transcript) => set({ transcript }),
  setDraftText: (draftText) => set({ draftText }),
  setIsLiveTalk: (isLiveTalk) => set({ isLiveTalk }),
  setIsLiveTalkHeld: (isLiveTalkHeld) => set({ isLiveTalkHeld }),
  
  setResponse: (response) => set({ response }),
  appendResponse: (chunk) => set((state) => ({ response: state.response + chunk })),
  
  setMicState: (owner, available, volumeRms = 0) =>
    set((state) =>
      state.micOwner === owner && state.isMicAvailable === available && state.volumeRms === volumeRms
        ? state
        : { micOwner: owner, isMicAvailable: available, volumeRms },
    ),
  setTtsState: (speaking, paused, msgId = null) =>
    set({
      isTtsSpeaking: speaking,
      isTtsPaused: paused,
      currentTtsMsgId: speaking || paused ? msgId : null,
    }),
  setError: (error) => set({ error, canonicalState: error ? 'ERROR' : 'IDLE' }),

  setSessions: (sessions) => set({ sessions }),
  setMessages: (messages) => set({ messages }),
  upsertSession: (session) =>
    set((state) => {
      const exists = state.sessions.find((s) => s.id === session.id);
      if (exists) {
        return { sessions: state.sessions.map((s) => (s.id === session.id ? { ...s, ...session } : s)) };
      }
      return { sessions: [session, ...state.sessions] };
    }),
  renameSession: (sessionId, title) =>
    set((state) => ({ sessions: state.sessions.map((s) => (s.id === sessionId ? { ...s, title } : s)) })),
  pinSession: (sessionId, pinned) =>
    set((state) => ({ sessions: state.sessions.map((s) => (s.id === sessionId ? { ...s, pinned } : s)) })),
  archiveSession: (sessionId, archived) =>
    set((state) => ({
      sessions: state.sessions.map((s) => (s.id === sessionId ? { ...s, archived } : s)),
      messages: state.chatSessionId === sessionId && archived ? [] : state.messages,
      chatSessionId: state.chatSessionId === sessionId && archived ? null : state.chatSessionId,
    })),
  deleteSession: (sessionId) =>
    set((state) => ({
      sessions: state.sessions.filter((s) => s.id !== sessionId),
      messages: state.chatSessionId === sessionId ? [] : state.messages,
      chatSessionId: state.chatSessionId === sessionId ? null : state.chatSessionId,
    })),
  upsertMessage: (message) =>
    set((state) => {
      const targetSessionId = state.chatSessionId || message.sessionId;
      if (message.sessionId && targetSessionId && message.sessionId !== targetSessionId) return state;
      
      const exists = state.messages.find((m) => m.id === message.id);
      if (exists) {
        return {
          chatSessionId: targetSessionId,
          messages: state.messages.map((m) => (m.id === message.id ? { ...m, ...message } : m)),
        };
      }
      return { chatSessionId: targetSessionId, messages: [...state.messages, message] };
    }),
  appendMessageChunk: (messageId, chunk) =>
    set((state) => {
      const exists = state.messages.find((m) => m.id === messageId);
      if (!exists) {
        return { messages: [...state.messages, { id: messageId, role: 'assistant', text: chunk, sessionId: state.chatSessionId }] };
      }
      return { messages: state.messages.map((m) => (m.id === messageId ? { ...m, text: m.text + chunk } : m)) };
    }),
  completeMessageStream: (messageId, fullText) =>
    set((state) => {
      const exists = state.messages.find((m) => m.id === messageId);
      if (!exists) {
        return { messages: [...state.messages, { id: messageId, role: 'assistant', text: fullText, sessionId: state.chatSessionId }] };
      }
      return { messages: state.messages.map((m) => (m.id === messageId ? { ...m, text: fullText || m.text } : m)) };
    }),

  reset: () =>
    set({
      chatSessionId: null,
      assistantRunId: null,
      requestId: null,
      requestOrigin: null,
      sessionActive: false,
      canonicalState: 'IDLE',
      transcript: '',
      draftText: '',
      response: '',
      micOwner: 'NONE',
      isMicAvailable: false,
      volumeRms: 0,
      isLiveTalk: false,
      isLiveTalkHeld: false,
      isTtsSpeaking: false,
      isTtsPaused: false,
      currentTtsMsgId: null,
      error: null,
      messages: [],
    }),
}));