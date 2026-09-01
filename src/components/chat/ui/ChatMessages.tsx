import React, { useCallback, useEffect, useRef } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { Brain } from 'lucide-react-native';
import { ResponseMessage } from './ResponseMessage';
import Colors from '@/theme';
import { useAssistantStore } from '@/store/assistantStore';
import { useAssistantActions } from '@/hooks/use-assistant-interaction';

export function ChatMessages() {
  const messages = useAssistantStore((s) => s.messages);
  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const error = useAssistantStore((s) => s.error);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMsgId);
  const isTtsSpeaking = useAssistantStore((s) => s.isTtsSpeaking);
  const isTtsPaused = useAssistantStore((s) => s.isTtsPaused);

  const { handleSpeakerPress } = useAssistantActions();
  const scrollViewRef = useRef<ScrollView>(null);

  const isSending =
    canonicalState === 'THINKING' || canonicalState === 'GENERATING';
  const isThinking = canonicalState === 'THINKING';

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
          return (
            <View style={[styles.messageWrapper, styles.userWrapper]} key={msg.id}>
              <View style={styles.userBubble}>
                <Text style={styles.userText}>{msg.text}</Text>
              </View>
            </View>
          );
        }

        return (
          <ResponseMessage
            key={msg.id}
            message={msg}
            isStreaming={isStreamingThisMessage}
            showActions={showActions}
            isTtsSpeaking={isTtsSpeaking && (!currentTtsMsgId || currentTtsMsgId === msg.id)}
            isTtsPaused={isTtsPaused && (!currentTtsMsgId || currentTtsMsgId === msg.id)}
            onSpeakerPress={() => handleSpeakerPress(msg.id, msg.text)}
          />
        );
      })}

      {isThinking && (
        <View style={styles.messageWrapper} key="thinking-indicator">
          <View style={styles.thinkingRow}>
            <Brain size={16} color={Colors.accentLightBlue} />
            <Text style={styles.thinkingText}>Thinking…</Text>
          </View>
        </View>
      )}

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
  thinkingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 6,
    paddingHorizontal: 4,
  },
  thinkingText: {
    fontSize: 13,
    fontWeight: '600',
    color: Colors.accentLightBlue,
    fontStyle: 'italic',
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
