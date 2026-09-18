import { StatusBar } from 'expo-status-bar';
import { useCallback, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { useChatSession } from '@/hooks';
import { settingsService } from '@/services';
import { Colors } from '@/theme';
import { ModelRecord } from '@/types';

import { ChatComposer } from './ChatComposer';
import { ChatHeader } from './ChatHeader';
import { ChatMessages } from './ChatMessages';
import { ChatModals } from './ChatModals';

export default function ChatScreen() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isModelDropdownOpen, setModelDropdownOpen] = useState(false);
  const [downloadModalModel, setDownloadModalModel] =
    useState<ModelRecord | null>(null);
  const [permissionsModalVisible, setPermissionsModalVisible] = useState(
    () => !settingsService.hasSeenPermissionsOnboarding(),
  );

  const { beginNewChat } = useChatSession();

  const handleNewChat = useCallback(async () => {
    try {
      setSidebarOpen(false);
      await beginNewChat();
    } catch (e) {
      console.warn('Failed to create new chat session', e);
    }
  }, [beginNewChat]);

  return (
    <View style={styles.container}>
      <StatusBar style="light" />

      <View style={styles.mainLayout}>
        <View style={styles.chatArea}>
          <ChatMessages />
        </View>
      </View>

      <View style={styles.headerOverlay}>
        <ChatHeader
          onMenu={() => setSidebarOpen(true)}
          onNewSession={handleNewChat}
          sidebarOpen={sidebarOpen}
          setSidebarOpen={setSidebarOpen}
        />
      </View>
      <ChatComposer />

      <ChatModals
        sidebarOpen={sidebarOpen}
        setSidebarOpen={setSidebarOpen}
        isModelDropdownOpen={isModelDropdownOpen}
        setModelDropdownOpen={setModelDropdownOpen}
        downloadModalModel={downloadModalModel}
        setDownloadModalModel={setDownloadModalModel}
        permissionsModalVisible={permissionsModalVisible}
        setPermissionsModalVisible={setPermissionsModalVisible}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: 'transparent' },
  mainLayout: { flex: 1, backgroundColor: Colors.bgDeepest },
  chatArea: { flex: 1, backgroundColor: Colors.bgDeepest },
  headerOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 10,
  },
});
