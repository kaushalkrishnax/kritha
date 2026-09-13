import { ChatSessionService } from '@/services';
import { useChatStore } from '@/store';

export function useSidebar() {
  const sessions = useChatStore((s) => s.sessions);
  const activeSessionId = useChatStore((s) => s.chatSessionId);

  const activeSessions = sessions.filter((s) => !s.archived);
  const archivedSessions = sessions.filter((s) => s.archived);
  const pinnedSessions = activeSessions.filter((s) => s.pinned);
  const recentSessions = activeSessions.filter((s) => !s.pinned);

  return {
    sessions,
    activeSessionId,
    pinnedSessions,
    recentSessions,
    archivedSessions,
    loadSessions: ChatSessionService.loadSessions,
  };
}
