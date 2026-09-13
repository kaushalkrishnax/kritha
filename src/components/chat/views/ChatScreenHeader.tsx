import React, { useMemo, useCallback } from 'react';
import { ChatHeader } from '@/components/chat/ui/ChatHeader';
import { useChatSession } from '@/hooks';
import { useModelStore } from '@/store';

interface Props {
  sidebarOpen: boolean;
  setSidebarOpen: (o: boolean) => void;
  onModelSelectClick: () => void;
}

export function ChatScreenHeader({
  sidebarOpen,
  setSidebarOpen,
  onModelSelectClick,
}: Props) {
  const models = useModelStore((s) => s.models);
  const selectedModelId = useModelStore((s) => s.selectedModelId);

  const selectedModel = useMemo(
    () => models.find((m) => m.id === selectedModelId) || models[0],
    [models, selectedModelId],
  );

  const { beginNewChat } = useChatSession();

  const handleNewChat = useCallback(() => {
    try {
      beginNewChat();
      setSidebarOpen(false);
    } catch (e) {
      console.warn('Failed to create new chat session', e);
    }
  }, [setSidebarOpen, beginNewChat]);

  return (
    <ChatHeader
      modelName={selectedModel?.name || ''}
      onMenu={() => setSidebarOpen(true)}
      onNewSession={handleNewChat}
      onModelSelectClick={onModelSelectClick}
      sidebarOpen={sidebarOpen}
      setSidebarOpen={setSidebarOpen}
    />
  );
}
