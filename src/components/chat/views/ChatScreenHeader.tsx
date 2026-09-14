import { useCallback, useMemo } from 'react';
import { StyleSheet, View } from 'react-native';
import { ChatHeader } from '@/components/chat/ui/ChatHeader';
import { useChatSession } from '@/hooks';
import { useModelStore } from '@/stores';

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

  const handleNewChat = useCallback(async () => {
    try {
      await beginNewChat();
      setSidebarOpen(false);
    } catch (e) {
      console.warn('Failed to create new chat session', e);
    }
  }, [setSidebarOpen, beginNewChat]);

  return (
    <View style={styles.container}>
      <ChatHeader
        modelName={selectedModel?.name || ''}
        onMenu={() => setSidebarOpen(true)}
        onNewSession={handleNewChat}
        onModelSelectClick={onModelSelectClick}
        sidebarOpen={sidebarOpen}
        setSidebarOpen={setSidebarOpen}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 10,
  },
});
