import {
  isDefaultAssistant,
  isNotificationListenerEnabled,
  isRunning,
  openAssistantSettings,
  requestNotificationListenerPermission,
  start,
  stop,
} from '@modules/kritha/src';
import { database } from '@/database';
import { useChatStore, useWakewordStore } from '@/stores';
import { ChatSessionService } from './chat.service';

export const AssistantBridge = {
  startWakewordListening: start,
  stopWakewordListening: stop,
  isWakewordRunning: isRunning,
  isDefaultAssistant,
  isNotificationListenerEnabled,
  openAssistantSettings,
  requestNotificationListenerPermission,
};

// App Bootstrap
export const bootstrapApp = async (): Promise<void> => {
  try {
    await database.init();

    await ChatSessionService.loadSessions(true);

    // Always open an empty chat window by default, do not default to latest/topmost chat
    useChatStore.getState().setChatSessionId(null);
    useChatStore.getState().setMessages([]);

    useWakewordStore
      .getState()
      .setIsEnabled(AssistantBridge.isWakewordRunning());
  } catch (err) {
    console.warn('Failed to load startup settings or database:', err);
  }
};
