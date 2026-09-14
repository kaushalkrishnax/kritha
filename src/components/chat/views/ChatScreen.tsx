import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { settingsService } from '@/services';
import { Colors } from '@/theme';
import { ModelRecord } from '@/types';
import { ChatScreenBody } from './ChatScreenBody';
import { ChatScreenComposer } from './ChatScreenComposer';
import { ChatScreenHeader } from './ChatScreenHeader';
import { ChatScreenModals } from './ChatScreenModals';

export default function ChatScreen() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isModelDropdownOpen, setModelDropdownOpen] = useState(false);
  const [downloadModalModel, setDownloadModalModel] =
    useState<ModelRecord | null>(null);
  const [permissionsModalVisible, setPermissionsModalVisible] = useState(
    () => !settingsService.hasSeenPermissionsOnboarding(),
  );

  return (
    <View style={styles.container}>
      <StatusBar style="light" />

      <View style={styles.mainLayout}>
        <ChatScreenBody />
      </View>

      <ChatScreenHeader
        sidebarOpen={sidebarOpen}
        setSidebarOpen={setSidebarOpen}
        onModelSelectClick={() => setModelDropdownOpen((prev) => !prev)}
      />
      <ChatScreenComposer />

      <ChatScreenModals
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
});
