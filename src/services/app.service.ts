import { database } from '@/database';
import { useChatStore, useWakewordStore } from '@/stores';
import {
  addWakeWordListener,
  isDefaultAssistant,
  isNotificationListenerEnabled,
  isRunning,
  openAssistantSettings,
  requestNotificationListenerPermission,
  start,
  stop,
} from '@modules/kritha/src';
import { ChatSessionService } from './chat.service';
import { SoniqoCoordinator } from './soniqoRuntime.service';

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

    addWakeWordListener((event) => {
      console.log('Wake word detected', event);
      SoniqoCoordinator.handleWakeWordDetected();
    });
  } catch (err) {
    console.warn('Failed to load startup settings or database:', err);
  }
};
