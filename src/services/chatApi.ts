import { useAssistantStore } from '@/store/assistantStore';
import {
  beginNewChat,
  deleteChat,
  loadSessions,
  NativeChatSession,
  openChat,
  renameChat,
  pinChat,
  archiveChat,
} from '@modules/kritha/src';

export type ChatSession = NativeChatSession;

export const chatApi = {
  loadSessions: (): ChatSession[] => loadSessions(),
  beginNewChat: (): void => beginNewChat(),
  openChat: (sessionId: string): void => {
    const store = useAssistantStore.getState();
    store.setChatSessionId(sessionId);
    store.setMessages([]);
    store.setResponse('');
    store.setTranscript('');
    openChat(sessionId);
  },
  renameChat: (id: string, title: string): void => {
    renameChat(id, title);
  },
  pinChat: (id: string, pinned: boolean): void => {
    pinChat(id, pinned);
  },
  archiveChat: (id: string, archived: boolean): void => {
    archiveChat(id, archived);
  },
  deleteChat: (id: string): void => {
    deleteChat(id);
  },
};
