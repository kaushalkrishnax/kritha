import { View, Text, StyleSheet } from 'react-native';
import { ChatMessage } from '@/components/chat/types';
import Colors from '@/theme';

export interface PromptMessageProps {
  message: ChatMessage;
  style?: object;
}

export function PromptMessage({ message, style }: PromptMessageProps) {
  return (
    <View style={[styles.messageWrapper, styles.userWrapper, style]}>
      <View style={styles.userBubble}>
        <Text style={styles.userText}>{message.text}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  messageWrapper: {
    width: '100%',
  },
  userWrapper: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  userBubble: {
    backgroundColor: Colors.userBubbleBg,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    borderBottomRightRadius: 4,
    maxWidth: '82%',
  },
  userText: {
    color: Colors.textOnAccent,
    fontSize: 14.5,
    lineHeight: 21,
  },
});
