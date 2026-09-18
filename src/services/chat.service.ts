import { Share } from 'react-native';

import database from '@/database/Database';
import {
  CreateMessageInput,
  CreateSessionInput,
  Message,
  Session,
  UpdateSessionInput,
} from '@/database/types';
import { useChatStore } from '@/stores';

export const ChatSessionService = {
  async getSessions(includeArchived: boolean = false): Promise<Session[]> {
    return database.sessions.getSessions(includeArchived);
  },

  async getSession(id: string): Promise<Session | null> {
    return database.sessions.getSession(id);
  },

  async createSession(
    titleOrInput: string | CreateSessionInput,
  ): Promise<Session> {
    const session = await database.sessions.createSession(titleOrInput);
    useChatStore.getState().upsertSession(session);
    return session;
  },

  async updateSession(id: string, input: UpdateSessionInput): Promise<Session> {
    return database.sessions.updateSession(id, input);
  },

  async renameSession(id: string, title: string): Promise<Session> {
    return database.sessions.updateSessionTitle(id, title);
  },

  async pinSession(id: string, pinned: boolean): Promise<Session> {
    return database.sessions.pinSession(id, pinned);
  },

  async archiveSession(id: string, archived: boolean): Promise<Session> {
    return database.sessions.archiveSession(id, archived);
  },

  async deleteSession(id: string): Promise<void> {
    return database.sessions.deleteSession(id);
  },

  async getMessages(sessionId: string): Promise<Message[]> {
    return database.messages.getMessages(sessionId);
  },

  async loadSessions(includeArchived: boolean = true): Promise<Session[]> {
    const sessions = await database.sessions.getSessions(includeArchived);
    useChatStore.getState().setSessions(sessions);
    return sessions;
  },

  async syncSessions(): Promise<void> {
    const sessions = await database.sessions.getSessions(true);
    useChatStore.getState().mergeSessions(sessions);
  },

  async createNewChat(title: string = 'New Chat'): Promise<Session> {
    const session = await database.sessions.createSession({ title });
    const store = useChatStore.getState();
    store.upsertSession(session);
    store.setChatSessionId(session.id);
    store.setMessages([]);
    return session;
  },

  async beginNewChat(): Promise<void> {
    const store = useChatStore.getState();
    store.setChatSessionId(null);
    store.setMessages([]);
  },

  async openChat(sessionId: string): Promise<void> {
    const store = useChatStore.getState();
    store.setChatSessionId(sessionId);
    store.setMessages([]);
    store.setHasMoreMessages(true);
    store.setIsLoadingMessages(true);

    try {
      const msgs = await database.messages.getMessages(sessionId, 20, 0);
      store.setMessages(
        msgs.map((m) => ({
          id: m.id,
          sessionId: m.sessionId,
          role: m.role as 'user' | 'assistant',
          text: m.content,
          createdAt: m.createdAt,
          status: 'sent',
        })),
      );
      if (msgs.length < 20) {
        store.setHasMoreMessages(false);
      }
    } finally {
      store.setIsLoadingMessages(false);
    }
  },

  async loadMoreMessages(): Promise<void> {
    const store = useChatStore.getState();
    const sessionId = store.chatSessionId;
    if (!sessionId || store.isLoadingMessages || !store.hasMoreMessages) return;

    store.setIsLoadingMessages(true);
    try {
      const currentCount = store.messages.length;
      const msgs = await database.messages.getMessages(
        sessionId,
        20,
        currentCount,
      );

      if (msgs.length > 0) {
        store.prependMessages(
          msgs.map((m) => ({
            id: m.id,
            sessionId: m.sessionId,
            role: m.role as 'user' | 'assistant',
            text: m.content,
            createdAt: m.createdAt,
            status: 'sent',
          })),
        );
      }

      if (msgs.length < 20) {
        store.setHasMoreMessages(false);
      }
    } finally {
      store.setIsLoadingMessages(false);
    }
  },

  async renameChat(id: string, title: string): Promise<Session> {
    useChatStore.getState().renameSession(id, title);
    return database.sessions.updateSessionTitle(id, title);
  },

  async pinChat(id: string, pinned: boolean): Promise<Session> {
    useChatStore.getState().pinSession(id, pinned);
    return database.sessions.pinSession(id, pinned);
  },

  async archiveChat(id: string, archived: boolean): Promise<Session> {
    const store = useChatStore.getState();
    const wasCurrent = store.chatSessionId === id;
    store.archiveSession(id, archived);
    const updated = await database.sessions.archiveSession(id, archived);

    if (wasCurrent && archived) {
      const remaining = store.sessions.filter(
        (s) => !s.archived && s.id !== id,
      );
      if (remaining.length > 0) {
        await this.openChat(remaining[0].id);
      } else {
        await this.beginNewChat();
      }
    }
    return updated;
  },

  async deleteChat(id: string): Promise<void> {
    const store = useChatStore.getState();
    const wasCurrent = store.chatSessionId === id;
    store.deleteSession(id);
    await database.sessions.deleteSession(id);

    if (wasCurrent) {
      const remaining = store.sessions.filter(
        (s) => !s.archived && s.id !== id,
      );
      if (remaining.length > 0) {
        await this.openChat(remaining[0].id);
      } else {
        await this.beginNewChat();
      }
    }
  },

  async saveMessage(input: CreateMessageInput): Promise<Message> {
    const message = await database.messages.saveMessage(input);
    const session = await database.sessions.getSession(input.sessionId);
    if (session) {
      useChatStore.getState().upsertSession(session);
    }
    return message;
  },

  async shareChat(id: string): Promise<void> {
    try {
      const session = await this.getSession(id);
      if (!session) return;
      await Share.share({ message: session.title });
    } catch (e) {
      console.warn('Failed to share chat:', e);
    }
  },

  recordIncomingMessage(payload: any): void {
    const { chatSessionId, messageId, role, text, createdAt } = payload;
    if (chatSessionId && messageId) {
      const currentStore = useChatStore.getState();
      if (!currentStore.chatSessionId) {
        currentStore.setChatSessionId(chatSessionId);
      }

      let finalStatus = 'sent';
      if (payload.status === 'failed') finalStatus = 'failed';

      if (role === 'user') {
        const msgs = currentStore.messages;
        const sendingIdx = msgs.map((m) => m.status).lastIndexOf('sending');
        if (sendingIdx >= 0 && msgs[sendingIdx].role === 'user') {
          const updated = [...msgs];
          updated[sendingIdx] = {
            id: messageId,
            sessionId: chatSessionId,
            role: 'user',
            text,
            createdAt,
            status: finalStatus as 'sent' | 'failed',
          };
          currentStore.setMessages(updated);
        } else {
          currentStore.upsertMessage({
            id: messageId,
            sessionId: chatSessionId,
            role: 'user',
            text,
            createdAt,
            status: finalStatus as 'sent' | 'failed',
          });
        }
      } else {
        currentStore.upsertMessage({
          id: messageId,
          sessionId: chatSessionId,
          role: role as 'user' | 'assistant',
          text,
          createdAt,
          status: finalStatus as 'sent' | 'failed',
        });
      }

      if (finalStatus !== 'failed') {
        database.messages
          .saveMessage({
            sessionId: chatSessionId,
            role: role as 'user' | 'assistant',
            content: text,
            customId: messageId,
            createdAt,
          })
          .catch((err: unknown) =>
            console.error('[Database] Failed to persist message:', err),
          );
      }
    }
  },

  addOptimisticUserMessage(text: string): string {
    const tempId = Math.random().toString(36).substring(2, 15);
    const currentStore = useChatStore.getState();
    const sessionId = currentStore.chatSessionId;
    currentStore.upsertMessage({
      id: tempId,
      sessionId: sessionId,
      role: 'user',
      text,
      createdAt: Date.now(),
      status: 'sending',
    });
    return tempId;
  },

  async truncateMessages(
    sessionId: string,
    fromCreatedAt: number,
    runId?: string,
  ): Promise<void> {
    await database.messages.truncateMessages(sessionId, fromCreatedAt, runId);

    const store = useChatStore.getState();
    if (store.chatSessionId === sessionId) {
      const filtered = store.messages.filter(
        (m) => (m.createdAt ?? 0) < fromCreatedAt && m.runId !== runId,
      );
      store.setMessages(filtered);
    }
  },
};
