import { ChatMessage } from '@/components/chat/types';
import { MarkdownRenderer } from '@/components/chat/ui';
import Colors from '@/theme';
import * as Clipboard from 'expo-clipboard';
import {
  Check,
  Copy,
  Maximize2,
  Pause,
  Share2,
  ThumbsDown,
  ThumbsUp,
  Volume2,
} from 'lucide-react-native';
import { useRef, useState } from 'react';
import {
  Animated,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

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
  const [copied, setCopied] = useState(false);
  const [feedback, setFeedback] = useState<'like' | 'dislike' | null>(null);
  const responseScrollRef = useRef<ScrollView>(null);

  if (!responseVisible) return null;

  const handleCopyText = async (text: string) => {
    if (!text) return;
    await Clipboard.setStringAsync(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShareText = async (text: string) => {
    if (!text) return;
    try {
      await Share.share({ message: text });
    } catch (e) {
      console.error('Share error:', e);
    }
  };

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
          <MarkdownRenderer content={latestAssistant.text} />
        ) : error ? (
          <Text style={[styles.responseText, styles.errorText]}>{error}</Text>
        ) : (
          <Text style={styles.responseText}>
            Just here and ready to help out. What are you working on today?
          </Text>
        )}

        {!hideActions && (
          <View style={styles.responseActions}>
            <TouchableOpacity
              style={styles.responseIcon}
              activeOpacity={0.7}
              onPress={() => setFeedback((p) => (p === 'like' ? null : 'like'))}
            >
              <ThumbsUp
                size={18}
                color={feedback === 'like' ? '#38BDF8' : '#9AA0A6'}
                fill={feedback === 'like' ? 'rgba(56, 189, 248, 0.2)' : 'transparent'}
              />
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.responseIcon}
              activeOpacity={0.7}
              onPress={() => setFeedback((p) => (p === 'dislike' ? null : 'dislike'))}
            >
              <ThumbsDown
                size={18}
                color={feedback === 'dislike' ? '#F87171' : '#9AA0A6'}
                fill={feedback === 'dislike' ? 'rgba(248, 113, 113, 0.2)' : 'transparent'}
              />
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.responseIcon}
              activeOpacity={0.7}
              onPress={() =>
                latestAssistant && handleCopyText(latestAssistant.text)
              }
            >
              {copied ? (
                <Check size={18} color="#10B981" />
              ) : (
                <Copy size={18} color="#9AA0A6" />
              )}
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.responseIcon}
              activeOpacity={0.7}
              onPress={() =>
                latestAssistant && handleShareText(latestAssistant.text)
              }
            >
              <Share2 size={18} color="#9AA0A6" />
            </TouchableOpacity>

            <View style={styles.responseSpacer} />

            {latestAssistant && (
              <>
                {onExpandPress && (
                  <TouchableOpacity
                    activeOpacity={0.8}
                    style={styles.responseIcon}
                    onPress={onExpandPress}
                  >
                    <Maximize2 size={18} color="#9AA0A6" />
                  </TouchableOpacity>
                )}

                <TouchableOpacity
                  activeOpacity={0.8}
                  style={[
                    styles.responseIcon,
                    isTtsSpeaking && styles.speakerActive,
                  ]}
                  onPress={() => onSpeakerPress(latestAssistant.id)}
                >
                  {isTtsSpeaking && (!ttsMsgId || ttsMsgId === latestAssistant.id) ? (
                    <Pause size={20} color={Colors.iconMuted} fill="transparent" />
                  ) : (
                    <Volume2
                      size={20}
                      color={
                        isTtsPaused && (!ttsMsgId || ttsMsgId === latestAssistant.id)
                          ? Colors.iconSlate
                          : '#9AA0A6'
                      }
                    />
                  )}
                </TouchableOpacity>
              </>
            )}
          </View>
        )}
      </ScrollView>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  responseCard: {
    backgroundColor: '#1E1F22',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    borderBottomLeftRadius: 28,
    borderBottomRightRadius: 28,
    paddingHorizontal: 18,
    paddingTop: 12,
    paddingBottom: 14,
    marginBottom: 10,
    maxHeight: 280,
    width: '100%',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.12)',
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
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    alignSelf: 'center',
    marginBottom: 10,
  },
  responseScroll: {
    minHeight: 44,
    maxHeight: 176,
  },
  responseContent: {
    paddingBottom: 4,
  },
  responseText: {
    color: '#E8EAED',
    fontSize: 15,
    lineHeight: 22,
  },
  errorText: {
    color: '#F87171',
  },
  responseActions: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.08)',
  },
  responseIcon: {
    padding: 6,
    borderRadius: 16,
    marginRight: 4,
  },
  responseSpacer: {
    flex: 1,
  },
  speakerActive: {
    backgroundColor: 'rgba(138,180,248,0.15)',
  },
});
