import { ChatMessage } from '@/components/chat/types';
import Colors from '@/theme';
import * as Clipboard from 'expo-clipboard';
import { Brain, Check, ChevronDown, ChevronUp, Copy, Pause, Share2, ThumbsDown, ThumbsUp, Volume2 } from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ScrollView, Share, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { MarkdownRenderer } from './MarkdownRenderer';

export interface ChatMessagesProps {
  messages?: ChatMessage[];
  isSending?: boolean;
  error?: string | null;
  ttsMsgId?: string | null;
  isTtsSpeaking?: boolean;
  isTtsPaused?: boolean;
  onSpeakerPress?: (msgId: string) => void;
}

function parseThinkingMessage(fullText: string): {
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

function ThinkingBlock({
  thinking,
  isThinkingActive,
}: {
  thinking: string;
  isThinkingActive: boolean;
}) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <View style={styles.thinkingContainer}>
      <TouchableOpacity
        style={styles.thinkingHeader}
        activeOpacity={0.7}
        onPress={() => setCollapsed((prev) => !prev)}
      >
        <View style={styles.thinkingHeaderLeft}>
          <Brain size={14} color={Colors.accentLightBlue} />
          <Text style={styles.thinkingHeaderText}>
            {isThinkingActive ? 'Thinking…' : 'Thought process'}
          </Text>
        </View>
        {collapsed ? (
          <ChevronDown size={14} color={Colors.textMuted} />
        ) : (
          <ChevronUp size={14} color={Colors.textMuted} />
        )}
      </TouchableOpacity>

      {!collapsed && (
        <View style={styles.thinkingBody}>
          <Text style={styles.thinkingText}>{thinking}</Text>
        </View>
      )}
    </View>
  );
}

function ResponseActions({
  msgId,
  textToCopy,
  isTtsSpeaking,
  isTtsPaused,
  onSpeakerPress,
}: {
  msgId: string;
  textToCopy: string;
  isTtsSpeaking: boolean;
  isTtsPaused: boolean;
  onSpeakerPress: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const [feedback, setFeedback] = useState<'like' | 'dislike' | null>(null);

  const handleCopy = async () => {
    if (!textToCopy) return;
    await Clipboard.setStringAsync(textToCopy);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShare = async () => {
    if (!textToCopy) return;
    try {
      await Share.share({ message: textToCopy });
    } catch (e) {
      console.error('Share error:', e);
    }
  };

  const toggleLike = () => {
    setFeedback((prev) => (prev === 'like' ? null : 'like'));
  };

  const toggleDislike = () => {
    setFeedback((prev) => (prev === 'dislike' ? null : 'dislike'));
  };

  return (
    <View style={styles.actionsRow}>
      <View style={styles.actionsLeft}>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={toggleLike}
        >
          <ThumbsUp
            size={18}
            color={feedback === 'like' ? Colors.accentSky : Colors.iconMuted}
            fill={feedback === 'like' ? 'rgba(56, 189, 248, 0.2)' : 'transparent'}
          />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={toggleDislike}
        >
          <ThumbsDown
            size={18}
            color={feedback === 'dislike' ? Colors.error : Colors.iconMuted}
            fill={feedback === 'dislike' ? 'rgba(248, 113, 113, 0.2)' : 'transparent'}
          />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={handleCopy}
        >
          {copied ? (
            <Check size={18} color={Colors.success} />
          ) : (
            <Copy size={18} color={Colors.iconMuted} />
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={handleShare}
        >
          <Share2 size={18} color={Colors.iconMuted} />
        </TouchableOpacity>
      </View>

      <TouchableOpacity
        style={[styles.actionIconBtn, isTtsSpeaking && styles.speakerActive]}
        activeOpacity={0.8}
        onPress={onSpeakerPress}
      >
        {isTtsSpeaking ? (
          <Pause fill={Colors.iconMuted} size={20} color="transparent" />
        ) : (
          <Volume2 size={20} color={Colors.iconMuted} />
        )}
      </TouchableOpacity>
    </View>
  );
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

        const { thinking, answer, isThinkingActive } = isUser
          ? { thinking: null, answer: msg.text, isThinkingActive: false }
          : parseThinkingMessage(msg.text);

        return (
          <View
            key={msg.id}
            style={[
              styles.messageWrapper,
              isUser ? styles.userWrapper : styles.assistantWrapper,
            ]}
          >
            <View
              style={isUser ? styles.userBubble : styles.assistantContainer}
            >
              {!isUser && thinking ? (
                <ThinkingBlock
                  thinking={thinking}
                  isThinkingActive={isThinkingActive}
                />
              ) : null}

              {answer ? (
                isUser ? (
                  <Text style={[styles.messageText, styles.userText]}>
                    {answer}
                  </Text>
                ) : (
                  <MarkdownRenderer content={answer} />
                )
              ) : null}

              {!isUser && !answer && !thinking && isStreamingThisMessage ? (
                <View style={styles.thinkingDotsRow}>
                  <Brain size={16} color={Colors.accentLightBlue} />
                  <Text style={styles.thinkingDotsText}>Thinking…</Text>
                </View>
              ) : null}

              {!isUser && showActions && (
                <ResponseActions
                  msgId={msg.id}
                  textToCopy={answer || msg.text}
                  isTtsSpeaking={isTtsSpeaking && (!ttsMsgId || ttsMsgId === msg.id)}
                  isTtsPaused={isTtsPaused && (!ttsMsgId || ttsMsgId === msg.id)}
                  onSpeakerPress={() => onSpeakerPress?.(msg.id)}
                />
              )}
            </View>
          </View>
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
  messageWrapper: { width: '100%' },
  userWrapper: { flexDirection: 'row', justifyContent: 'flex-end' },
  assistantWrapper: { flexDirection: 'row', justifyContent: 'flex-start' },
  userBubble: {
    backgroundColor: Colors.userBubbleBg,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    borderBottomRightRadius: 4,
    maxWidth: '82%',
  },
  assistantContainer: {
    width: '100%',
    paddingVertical: 2,
    paddingHorizontal: 2,
  },
  messageText: { fontSize: 15, lineHeight: 22 },
  userText: { color: Colors.textOnAccent, fontSize: 14.5, lineHeight: 21 },
  thinkingContainer: {
    marginBottom: 10,
    backgroundColor: Colors.thinkingBg,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.assistantBubbleBorder,
    overflow: 'hidden',
  },
  thinkingHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 10,
    paddingVertical: 7,
    backgroundColor: 'rgba(26,115,232,0.08)',
  },
  thinkingHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  thinkingHeaderText: { fontSize: 12, fontWeight: '600', color: '#8AB4F8' },
  thinkingBody: {
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(26,115,232,0.15)',
    borderLeftWidth: 3,
    borderLeftColor: Colors.thinkingBorder,
  },
  thinkingText: {
    fontSize: 12.5,
    lineHeight: 18,
    color: 'rgba(255,255,255,0.55)',
    fontStyle: 'italic',
  },
  thinkingDotsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 4,
  },
  thinkingDotsText: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.55)',
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
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 10,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: Colors.borderFaint,
  },
  actionsLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  actionIconBtn: {
    padding: 10,
    borderRadius: 20,
  },
  speakerActive: {
    backgroundColor: Colors.ttsActiveBg,
  },
});
