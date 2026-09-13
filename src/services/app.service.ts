import * as SecureStore from 'expo-secure-store';
import { createMMKV } from 'react-native-mmkv';
import { StateStorage } from 'zustand/middleware';
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
import { useWakewordStore } from '@/store/wakewordStore';

// MMKV
const appMMKV = createMMKV({ id: 'kritha-storage' });

export const mmkvStorage: StateStorage = {
  setItem: (name: string, value: string) => {
    appMMKV.set(name, value);
  },
  getItem: (name: string) => {
    const value = appMMKV.getString(name);
    return value ?? null;
  },
  removeItem: (name: string) => {
    appMMKV.remove(name);
  },
};

// Secure Storage
export const secureStorage: StateStorage = {
  getItem: (name: string): Promise<string | null> =>
    SecureStore.getItemAsync(name),
  setItem: (name: string, value: string): Promise<void> =>
    SecureStore.setItemAsync(name, value),
  removeItem: (name: string): Promise<void> =>
    SecureStore.deleteItemAsync(name).catch(() => {}),
};

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
