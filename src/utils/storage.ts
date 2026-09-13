import * as SecureStore from 'expo-secure-store';
import { createMMKV } from 'react-native-mmkv';
import { StateStorage } from 'zustand/middleware';

let appMMKV: ReturnType<typeof createMMKV> | null = null;

function getMMKV() {
  if (!appMMKV) {
    appMMKV = createMMKV({ id: 'kritha-storage' });
  }

  return appMMKV;
}

export const mmkvStorage: StateStorage = {
  setItem: (name, value) => {
    getMMKV().set(name, value);
  },

  getItem: (name) => {
    return getMMKV().getString(name) ?? null;
  },

  removeItem: (name) => {
    getMMKV().remove(name);
  },
};

export const secureStorage: StateStorage = {
  getItem: (name: string): Promise<string | null> =>
    SecureStore.getItemAsync(name),
  setItem: (name: string, value: string): Promise<void> =>
    SecureStore.setItemAsync(name, value),
  removeItem: (name: string): Promise<void> =>
    SecureStore.deleteItemAsync(name).catch(() => {}),
};