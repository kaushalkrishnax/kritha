import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { STORAGE_KEYS } from '@/constants';
import { secureStorage } from '@/services';

interface VoiceStore {
  isTtsSpeaking: boolean;
  isTtsPaused: boolean;
  currentTtsMsgId: string | null;
  isTtsDownloaded: boolean;
  isSttDownloaded: boolean;
  voiceModelProgress: { modelType: string; progress: number } | null;
  isVoiceModalOpen: boolean;
  selectedSttModelId: string | null;
  selectedTtsModelId: string | null;

  setTtsState: (
    speaking: boolean,
    paused: boolean,
    msgId?: string | null,
  ) => void;
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
      isTtsSpeaking: false,
      isTtsPaused: false,
      currentTtsMsgId: null,
      isTtsDownloaded: false,
      isSttDownloaded: false,
      voiceModelProgress: null,
      isVoiceModalOpen: false,
      selectedSttModelId: null,
      selectedTtsModelId: null,

      setTtsState: (speaking, paused, msgId = null) =>
        set({
          isTtsSpeaking: speaking,
          isTtsPaused: paused,
          currentTtsMsgId: speaking || paused ? msgId : null,
        }),
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
        set({ isTtsSpeaking: false, isTtsPaused: false, currentTtsMsgId: null }),
    }),
    {
      name: STORAGE_KEYS.assistantSessionStore,
      storage: createJSONStorage(() => secureStorage),
      partialize: (state) => ({
        selectedSttModelId: state.selectedSttModelId,
        selectedTtsModelId: state.selectedTtsModelId,
      }),
    },
  ),
);
