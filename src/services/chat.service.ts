import { Share } from 'react-native';
import database from '@/database/Database';
import {
  CreateMessageInput,
  CreateSessionInput,
  Message,
  Session,
  UpdateSessionInput,
} from '@/database/types';
import { useChatStore } from '@/store';
import { stubAction } from '@/utils';

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
    return database.sessions.createSession(titleOrInput);
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

  async saveMessage(input: CreateMessageInput): Promise<Message> {
    return database.messages.saveMessage(input);
  },

  async getHistory(sessionId: string, limit: number = 20): Promise<Message[]> {
    return database.messages.getHistory(sessionId, limit);
  },

  async loadSessions(includeArchived: boolean = false): Promise<Session[]> {
    const sessions = await database.sessions.getSessions(includeArchived);
    useChatStore.getState().setSessions(sessions);
    return sessions;
  },

  async syncSessions(): Promise<void> {
    const sessions = await database.sessions.getSessions(false);
    useChatStore.getState().mergeSessions(sessions);
  },

  beginNewChat(): void {
    const store = useChatStore.getState();
    store.setChatSessionId(null);
    store.setMessages([]);
  },

  async openChat(sessionId: string): Promise<void> {
    const store = useChatStore.getState();
    store.setChatSessionId(sessionId);
    store.setMessages([]);

    const msgs = await database.messages.getMessages(sessionId);
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
  },

  async renameChat(id: string, title: string): Promise<void> {
    useChatStore.getState().renameSession(id, title);
    await database.sessions.updateSessionTitle(id, title);
  },

  async pinChat(id: string, pinned: boolean): Promise<void> {
    useChatStore.getState().pinSession(id, pinned);
    await database.sessions.pinSession(id, pinned);
  },

  async archiveChat(id: string, archived: boolean): Promise<void> {
    useChatStore.getState().archiveSession(id, archived);
    await database.sessions.archiveSession(id, archived);
  },

  async deleteChat(id: string): Promise<void> {
    const store = useChatStore.getState();
    store.deleteSession(id);
    if (store.chatSessionId === id) {
      this.beginNewChat();
    }
    await database.sessions.deleteSession(id);
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

      // if user role, we might be reconciling an optimistic send
      if (role === 'user') {
        const msgs = currentStore.messages;
        const sendingIdx = msgs.map((m) => m.status).lastIndexOf('sending');
        if (sendingIdx >= 0 && msgs[sendingIdx].role === 'user') {
          // Replace it
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

  editMessage(messageId: string): void {
    stubAction('editMessage');
  },

  regenerateResponse(messageId: string): void {
    stubAction('regenerateResponse');
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
};
