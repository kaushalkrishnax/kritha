import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { STORAGE_KEYS } from '@/constants';
import { secureStorage } from '@/utils';

export type LiveTalkTtsMode = 'disabled' | 'after_generation' | 'stream';

interface VoiceStore {
  isTtsDownloaded: boolean;
  isSttDownloaded: boolean;
  voiceModelProgress: { modelType: string; progress: number } | null;
  isVoiceModalOpen: boolean;
  selectedSttModelId: string | null;
  selectedTtsModelId: string | null;
  liveTalkTtsMode: LiveTalkTtsMode;

  setTtsDownloaded: (downloaded: boolean) => void;
  setSttDownloaded: (downloaded: boolean) => void;
  setVoiceModelProgress: (
    progress: { modelType: string; progress: number } | null,
  ) => void;
  setVoiceModalOpen: (open: boolean) => void;
  setSelectedSttModelId: (id: string | null) => void;
  setSelectedTtsModelId: (id: string | null) => void;
  setLiveTalkTtsMode: (mode: LiveTalkTtsMode) => void;
  reset: () => void;
}

export const useVoiceStore = create<VoiceStore>()(
  persist(
    (set) => ({
      isTtsDownloaded: false,
      isSttDownloaded: false,
      voiceModelProgress: null,
      isVoiceModalOpen: false,
      selectedSttModelId: 'moonshine-tiny-onnx',
      selectedTtsModelId: 'qwen3-tts',
      liveTalkTtsMode: 'stream',

      setTtsDownloaded: (downloaded) => set({ isTtsDownloaded: downloaded }),
      setSttDownloaded: (downloaded) => set({ isSttDownloaded: downloaded }),
      setVoiceModelProgress: (progress) =>
        set({ voiceModelProgress: progress }),
      setVoiceModalOpen: (isVoiceModalOpen) => set({ isVoiceModalOpen }),
      setSelectedSttModelId: (selectedSttModelId) =>
        set({ selectedSttModelId }),
      setSelectedTtsModelId: (selectedTtsModelId) =>
        set({ selectedTtsModelId }),
      setLiveTalkTtsMode: (liveTalkTtsMode) => set({ liveTalkTtsMode }),
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
        liveTalkTtsMode: state.liveTalkTtsMode,
      }),
    },
  ),
);
