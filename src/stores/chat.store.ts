import { create } from 'zustand';
import { Session } from '@/database';
import { ChatMessage } from '@/types';

interface ChatStore {
  chatSessionId: string | null;
  sessions: Session[];
  messages: ChatMessage[];
  chatInputHeight: number;
  isLoadingMessages: boolean;
  hasMoreMessages: boolean;

  setChatSessionId: (chatSessionId: string | null) => void;
  setSessions: (sessions: Session[]) => void;
  setMessages: (messages: ChatMessage[]) => void;
  setChatInputHeight: (chatInputHeight: number) => void;
  setIsLoadingMessages: (loading: boolean) => void;
  setHasMoreMessages: (hasMore: boolean) => void;
  prependMessages: (messages: ChatMessage[]) => void;
  mergeSessions: (incoming: Session[]) => void;
  upsertSession: (session: Session) => void;
  renameSession: (sessionId: string, title: string) => void;
  pinSession: (sessionId: string, pinned: boolean) => void;
  archiveSession: (sessionId: string, archived: boolean) => void;
  deleteSession: (sessionId: string) => void;
  upsertMessage: (message: ChatMessage) => void;
  appendMessageChunk: (messageId: string, chunk: string) => void;
  completeMessageStream: (messageId: string, fullText: string) => void;
}

export const useChatStore = create<ChatStore>()((set) => ({
  chatSessionId: null,
  sessions: [],
  messages: [],
  chatInputHeight: 0,
  isLoadingMessages: false,
  hasMoreMessages: true,

  setChatSessionId: (chatSessionId) => set({ chatSessionId }),
  setSessions: (sessions) => set({ sessions }),
  setMessages: (messages) => set({ messages }),
  setChatInputHeight: (chatInputHeight) => set({ chatInputHeight }),
  setIsLoadingMessages: (isLoadingMessages) => set({ isLoadingMessages }),
  setHasMoreMessages: (hasMoreMessages) => set({ hasMoreMessages }),
  prependMessages: (newMessages) =>
    set((state) => ({ messages: [...newMessages, ...state.messages] })),

  mergeSessions: (incoming) =>
    set((state) => {
      const existingIds = new Set(state.sessions.map((s) => s.id));
      const newSessions = incoming.filter((s) => !existingIds.has(s.id));

      const patchExisting = (list: Session[]) =>
        list.map((s) => {
          const match = incoming.find((i) => i.id === s.id);
          return match ? { ...s, ...match } : s;
        });

      const hasNoPatches = state.sessions.every((s) => {
        const match = incoming.find((i) => i.id === s.id);
        return (
          !match ||
          (match.title === s.title &&
            match.pinned === s.pinned &&
            match.archived === s.archived &&
            match.updatedAt === s.updatedAt)
        );
      });

      if (newSessions.length === 0) {
        if (hasNoPatches) return state;
        return { sessions: patchExisting(state.sessions) };
      }

      return { sessions: [...newSessions, ...patchExisting(state.sessions)] };
    }),

  upsertSession: (session) =>
    set((state) => {
      const exists = state.sessions.some((s) => s.id === session.id);
      const updated = exists
        ? state.sessions.map((s) =>
            s.id === session.id ? { ...s, ...session } : s,
          )
        : [session, ...state.sessions];

      updated.sort((a, b) => {
        if (Boolean(a.pinned) !== Boolean(b.pinned)) {
          return a.pinned ? -1 : 1;
        }
        return (b.updatedAt || 0) - (a.updatedAt || 0);
      });

      return { sessions: updated };
    }),

  renameSession: (sessionId, title) =>
    set((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === sessionId ? { ...s, title } : s,
      ),
    })),

  pinSession: (sessionId, pinned) =>
    set((state) => {
      const updated = state.sessions.map((s) =>
        s.id === sessionId ? { ...s, pinned } : s,
      );
      updated.sort((a, b) => {
        if (Boolean(a.pinned) !== Boolean(b.pinned)) {
          return a.pinned ? -1 : 1;
        }
        return (b.updatedAt || 0) - (a.updatedAt || 0);
      });
      return { sessions: updated };
    }),

  archiveSession: (sessionId, archived) =>
    set((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === sessionId ? { ...s, archived } : s,
      ),
      messages:
        state.chatSessionId === sessionId && archived ? [] : state.messages,
      chatSessionId:
        state.chatSessionId === sessionId && archived
          ? null
          : state.chatSessionId,
    })),

  deleteSession: (sessionId) =>
    set((state) => ({
      sessions: state.sessions.filter((s) => s.id !== sessionId),
      messages: state.chatSessionId === sessionId ? [] : state.messages,
      chatSessionId:
        state.chatSessionId === sessionId ? null : state.chatSessionId,
    })),

  upsertMessage: (message) =>
    set((state) => {
      const targetSessionId = state.chatSessionId || message.sessionId;
      if (
        message.sessionId &&
        targetSessionId &&
        message.sessionId !== targetSessionId
      )
        return state;

      const exists = state.messages.find((m) => m.id === message.id);
      if (exists) {
        return {
          chatSessionId: targetSessionId,
          messages: state.messages.map((m) =>
            m.id === message.id
              ? {
                  ...m,
                  ...message,
                  status: message.status || m.status || 'sent',
                }
              : m,
          ),
        };
      }
      return {
        chatSessionId: targetSessionId,
        messages: [
          ...state.messages,
          { ...message, status: message.status || 'sent' },
        ],
      };
    }),

  appendMessageChunk: (messageId, chunk) =>
    set((state) => {
      const exists = state.messages.find((m) => m.id === messageId);
      if (!exists) {
        return {
          messages: [
            ...state.messages,
            {
              id: messageId,
              role: 'assistant',
              text: chunk,
              sessionId: state.chatSessionId,
              status: 'sent',
            },
          ],
        };
      }
      return {
        messages: state.messages.map((m) =>
          m.id === messageId ? { ...m, text: m.text + chunk } : m,
        ),
      };
    }),

  completeMessageStream: (messageId, fullText) =>
    set((state) => {
      const exists = state.messages.find((m) => m.id === messageId);
      if (!exists) {
        return {
          messages: [
            ...state.messages,
            {
              id: messageId,
              role: 'assistant',
              text: fullText,
              sessionId: state.chatSessionId,
              status: 'sent',
            },
          ],
        };
      }
      return {
        messages: state.messages.map((m) =>
          m.id === messageId
            ? { ...m, text: fullText || m.text, status: 'sent' }
            : m,
        ),
      };
    }),
}));
