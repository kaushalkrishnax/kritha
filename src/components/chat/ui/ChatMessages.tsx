import React, { useCallback, useEffect, useRef } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { ChatMessage } from '@/components/chat/types';
import { PromptMessage } from './PromptMessage';
import { ResponseMessage } from './ResponseMessage';
import Colors from '@/theme';

export interface ChatMessagesProps {
  messages?: ChatMessage[];
  isSending?: boolean;
  error?: string | null;
  ttsMsgId?: string | null;
  isTtsSpeaking?: boolean;
  isTtsPaused?: boolean;
  onSpeakerPress?: (msgId: string) => void;
}

export function ChatMessages({
  messages = [],
  isSending = false,
  error = null,
  ttsMsgId = null,
  isTtsSpeaking = false,
  isTtsPaused = false,
  onSpeakerPress,
}: ChatMessagesProps) {
  const scrollViewRef = useRef<ScrollView>(null);

  const scrollToBottom = useCallback(() => {
    requestAnimationFrame(() => {
      scrollViewRef.current?.scrollToEnd({ animated: false });
    });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, isSending, scrollToBottom]);

  const lastAssistantIdx = (() => {
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role === 'assistant') return i;
    }
    return -1;
  })();

  return (
    <ScrollView
      ref={scrollViewRef}
      style={styles.scrollView}
      contentContainerStyle={styles.container}
      onContentSizeChange={scrollToBottom}
    >
      {messages.map((msg, index) => {
        const isUser = msg.role === 'user';
        const isLastMessage = index === messages.length - 1;
        const isStreamingThisMessage = isSending && isLastMessage && !isUser;
        const isLastAssistant = index === lastAssistantIdx;
        const showActions =
          isLastAssistant && !isStreamingThisMessage && msg.text.length > 0;

        if (isUser) {
          return <PromptMessage key={msg.id} message={msg} />;
        }

        return (
          <ResponseMessage
            key={msg.id}
            message={msg}
            isStreaming={isStreamingThisMessage}
            showActions={showActions}
            isTtsSpeaking={isTtsSpeaking && (!ttsMsgId || ttsMsgId === msg.id)}
            isTtsPaused={isTtsPaused && (!ttsMsgId || ttsMsgId === msg.id)}
            onSpeakerPress={onSpeakerPress}
          />
        );
      })}

      {error && (
        <View style={styles.errorWrapper}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}
    </ScrollView>
  );
}

export default ChatMessages;

const styles = StyleSheet.create({
  scrollView: { flex: 1 },
  container: {
    flexGrow: 1,
    paddingTop: 16,
    paddingBottom: 24,
    paddingHorizontal: 16,
    gap: 16,
  },
  errorWrapper: {
    alignSelf: 'center',
    backgroundColor: Colors.errorBubbleBg,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    marginTop: 8,
  },
  errorText: { color: Colors.error, fontSize: 13 },
});
