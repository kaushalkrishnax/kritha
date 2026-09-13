import { create } from 'zustand';
import { ChatInputMode, LiveTalkPhase } from '@/types';

interface ChatInputStore {
  mode: ChatInputMode;
  liveTalkPhase: LiveTalkPhase | null;
  draftText: string;

  setMode: (mode: ChatInputMode) => void;
  setLiveTalkPhase: (phase: LiveTalkPhase | null) => void;
  setDraftText: (draftText: string) => void;
  reset: () => void;
}

export const useChatInputStore = create<ChatInputStore>()((set) => ({
  mode: 'TEXTING',
  liveTalkPhase: null,
  draftText: '',

  setMode: (mode) => set({ mode }),
  setLiveTalkPhase: (liveTalkPhase) => set({ liveTalkPhase }),
  setDraftText: (draftText) => set({ draftText }),
  reset: () => set({ mode: 'TEXTING', liveTalkPhase: null, draftText: '' }),
}));
