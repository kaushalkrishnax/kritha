import { buildConversationContext } from '@/services';
import { useChatStore, useSettingsStore } from '@/store';

export function useConversationContext() {
  return function getConversationContext() {
    const settingsStoreState = useSettingsStore.getState();
    const userName = settingsStoreState.userName || '';
    const customInstructions = settingsStoreState.customInstructions || '';

    return buildConversationContext({
      messages: useChatStore.getState().messages,
      userName,
      customInstructions,
    });
  };
}
