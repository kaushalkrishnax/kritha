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
import { SpeechCoordinator } from './speechRuntime.service';

export const AssistantBridge = {
  startWakewordListening: start,
  stopWakewordListening: stop,
  isWakewordRunning: isRunning,
  isDefaultAssistant,
  isNotificationListenerEnabled,
  openAssistantSettings,
  requestNotificationListenerPermission,
};

export const bootstrapApp = async (): Promise<void> => {
  try {
    await database.init();

    await ChatSessionService.loadSessions(true);

    // Keep an active wake-word session (overlay expand opens the same chat);
    // otherwise always open an empty chat window by default.
    const currentId = useChatStore.getState().chatSessionId;
    const current = currentId
      ? useChatStore.getState().sessions.find((s) => s.id === currentId)
      : null;
    if (current?.origin !== 'wake_word') {
      useChatStore.getState().setChatSessionId(null);
      useChatStore.getState().setMessages([]);
    }

    useWakewordStore
      .getState()
      .setIsEnabled(AssistantBridge.isWakewordRunning());

    addWakeWordListener((event) => {
      console.log('Wake word detected', event);
      SpeechCoordinator.handleWakeWordDetected();
    });
  } catch (err) {
    console.warn('Failed to load startup settings or database:', err);
  }
};
