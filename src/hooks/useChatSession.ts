import { ChatSessionService } from '@/services';
import { useAssistantStore } from '@/stores';

export function useChatSession() {
  const beginNewChat = () => {
    ChatSessionService.beginNewChat();
    useAssistantStore.getState().reset();
  };

  const openChat = async (sessionId: string) => {
    await ChatSessionService.openChat(sessionId);
    useAssistantStore.getState().reset();
  };

  const setSessionError = (error: string | null) => {
    useAssistantStore.getState().setError(error);
  };

  return {
    beginNewChat,
    openChat,
    setSessionError,
  };
}