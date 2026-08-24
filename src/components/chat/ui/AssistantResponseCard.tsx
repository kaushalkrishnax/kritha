import React, { useRef } from 'react';
import { Animated, ScrollView, StyleSheet, Text, View } from 'react-native';
import { ChatMessage } from '@/components/chat/types';
import { ResponseMessage } from './ResponseMessage';
import { ResponseActions } from './ResponseActions';
import Colors from '@/theme';

export interface AssistantResponseCardProps {
  responseVisible: boolean;
  responseOpacity: Animated.Value;
  responseTranslate: Animated.Value;
  latestAssistant: ChatMessage | undefined;
  error: string | null;
  isTtsSpeaking: boolean;
  isTtsPaused: boolean;
  ttsMsgId: string | null;
  onSpeakerPress: (msgId: string) => void;
  onExpandPress?: () => void;
  hideActions?: boolean;
}

export function AssistantResponseCard({
  responseVisible,
  responseOpacity,
  responseTranslate,
  latestAssistant,
  error,
  isTtsSpeaking,
  isTtsPaused,
  ttsMsgId,
  onSpeakerPress,
  onExpandPress,
  hideActions = false,
}: AssistantResponseCardProps) {
  const responseScrollRef = useRef<ScrollView>(null);

  if (!responseVisible) return null;

  return (
    <Animated.View
      style={[
        styles.responseCard,
        {
          opacity: responseOpacity,
          transform: [{ translateY: responseTranslate }],
        },
      ]}
    >
      <View style={styles.responseHandle} />

      <ScrollView
        ref={responseScrollRef}
        style={styles.responseScroll}
        contentContainerStyle={styles.responseContent}
        showsVerticalScrollIndicator={false}
        bounces={false}
        onContentSizeChange={() =>
          responseScrollRef.current?.scrollToEnd({ animated: true })
        }
      >
        {latestAssistant ? (
          <ResponseMessage
            message={latestAssistant}
            showActions={!hideActions}
            isTtsSpeaking={
              isTtsSpeaking && (!ttsMsgId || ttsMsgId === latestAssistant.id)
            }
            isTtsPaused={
              isTtsPaused && (!ttsMsgId || ttsMsgId === latestAssistant.id)
            }
            onSpeakerPress={onSpeakerPress}
            onExpandPress={onExpandPress}
            showExpandButton={Boolean(onExpandPress)}
          />
        ) : error ? (
          <View style={styles.errorWrapper}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : (
          <View>
            <Text style={styles.responseText}>
              Just here and ready to help out. What are you working on today?
            </Text>
            {!hideActions && (
              <ResponseActions
                textToCopy="Just here and ready to help out. What are you working on today?"
                onExpandPress={onExpandPress}
                showExpandButton={Boolean(onExpandPress)}
              />
            )}
          </View>
        )}
      </ScrollView>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  responseCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: 28,
    paddingHorizontal: 18,
    paddingTop: 12,
    paddingBottom: 14,
    marginBottom: 10,
    maxHeight: 280,
    width: '100%',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.35,
    shadowRadius: 16,
    elevation: 10,
  },
  responseHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.borderSubtle,
    alignSelf: 'center',
    marginBottom: 10,
  },
  responseScroll: {
    minHeight: 44,
    maxHeight: 210,
  },
  responseContent: {
    paddingBottom: 4,
  },
  responseText: {
    color: Colors.textSecondary,
    fontSize: 15,
    lineHeight: 22,
  },
  errorWrapper: {
    paddingVertical: 8,
  },
  errorText: {
    color: Colors.error,
    fontSize: 14,
  },
});
