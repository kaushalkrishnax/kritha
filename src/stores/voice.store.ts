import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { STORAGE_KEYS } from '@/constants';
import { secureStorage } from '@/utils';

interface VoiceStore {
  isTtsDownloaded: boolean;
  isSttDownloaded: boolean;
  voiceModelProgress: { modelType: string; progress: number } | null;
  isVoiceModalOpen: boolean;
  selectedSttModelId: string | null;
  selectedTtsModelId: string | null;

  setTtsDownloaded: (downloaded: boolean) => void;
  setSttDownloaded: (downloaded: boolean) => void;
  setVoiceModelProgress: (
    progress: { modelType: string; progress: number } | null,
  ) => void;
  setVoiceModalOpen: (open: boolean) => void;
  setSelectedSttModelId: (id: string | null) => void;
  setSelectedTtsModelId: (id: string | null) => void;
  reset: () => void;
}

export const useVoiceStore = create<VoiceStore>()(
  persist(
    (set) => ({
      isTtsDownloaded: false,
      isSttDownloaded: false,
      voiceModelProgress: null,
      isVoiceModalOpen: false,
      selectedSttModelId: 'nemotron-multilingual-int8',
      selectedTtsModelId: 'qwen3-tts',

      setTtsDownloaded: (downloaded) => set({ isTtsDownloaded: downloaded }),
      setSttDownloaded: (downloaded) => set({ isSttDownloaded: downloaded }),
      setVoiceModelProgress: (progress) =>
        set({ voiceModelProgress: progress }),
      setVoiceModalOpen: (isVoiceModalOpen) => set({ isVoiceModalOpen }),
      setSelectedSttModelId: (selectedSttModelId) =>
        set({ selectedSttModelId }),
      setSelectedTtsModelId: (selectedTtsModelId) =>
        set({ selectedTtsModelId }),
      reset: () =>
        set({
          isTtsDownloaded: false,
          isSttDownloaded: false,
          voiceModelProgress: null,
          isVoiceModalOpen: false,
        }),
    }),
    {
      name: STORAGE_KEYS.voiceStore,
      storage: createJSONStorage(() => secureStorage),
      partialize: (state) => ({
        selectedSttModelId: state.selectedSttModelId,
        selectedTtsModelId: state.selectedTtsModelId,
      }),
    },
  ),
);
