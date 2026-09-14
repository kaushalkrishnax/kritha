import { useChatStore } from '@/stores';

export function useChatInputHeight() {
  const chatInputHeight = useChatStore((s) => s.chatInputHeight);
  const setChatInputHeight = useChatStore((s) => s.setChatInputHeight);

  return {
    chatInputHeight,
    setChatInputHeight,
  };
}
