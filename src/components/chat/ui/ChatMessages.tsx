import { ArrowDown, Brain, Copy, Pencil, Share2 } from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
    Dimensions,
    Keyboard,
    Animated as RNAnimated,
    ScrollView,
    Share,
    StyleSheet,
    Text,
    TouchableOpacity,
    View,
} from 'react-native';
import { useReanimatedKeyboardAnimation } from 'react-native-keyboard-controller';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Clipboard from 'expo-clipboard';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';
import Svg, {
    Defs,
    Rect,
    Stop,
    LinearGradient as SvgGradient,
} from 'react-native-svg';
import { ContextMenu } from '@/components/ui/ContextMenu';
import { useChatInputHeight, useSpeaker } from '@/hooks';
import { ChatSessionService } from '@/services';
import {
    useAssistantStore,
    useChatStore,
    useIsLlmGenerating,
    useIsLlmThinking,
    useIsTtsPaused,
    useIsTtsSpeaking,
} from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
import { ChatMessage } from '@/types/chat';
import { formatMessageTime } from '@/utils';
import { ResponseMessage } from './ResponseMessage';

const { width: SCREEN_W } = Dimensions.get('window');
const GRADIENT_TOP_HEIGHT = 100;
const GRADIENT_BOTTOM_HEIGHT = 25;

function MessageSkeleton() {
  return (
    <View style={styles.skeletonContainer}>
      <View style={[styles.skeletonBubble, styles.skeletonUser]} />
      <View
        style={[
          styles.skeletonBubble,
          styles.skeletonAssistant,
          { width: '85%' },
        ]}
      />
      <View
        style={[styles.skeletonBubble, styles.skeletonUser, { width: '60%' }]}
      />
      <View
        style={[
          styles.skeletonBubble,
          styles.skeletonAssistant,
          { width: '90%', height: 80 },
        ]}
      />
    </View>
  );
}

interface UserMessageItemProps {
  msg: ChatMessage;
  onLongPress: (
    anchor: { x: number; y: number; width: number; height: number },
    msg: ChatMessage,
  ) => void;
}

function UserMessageItem({ msg, onLongPress }: UserMessageItemProps) {
  const bubbleRef = useRef<View>(null);

  const handleLongPress = () => {
    bubbleRef.current?.measureInWindow((x, y, width, height) => {
      onLongPress({ x, y, width, height }, msg);
    });
  };

  return (
    <View style={[styles.messageWrapper, styles.userWrapper]}>
      <TouchableOpacity
        activeOpacity={0.8}
        style={styles.userTouchArea}
        onLongPress={handleLongPress}
      >
        <View ref={bubbleRef} collapsable={false} style={styles.userBubble}>
          <Text style={styles.userText}>{msg.text}</Text>
        </View>
      </TouchableOpacity>
    </View>
  );
}

export function ChatMessages() {
  const insets = useSafeAreaInsets();
  const keyboard = useReanimatedKeyboardAnimation();
  const messages = useChatStore((s) => s.messages);
  const isLoadingMessages = useChatStore((s) => s.isLoadingMessages);
  const hasMoreMessages = useChatStore((s) => s.hasMoreMessages);
  const error = useAssistantStore((s) => s.error);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMessageId);
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();
  const setEditingMessageId = useAssistantStore((s) => s.setEditingMessageId);
  const setDraftText = useAssistantStore((s) => s.setDraftText);
  const { chatInputHeight } = useChatInputHeight();

  const isThinking = useIsLlmThinking();
  const isGenerating = useIsLlmGenerating();
  const isSending = isThinking || isGenerating;

  const { handleSpeakerPress } = useSpeaker();

  const scrollViewRef = useRef<ScrollView>(null);
  const [contextMenuState, setContextMenuState] = useState<{
    visible: boolean;
    anchor: { x: number; y: number; width: number; height: number } | null;
    msg: ChatMessage | null;
  }>({ visible: false, anchor: null, msg: null });

  const handleUserLongPress = (
    anchor: { x: number; y: number; width: number; height: number },
    msg: ChatMessage,
  ) => {
    setContextMenuState({
      visible: true,
      anchor,
      msg,
    });
  };

  const onContextSelect = async (id: string) => {
    const msg = contextMenuState.msg;
    setContextMenuState({ visible: false, anchor: null, msg: null });

    if (!msg) return;

    if (id === 'copy') {
      await Clipboard.setStringAsync(msg.text);
    } else if (id === 'edit') {
      setDraftText(msg.text);
      setEditingMessageId(msg.id);
    } else if (id === 'share') {
      try {
        await Share.share({ message: msg.text });
      } catch (e) {
        console.error('Share error:', e);
      }
    }
  };

  const isNearBottomRef = useRef(true);
  const prevMessagesLengthRef = useRef(messages.length);

  const [showScrollDown, setShowScrollDown] = useState(false);
  const [scrollDownAnim] = useState(() => new RNAnimated.Value(0));
  const scrollTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const hideScrollDownButton = useCallback(() => {
    RNAnimated.timing(scrollDownAnim, {
      toValue: 0,
      duration: 180,
      useNativeDriver: true,
    }).start(() => {
      setShowScrollDown(false);
    });
  }, [scrollDownAnim]);

  const showScrollDownButton = useCallback(() => {
    setShowScrollDown(true);
    RNAnimated.timing(scrollDownAnim, {
      toValue: 1,
      duration: 180,
      useNativeDriver: true,
    }).start();

    if (scrollTimeoutRef.current) {
      clearTimeout(scrollTimeoutRef.current);
    }
    scrollTimeoutRef.current = setTimeout(() => {
      hideScrollDownButton();
    }, 3000);
  }, [scrollDownAnim, hideScrollDownButton]);

  const animatedContainerStyle = useAnimatedStyle(() => {
    const keyboardHeight = Math.abs(keyboard.height.value);
    const bottomSpacing =
      keyboardHeight > 0 ? keyboardHeight : Math.max(insets.bottom, 16);

    return {
      marginBottom: bottomSpacing + chatInputHeight,
    };
  }, [insets.bottom, chatInputHeight]);

  const handleScroll = useCallback(
    (event: any) => {
      const { layoutMeasurement, contentOffset, contentSize } =
        event.nativeEvent;

      const distanceFromBottom =
        contentSize.height - (contentOffset.y + layoutMeasurement.height);

      const isNearBottom =
        distanceFromBottom <= 80 ||
        contentSize.height <= layoutMeasurement.height;

      isNearBottomRef.current = isNearBottom;
      if (contentOffset.y < 300) {
        ChatSessionService.loadMoreMessages();
      }

      if (!isNearBottom) {
        showScrollDownButton();
      } else {
        if (scrollTimeoutRef.current) {
          clearTimeout(scrollTimeoutRef.current);
          scrollTimeoutRef.current = null;
        }
        hideScrollDownButton();
      }
    },
    [showScrollDownButton, hideScrollDownButton],
  );

  const scrollToBottom = useCallback(
    (animated: boolean = false, force: boolean = false) => {
      if (!force && !isNearBottomRef.current) return;
      requestAnimationFrame(() => {
        if (force || isNearBottomRef.current) {
          scrollViewRef.current?.scrollToEnd({ animated });
        }
      });
      setTimeout(() => {
        if (force || isNearBottomRef.current) {
          scrollViewRef.current?.scrollToEnd({ animated });
        }
      }, 120);
    },
    [],
  );

  const handleScrollDownPress = useCallback(() => {
    if (scrollTimeoutRef.current) {
      clearTimeout(scrollTimeoutRef.current);
      scrollTimeoutRef.current = null;
    }
    isNearBottomRef.current = true;
    scrollToBottom(true, true);
    hideScrollDownButton();
  }, [scrollToBottom, hideScrollDownButton]);

  useEffect(() => {
    return () => {
      if (scrollTimeoutRef.current) {
        clearTimeout(scrollTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    const isNewUserMessage =
      messages.length > prevMessagesLengthRef.current &&
      messages[messages.length - 1]?.role === 'user';
    prevMessagesLengthRef.current = messages.length;

    if (isNewUserMessage) {
      isNearBottomRef.current = true;
      scrollToBottom(true, true);
    } else if (isNearBottomRef.current) {
      scrollToBottom(false);
    }
  }, [messages, isSending, scrollToBottom]);

  useEffect(() => {
    const showSub = Keyboard.addListener('keyboardDidShow', () => {
      if (isNearBottomRef.current) {
        scrollToBottom(true);
      }
    });
    const hideSub = Keyboard.addListener('keyboardDidHide', () => {
      if (isNearBottomRef.current) {
        scrollToBottom(true);
      }
    });
    const willShowSub = Keyboard.addListener('keyboardDidShow', () => {
      if (isNearBottomRef.current) {
        scrollToBottom(false);
      }
    });
    const willHideSub = Keyboard.addListener('keyboardDidHide', () => {
      if (isNearBottomRef.current) {
        scrollToBottom(false);
      }
    });

    return () => {
      showSub.remove();
      hideSub.remove();
      willShowSub.remove();
      willHideSub.remove();
    };
  }, [scrollToBottom]);

  return (
    <>
      <Animated.View style={[{ flex: 1 }, animatedContainerStyle]}>
        <ScrollView
          ref={scrollViewRef}
          style={styles.scrollView}
          onScroll={handleScroll}
          onLayout={() => {
            if (isNearBottomRef.current) {
              scrollToBottom(false);
            }
          }}
          onContentSizeChange={() => {
            if (isNearBottomRef.current) {
              scrollToBottom(false);
            }
          }}
          scrollEventThrottle={16}
          keyboardDismissMode="interactive"
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          maintainVisibleContentPosition={{ minIndexForVisible: 0 }}
        >
          <View style={styles.container}>
            {isLoadingMessages && messages.length === 0 ? (
              <MessageSkeleton />
            ) : (
              <>
                {hasMoreMessages && messages.length > 0 && (
                  <View style={styles.loadingMoreWrapper}>
                    <Text style={styles.loadingMoreText}>Loading...</Text>
                  </View>
                )}
                {messages.map((msg, index) => {
                  const isUser = msg.role === 'user';
                  const isLastMessage = index === messages.length - 1;
                  const isStreamingThisMessage =
                    isSending && isLastMessage && !isUser;
                  const showActions =
                    !isStreamingThisMessage && msg.text.length > 0;

                  if (isUser) {
                    return (
                      <UserMessageItem
                        key={msg.id}
                        msg={msg}
                        onLongPress={handleUserLongPress}
                      />
                    );
                  }

                  return (
                    <ResponseMessage
                      key={msg.id}
                      message={msg}
                      isStreaming={isStreamingThisMessage}
                      showActions={showActions}
                      isTtsSpeaking={
                        isTtsSpeaking &&
                        (!currentTtsMsgId || currentTtsMsgId === msg.id)
                      }
                      isTtsPaused={
                        isTtsPaused &&
                        (!currentTtsMsgId || currentTtsMsgId === msg.id)
                      }
                      onSpeakerPress={() =>
                        handleSpeakerPress(msg.id, msg.text)
                      }
                    />
                  );
                })}
              </>
            )}

            {isThinking && (
              <View style={styles.messageWrapper} key="thinking-indicator">
                <View style={styles.thinkingRow}>
                  <Brain size={IconSizes.sm} color={Colors.accentLightBlue} />
                  <Text style={styles.thinkingText}>Thinking…</Text>
                </View>
              </View>
            )}

            {error && (
              <View style={styles.errorWrapper}>
                <Text style={styles.errorText}>{error}</Text>
              </View>
            )}
          </View>
        </ScrollView>

        <View style={styles.topGradient} pointerEvents="none">
          <Svg height={GRADIENT_TOP_HEIGHT} width={SCREEN_W}>
            <Defs>
              <SvgGradient id="topFade" x1="0" y1="0" x2="0" y2="1">
                <Stop offset="0" stopColor={Colors.bgSurface} stopOpacity="1" />
                <Stop offset="1" stopColor={Colors.bgSurface} stopOpacity="0" />
              </SvgGradient>
            </Defs>
            <Rect
              width={SCREEN_W}
              height={GRADIENT_TOP_HEIGHT}
              fill="url(#topFade)"
            />
          </Svg>
        </View>

        <View style={styles.bottomGradient} pointerEvents="none">
          <Svg height={GRADIENT_BOTTOM_HEIGHT} width={SCREEN_W}>
            <Defs>
              <SvgGradient id="bottomFade" x1="0" y1="0" x2="0" y2="1">
                <Stop offset="0" stopColor={Colors.bgSurface} stopOpacity="0" />
                <Stop offset="1" stopColor={Colors.bgSurface} stopOpacity="1" />
              </SvgGradient>
            </Defs>
            <Rect
              width={SCREEN_W}
              height={GRADIENT_BOTTOM_HEIGHT}
              fill="url(#bottomFade)"
            />
          </Svg>
        </View>

        {showScrollDown && (
          <RNAnimated.View
            style={[
              styles.scrollDownButtonWrapper,
              {
                opacity: scrollDownAnim,
              },
            ]}
          >
            <TouchableOpacity
              style={styles.scrollDownButton}
              activeOpacity={0.75}
              onPress={handleScrollDownPress}
            >
              <ArrowDown size={IconSizes.lg} color={Colors.textPrimary} />
            </TouchableOpacity>
          </RNAnimated.View>
        )}
      </Animated.View>

      <ContextMenu
        visible={contextMenuState.visible}
        anchor={contextMenuState.anchor}
        align="right"
        targetHeight={contextMenuState.anchor?.height}
        header={
          contextMenuState.msg ? (
            <Text style={styles.contextHeaderTime}>
              {formatMessageTime(contextMenuState.msg.createdAt)}
            </Text>
          ) : undefined
        }
        items={[
          {
            id: 'copy',
            label: 'Copy',
            icon: <Copy size={IconSizes.md} color={Colors.textPrimary} />,
          },
          {
            id: 'edit',
            label: 'Edit message',
            icon: <Pencil size={IconSizes.md} color={Colors.textPrimary} />,
          },
          {
            id: 'share',
            label: 'Share prompt',
            icon: <Share2 size={IconSizes.md} color={Colors.textPrimary} />,
          },
        ]}
        onSelect={onContextSelect}
        onDismiss={() =>
          setContextMenuState({ visible: false, anchor: null, msg: null })
        }
      />
    </>
  );
}

export default ChatMessages;

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    backgroundColor: Colors.bgDeepest,
    paddingHorizontal: 16,
    paddingTop: 70,
    paddingBottom: GRADIENT_BOTTOM_HEIGHT + 12,
    gap: 8,
  },
  scrollView: { flex: 1 },
  messageWrapper: {
    width: '100%',
  },
  userWrapper: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    width: '100%',
  },

  skeletonContainer: {
    paddingTop: 20,
    gap: 16,
  },
  skeletonBubble: {
    height: 48,
    borderRadius: Radius.xl,
    backgroundColor: Colors.bgTertiary,
    opacity: 0.5,
  },
  skeletonUser: {
    alignSelf: 'flex-end',
    width: '70%',
    backgroundColor: Colors.userBubbleBg,
  },
  skeletonAssistant: {
    alignSelf: 'flex-start',
    width: '80%',
  },
  loadingMoreWrapper: {
    alignItems: 'center',
    paddingVertical: 10,
  },
  loadingMoreText: {
    color: Colors.textMuted,
    fontSize: Typography.sizeSm,
  },

  userTouchArea: {
    maxWidth: '80%',
    alignSelf: 'flex-end',
  },
  userBubble: {
    backgroundColor: Colors.userBubbleBg,
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: Radius.xl,
    alignSelf: 'flex-end',
  },
  userText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeBase,
    lineHeight: 24,
  },
  thinkingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 6,
    paddingHorizontal: 4,
  },
  thinkingText: {
    fontSize: Typography.sizeBase,
    fontWeight: '600',
    color: Colors.accentLightBlue,
    fontStyle: 'italic',
  },
  contextHeaderTime: {
    color: Colors.textMuted,
    fontSize: Typography.sizeBase,
  },
  errorWrapper: {
    alignSelf: 'center',
    backgroundColor: Colors.errorBubbleBg,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: Radius.sm,
    marginTop: 8,
  },
  errorText: { color: Colors.error, fontSize: Typography.sizeBase },
  topGradient: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: GRADIENT_TOP_HEIGHT,
  },
  bottomGradient: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: GRADIENT_BOTTOM_HEIGHT,
  },
  scrollDownButtonWrapper: {
    position: 'absolute',
    bottom: 12,
    alignSelf: 'center',
    zIndex: 25,
  },
  scrollDownButton: {
    width: 45,
    height: 45,
    borderRadius: Radius.full,
    backgroundColor: Colors.bgTertiary,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.35,
    shadowRadius: 6,
    elevation: 6,
    marginBottom: 24,
  },
});
