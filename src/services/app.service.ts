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
import { useWakewordStore } from '@/stores';

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
    
    useWakewordStore
      .getState()
      .setIsEnabled(AssistantBridge.isWakewordRunning());
  } catch (err) {
    console.warn('Failed to load startup settings or database:', err);
  }
};
