import { ChatSessionService } from '@/services';
import { useAssistantSessionStore, useChatInputStore } from '@/store';

export function useChatSession() {
  const beginNewChat = () => {
    ChatSessionService.beginNewChat();
    useAssistantSessionStore.getState().reset();
    useChatInputStore.getState().reset();
  };

  const openChat = async (sessionId: string) => {
    await ChatSessionService.openChat(sessionId);
    useAssistantSessionStore.getState().reset();
    useChatInputStore.getState().reset();
  };

  const setSessionError = (error: string | null) => {
    useAssistantSessionStore.getState().setError(error);
  };

  return {
    beginNewChat,
    openChat,
    setSessionError,
  };
}
