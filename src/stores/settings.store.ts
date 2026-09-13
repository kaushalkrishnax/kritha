import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { STORAGE_KEYS } from '@/constants/storageKeys';
import { mmkvStorage } from '@/utils';

export type DeviceType = 'cpu' | 'gpu';

export type SettingsStoreState = {
  userName: string;
  customInstructions: string;
  deviceType: DeviceType;
  setUserName: (name: string) => void;
  setCustomInstructions: (instructions: string) => void;
  setDeviceType: (device: DeviceType) => void;
};

export const useSettingsStore = create<SettingsStoreState>()(
  persist(
    (set) => ({
      userName: 'Your Name',
      customInstructions: '',
      deviceType: 'cpu',
      setUserName: (userName) => set({ userName }),
      setCustomInstructions: (customInstructions) =>
        set({ customInstructions }),
      setDeviceType: (deviceType) => set({ deviceType }),
    }),
    {
      name: STORAGE_KEYS.settingsStore,
      storage: createJSONStorage(() => mmkvStorage),
    },
  ),
);
