import database from '@/database/Database';
import { CreateMessageInput, CreateSessionInput, Message, Session, UpdateSessionInput } from '@/database/types';
import { useAssistantStore } from '@/store/assistantStore';

export const chatApi = {
  // Retrieves all chat sessions from local database.
  async getSessions(includeArchived: boolean = false): Promise<Session[]> {
    return database.sessions.getSessions(includeArchived);
  },

  // Retrieves a single chat session by ID.
  async getSession(id: string): Promise<Session | null> {
    return database.sessions.getSession(id);
  },

  // Creates a new chat session.
  async createSession(titleOrInput: string | CreateSessionInput): Promise<Session> {
    return database.sessions.createSession(titleOrInput);
  },

  // Updates session metadata (title, pinned, archived).
  async updateSession(id: string, input: UpdateSessionInput): Promise<Session> {
    return database.sessions.updateSession(id, input);
  },

  // Renames a chat session.
  async renameSession(id: string, title: string): Promise<Session> {
    return database.sessions.updateSessionTitle(id, title);
  },

  // Pins or unpins a chat session.
  async pinSession(id: string, pinned: boolean): Promise<Session> {
    return database.sessions.pinSession(id, pinned);
  },

  // Archives or unarchives a chat session.
  async archiveSession(id: string, archived: boolean): Promise<Session> {
    return database.sessions.archiveSession(id, archived);
  },

  // Deletes a chat session and all associated messages.
  async deleteSession(id: string): Promise<void> {
    return database.sessions.deleteSession(id);
  },

  // Retrieves all messages for a session.
  async getMessages(sessionId: string): Promise<Message[]> {
    return database.messages.getMessages(sessionId);
  },

  // Saves a message to a session.
  async saveMessage(input: CreateMessageInput): Promise<Message> {
    return database.messages.saveMessage(input);
  },

  // Gets recent context messages for LLM pipeline input.
  async getHistory(sessionId: string, limit: number = 20): Promise<Message[]> {
    return database.messages.getHistory(sessionId, limit);
  },

  // Loads sessions into the assistant store and returns them.
  async loadSessions(includeArchived: boolean = false): Promise<Session[]> {
    const sessions = await database.sessions.getSessions(includeArchived);
    useAssistantStore.getState().setSessions(sessions);
    return sessions;
  },

  beginNewChat(): void {
    const store = useAssistantStore.getState();
    store.setChatSessionId(null);
    store.setMessages([]);
    store.setResponse('');
    store.setTranscript('');
    store.setDraftText('');
    store.setError(null);
  },

  async openChat(sessionId: string): Promise<void> {
    const store = useAssistantStore.getState();
    store.setChatSessionId(sessionId);
    store.setMessages([]);
    store.setResponse('');
    store.setTranscript('');
    store.setDraftText('');
    store.setError(null);

    const msgs = await database.messages.getMessages(sessionId);
    store.setMessages(
      msgs.map((m) => ({
        id: m.id,
        sessionId: m.sessionId,
        role: m.role,
        text: m.content,
        createdAt: m.createdAt,
      }))
    );
  },

  async renameChat(id: string, title: string): Promise<void> {
    useAssistantStore.getState().renameSession(id, title);
    await database.sessions.updateSessionTitle(id, title);
  },

  async pinChat(id: string, pinned: boolean): Promise<void> {
    useAssistantStore.getState().pinSession(id, pinned);
    await database.sessions.pinSession(id, pinned);
  },

  async archiveChat(id: string, archived: boolean): Promise<void> {
    useAssistantStore.getState().archiveSession(id, archived);
    await database.sessions.archiveSession(id, archived);
  },

  async deleteChat(id: string): Promise<void> {
    const store = useAssistantStore.getState();
    store.deleteSession(id);
    if (store.chatSessionId === id) {
      this.beginNewChat();
    }
    await database.sessions.deleteSession(id);
  },
};
