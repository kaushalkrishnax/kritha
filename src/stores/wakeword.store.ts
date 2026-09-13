import { create } from 'zustand';

export type WakewordStoreState = {
  isEnabled: boolean;
  setIsEnabled: (enabled: boolean) => void;
};

export const useWakewordStore = create<WakewordStoreState>()((set) => ({
  isEnabled: false, // HYDRATED in AppBootstrap
  setIsEnabled: (isEnabled) => set({ isEnabled }),
}));
