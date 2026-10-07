import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { STORAGE_KEYS } from '@/constants/storageKeys';
import { mmkvStorage } from '@/utils';

export interface UpdateInfo {
  latestVersion: string;
  releaseUrl?: string;
  releaseNotes?: string;
  publishedAt?: string;
  severity?: 'high' | 'low';
}

export interface RuntimeExtensionUpdateInfo {
  count: number;
  runtimeUpdates: number;
  extensionUpdates: number;
}

export type UpdateState = {
  appUpdate: {
    available: boolean;
    info: UpdateInfo | null;
    seenVersion: string | null;
    checkInProgress: boolean;
    lastChecked: number | null;
  };
  runtimeExtensionUpdates: {
    available: boolean;
    info: RuntimeExtensionUpdateInfo | null;
  };
  checkForAppUpdate: () => Promise<void>;
  setAppUpdateAvailable: (info: UpdateInfo) => void;
  markAppUpdateSeen: (version: string) => void;
  dismissAppUpdate: () => void;
  setRuntimeExtensionUpdates: (info: RuntimeExtensionUpdateInfo) => void;
  setCheckInProgress: (inProgress: boolean) => void;
};

const initialState = {
  appUpdate: {
    available: false,
    info: null,
    seenVersion: null,
    checkInProgress: false,
    lastChecked: null,
  },
  runtimeExtensionUpdates: {
    available: false,
    info: null,
  },
};

export const useUpdateStore = create<UpdateState>()(
  persist(
    (set, get) => ({
      ...initialState,
      checkForAppUpdate: async () => {
        const { UpdateService } = await import('@/services/update.service');
        await UpdateService.checkAppUpdateFromRegistry();
      },
      setAppUpdateAvailable: (info: UpdateInfo) =>
        set((state) => ({
          appUpdate: {
            ...state.appUpdate,
            available: true,
            info,
            checkInProgress: false,
            lastChecked: Date.now(),
          },
        })),
      markAppUpdateSeen: (version: string) =>
        set((state) => ({
          appUpdate: {
            ...state.appUpdate,
            seenVersion: version,
          },
        })),
      dismissAppUpdate: () =>
        set((state) => ({
          appUpdate: {
            ...state.appUpdate,
            available: false,
            info: null,
          },
        })),
      setRuntimeExtensionUpdates: (info: RuntimeExtensionUpdateInfo) =>
        set((state) => ({
          runtimeExtensionUpdates: {
            available: info.count > 0,
            info,
          },
        })),
      setCheckInProgress: (inProgress: boolean) =>
        set((state) => ({
          appUpdate: {
            ...state.appUpdate,
            checkInProgress: inProgress,
          },
        })),
    }),
    {
      name: STORAGE_KEYS.updateStore,
      storage: createJSONStorage(() => mmkvStorage),
      partialize: (state) => ({
        appUpdate: {
          seenVersion: state.appUpdate.seenVersion,
        },
        runtimeExtensionUpdates: state.runtimeExtensionUpdates,
      }),
    }
  )
);