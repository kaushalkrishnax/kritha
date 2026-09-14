import { ChatSessionService } from '@/services';
import { useAssistantStore } from '@/stores';

export function useChatSession() {
  const beginNewChat = async (title: string = 'New Chat') => {
    try {
      const session = await ChatSessionService.createNewChat(title);
      useAssistantStore.getState().reset();
      return session;
    } catch (e: any) {
      useAssistantStore
        .getState()
        .setError(e.message || 'Failed to create new chat session');
      throw e;
    }
  };

  const createNewChat = beginNewChat;

  const openChat = async (sessionId: string) => {
    try {
      await ChatSessionService.openChat(sessionId);
      useAssistantStore.getState().reset();
    } catch (e: any) {
      useAssistantStore.getState().setError(e.message || 'Failed to open chat');
      throw e;
    }
  };

  const setSessionError = (error: string | null) => {
    useAssistantStore.getState().setError(error);
  };

  return {
    beginNewChat,
    createNewChat,
    openChat,
    setSessionError,
  };
}
