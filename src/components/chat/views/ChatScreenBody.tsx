import { StyleSheet, View } from 'react-native';
import { ChatMessages } from '@/components/chat/ui';
import { Colors } from '@/theme';

export function ChatScreenBody() {
  return (
    <View style={styles.chatArea}>
      <ChatMessages />
    </View>
  );
}

const styles = StyleSheet.create({
  chatArea: { flex: 1, backgroundColor: Colors.bgDeepest },
});
