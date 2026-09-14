import { Brain } from 'lucide-react-native';
import { StyleSheet, Text, View } from 'react-native';
import { Colors, IconSizes, Typography } from '@/theme';
import { ChatMessage } from '@/types/chat';
import { MarkdownRenderer } from './MarkdownRenderer';
import { ResponseActions } from './ResponseActions';
import { ThinkingBlock } from './ThinkingBlock';

export interface ResponseMessageProps {
  message: ChatMessage;
  isStreaming?: boolean;
  showActions?: boolean;
  isTtsSpeaking?: boolean;
  isTtsPaused?: boolean;
  onSpeakerPress?: (msgId: string) => void;
  style?: object;
}

export function parseThinkingMessage(fullText: string): {
  thinking: string | null;
  answer: string;
  isThinkingActive: boolean;
} {
  const openIdx = fullText.indexOf('<think>');
  if (openIdx === -1) {
    return { thinking: null, answer: fullText, isThinkingActive: false };
  }

  const closeIdx = fullText.indexOf('</think>');
  if (closeIdx === -1) {
    const thinking = fullText.slice(openIdx + 7).trim();
    return { thinking, answer: '', isThinkingActive: true };
  }

  const thinking = fullText.slice(openIdx + 7, closeIdx).trim();
  const answer = fullText.slice(closeIdx + 8).trim();
  return { thinking, answer, isThinkingActive: false };
}

export function ResponseMessage({
  message,
  isStreaming = false,
  showActions = false,
  isTtsSpeaking = false,
  isTtsPaused = false,
  onSpeakerPress,
  style,
}: ResponseMessageProps) {
  const { thinking, answer, isThinkingActive } = parseThinkingMessage(
    message.text,
  );

  return (
    <View style={[styles.messageWrapper, styles.assistantWrapper, style]}>
      <View style={styles.assistantContainer}>
        {thinking ? (
          <ThinkingBlock
            thinking={thinking}
            isThinkingActive={isThinkingActive}
          />
        ) : null}

        {answer ? (
          <MarkdownRenderer content={answer} />
        ) : null}

        {!answer && !thinking && isStreaming ? (
          <View style={styles.thinkingDotsRow}>
            <Brain size={IconSizes.sm} color={Colors.accentLightBlue} />
            <Text style={styles.thinkingDotsText}>Thinking…</Text>
          </View>
        ) : null}

        {showActions && (
          <ResponseActions
            msgId={message.id}
            textToCopy={answer || message.text}
            isTtsSpeaking={isTtsSpeaking}
            isTtsPaused={isTtsPaused}
            onSpeakerPress={
              onSpeakerPress ? () => onSpeakerPress(message.id) : undefined
            }
          />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  messageWrapper: {
    width: '100%',
  },
  assistantWrapper: {
    flexDirection: 'row',
    justifyContent: 'flex-start',
  },
  assistantContainer: {
    width: '100%',
    paddingVertical: 12,
    paddingHorizontal: 2,
  },
  thinkingDotsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 4,
  },
  thinkingDotsText: {
    fontSize: Typography.sizeSm,
    color: Colors.textDimmed,
    fontStyle: 'italic',
  },
});
