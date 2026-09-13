import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { MODELS, STORAGE_KEYS } from '@/constants';
import { mmkvStorage } from '@/services';
import { DownloadState, ModelRecord } from '@/types';

export type ModelStoreState = {
  models: ModelRecord[];
  selectedModelId: string;
  downloadState: DownloadState;

  setModels: (models: ModelRecord[]) => void;
  setSelectedModelId: (id: string) => void;
  setDownloadState: (patch: Partial<DownloadState>) => void;
  markModelDownloaded: (id: string) => void;
};

export const useModelStore = create<ModelStoreState>()(
  persist(
    (set) => ({
      models: MODELS,
      selectedModelId: 'gemma-4-E2B-it',
      downloadState: {
        modelId: '',
        progress: 0,
        downloadedMb: 0,
        totalMb: 0,
        speed: 0,
        active: false,
        paused: false,
      },

      setModels: (models) => set({ models }),
      setSelectedModelId: (selectedModelId) => set({ selectedModelId }),
      setDownloadState: (patch) =>
        set((state) => ({
          downloadState: { ...state.downloadState, ...patch },
        })),
      markModelDownloaded: (modelId) =>
        set((state) => ({
          models: state.models.map((m) =>
            m.id === modelId ? { ...m, downloaded: true } : m,
          ),
          selectedModelId: modelId,
        })),
    }),
    {
      name: STORAGE_KEYS.modelStore,
      storage: createJSONStorage(() => mmkvStorage),
      partialize: (state) => ({
        selectedModelId: state.selectedModelId,
      }),
    },
  ),
);
