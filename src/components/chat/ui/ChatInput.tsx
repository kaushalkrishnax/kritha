import {
  ArrowUp,
  AudioLines,
  Info,
  Mic,
  Plus,
  Square,
  X,
} from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  LayoutChangeEvent,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import uuid from 'react-native-uuid';
import { ChatMode, RequestOrigin } from '@/constants';
import { useChatInputHeight } from '@/hooks';
import * as assistantRuntime from '@/services/assistantRuntime.service';
import {
  useAssistantStore,
  useChatStore,
  useIsLlmBusy,
  useIsLlmGenerating,
  useIsLlmThinking,
  useIsSttTranscribing,
  useModelStore,
} from '@/stores';
import { Colors, IconSizes, Radius, Spacing, Typography } from '@/theme';

const MULTIPLIERS = [
  0.35, 0.65, 0.95, 0.55, 0.85, 1.2, 0.7, 1.0, 1.3, 0.8, 0.45, 0.9, 1.15, 0.6,
  0.9, 0.55, 0.8, 0.35, 0.6, 1.0, 0.45, 0.7,
];
const LINE_HEIGHT = 24;
const MAX_LINES = 8;
const MAX_INPUT_HEIGHT = LINE_HEIGHT * MAX_LINES;
const COMPACT_HEIGHT = 58;
const EXPANDED_MIN_HEIGHT = 116;
const BOTTOM_ROW_HEIGHT = 44;

export function ChatInput({
  modelId,
  variant = 'overlay',
}: {
  modelId?: string;
  variant?: 'overlay' | 'chat';
}) {
  const requestOrigin = useAssistantStore((s) => s.requestOrigin);
  const volumeRms = useAssistantStore((s) => s.volumeRms);
  const response = useAssistantStore((s) => s.response);
  const chatMode = useAssistantStore((s) => s.chatMode);
  const draftText = useAssistantStore((s) => s.draftText);
  const setDraftText = useAssistantStore((s) => s.setDraftText);
  const editingMessageId = useAssistantStore((s) => s.editingMessageId);
  const setEditingMessageId = useAssistantStore((s) => s.setEditingMessageId);
  const selectedModelId = useModelStore((s) => s.selectedModelId);
  const chatSessionId = useChatStore((s) => s.chatSessionId);
  const { setChatInputHeight } = useChatInputHeight();

  const isBusy = useIsLlmBusy();
  const isThinking = useIsLlmThinking();
  const isGenerating = useIsLlmGenerating();
  const isTranscribing = useIsSttTranscribing();

  const effectiveModelId = modelId ?? selectedModelId;

  const hasText = draftText.trim().length > 0;
  const showJustASec =
    variant === 'overlay' &&
    (requestOrigin === RequestOrigin.WAKE_WORD ||
      requestOrigin === RequestOrigin.MANUAL_DICTATION) &&
    (isThinking || (isGenerating && !response));

  const [measuredLines, setMeasuredLines] = useState(1);

  const isDictationMode = chatMode === ChatMode.DICTATION;
  const volume = isDictationMode
    ? Math.max(0, Math.min(12, volumeRms * 1.2))
    : 0;
  const isExpanded = hasText && measuredLines > 1;

  const [dotsOpacity] = useState(() => new Animated.Value(1));
  const [glowOpacity] = useState(() => new Animated.Value(0.2));
  const [glowScale] = useState(() => new Animated.Value(1));
  const [fadeAnim] = useState(() => new Animated.Value(1));

  /** Animation synchronizations */
  useEffect(() => {
    if (isGenerating) {
      const animation = Animated.loop(
        Animated.sequence([
          Animated.timing(fadeAnim, {
            toValue: 0.25,
            duration: 700,
            useNativeDriver: true,
          }),
          Animated.timing(fadeAnim, {
            toValue: 1,
            duration: 700,
            useNativeDriver: true,
          }),
        ]),
      );
      animation.start();
      return () => animation.stop();
    }
    fadeAnim.setValue(1);
  }, [isGenerating, fadeAnim]);

  const inputRef = useRef<TextInput>(null);

  useEffect(() => {
    if (editingMessageId && inputRef.current) {
      inputRef.current.focus();
    }
  }, [editingMessageId]);

  useEffect(() => {
    if (!isGenerating && !isThinking) {
      dotsOpacity.setValue(1);
      return;
    }
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(dotsOpacity, {
          toValue: 0.4,
          duration: 700,
          useNativeDriver: true,
        }),
        Animated.timing(dotsOpacity, {
          toValue: 1,
          duration: 700,
          useNativeDriver: true,
        }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [isGenerating, isThinking, dotsOpacity]);

  useEffect(() => {
    if (isDictationMode) {
      Animated.parallel([
        Animated.spring(glowScale, {
          toValue: 1 + (volume / 12) * 0.12,
          tension: 120,
          friction: 8,
          useNativeDriver: true,
        }),
        Animated.timing(glowOpacity, {
          toValue: 0.35 + (volume / 12) * 0.4,
          duration: 90,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      Animated.parallel([
        Animated.timing(glowScale, {
          toValue: 1,
          duration: 250,
          useNativeDriver: true,
        }),
        Animated.timing(glowOpacity, {
          toValue: isGenerating || isThinking ? 0.3 : 0.2,
          duration: 250,
          useNativeDriver: true,
        }),
      ]).start();
    }
  }, [
    isDictationMode,
    volume,
    isGenerating,
    isThinking,
    glowScale,
    glowOpacity,
  ]);

  const handleTextChange = (text: string) => {
    setDraftText(text);
    if (!text.trim()) {
      setMeasuredLines(1);
    }
  };

  const getBarHeight = (multiplier: number) =>
    Math.max(8, Math.min(42, 6 + (volume / 12) * 36 * multiplier));

  const handleSubmit = () => {
    if (!effectiveModelId) return;
    const msgId = String(uuid.v4());
    if (editingMessageId) {
      assistantRuntime.editAndResubmitPrompt(
        editingMessageId,
        draftText,
        effectiveModelId,
        chatSessionId,
        msgId,
      );
    } else {
      assistantRuntime.submitPrompt({
        text: draftText,
        origin: RequestOrigin.MANUAL_TYPING,
        modelId: effectiveModelId,
        sessionId: chatSessionId,
        msgId,
      });
    }
  };

  const handleSubmitDictation = async () => {
    if (!effectiveModelId) return;

    const text = await assistantRuntime.stopDictation();
    const promptText = text.trim() || draftText.trim();

    if (!promptText) return;
    const msgId = String(uuid.v4());

    await assistantRuntime.submitPrompt({
      text: promptText,
      origin: RequestOrigin.MANUAL_DICTATION,
      modelId: effectiveModelId,
      sessionId: chatSessionId,
      msgId,
    });
  };

  const handleActionPress = () => {
    if (chatMode === ChatMode.DICTATION) {
      handleSubmitDictation();
      return;
    }
    if (isBusy || showJustASec) {
      assistantRuntime.cancelRun();
      return;
    }
    if (!isBusy && hasText) return handleSubmit();
    assistantRuntime.startLiveTalk({ sessionId: chatSessionId });
  };

  const handleCancelEdit = () => {
    setEditingMessageId(null);
    setDraftText('');
  };

  const handleContainerLayout = useCallback(
    (event: LayoutChangeEvent) => {
      const height = Math.ceil(event.nativeEvent.layout.height);

      setChatInputHeight(height);
    },
    [setChatInputHeight],
  );

  const expandedHeight = Math.min(
    EXPANDED_MIN_HEIGHT + Math.max(0, measuredLines - 2) * LINE_HEIGHT,
    MAX_INPUT_HEIGHT + BOTTOM_ROW_HEIGHT + 24,
  );

  return (
    <View style={styles.container}>
      {!!editingMessageId && (
        <View style={styles.editingWarningWrapper}>
          <Info
            size={IconSizes.sm}
            color={Colors.textPrimary}
            style={{ marginRight: Spacing.sm }}
          />
          <Text style={styles.editingWarningText}>
            Editing this message will restart the conversation from here.
          </Text>
          <TouchableOpacity
            onPress={handleCancelEdit}
            style={styles.editingWarningCloseBtn}
          >
            <X size={IconSizes.sm} color={Colors.textSecondary} />
          </TouchableOpacity>
        </View>
      )}
      <View
        style={[
          styles.composer,
          isExpanded && styles.expandedComposer,
          { height: isExpanded ? expandedHeight : COMPACT_HEIGHT },
        ]}
        onLayout={handleContainerLayout}
      >
        {chatMode === ChatMode.DICTATION ? (
          <View style={styles.recordingRow}>
            <TouchableOpacity
              activeOpacity={0.7}
              style={styles.plusButton}
              onPress={() => assistantRuntime.cancelDictation()}
            >
              <X size={IconSizes.lg} color={Colors.textSecondary} />
            </TouchableOpacity>

            {isTranscribing && (
              <View style={styles.plusButton}>
                <ActivityIndicator size="small" color={Colors.textSecondary} />
              </View>
            )}

            {isTranscribing ? (
              <View
                style={[styles.waveformContainer, { justifyContent: 'center' }]}
              >
                <Text
                  style={{
                    color: Colors.textMuted,
                    fontSize: Typography.sizeMd,
                    fontFamily: 'Inter-Medium',
                  }}
                >
                  Transcribing...
                </Text>
              </View>
            ) : (
              <View style={styles.waveformContainer}>
                <View style={styles.waveform} pointerEvents="none">
                  {MULTIPLIERS.map((multiplier, i) => (
                    <View
                      key={i}
                      style={[
                        styles.waveBar,
                        { height: getBarHeight(multiplier) },
                      ]}
                    />
                  ))}
                </View>
              </View>
            )}
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                gap: Spacing.sm,
              }}
            >
              <TouchableOpacity
                onPress={() => assistantRuntime.stopDictation()}
                activeOpacity={0.82}
                style={[
                  styles.stopButton,
                  isTranscribing && {
                    opacity: 0.5,
                  },
                ]}
                disabled={isTranscribing}
              >
                <Square size={IconSizes.base} color={Colors.iconSlate} />
              </TouchableOpacity>
              <TouchableOpacity
                onPress={handleActionPress}
                activeOpacity={0.82}
                style={[
                  styles.actionButton,
                  !hasText &&
                    chatMode !== ChatMode.DICTATION && {
                      opacity: 0.5,
                    },
                ]}
                disabled={!hasText && chatMode !== ChatMode.DICTATION}
              >
                <ArrowUp size={IconSizes.md} color={Colors.textOnAccent} />
              </TouchableOpacity>
            </View>
          </View>
        ) : (
          <>
            <View
              style={[styles.inputArea, isExpanded && styles.inputAreaExpanded]}
            >
              {!isExpanded && (
                <TouchableOpacity
                  activeOpacity={0.7}
                  style={[styles.plusButton, showJustASec && { opacity: 0.35 }]}
                  disabled={showJustASec}
                >
                  <Plus
                    size={IconSizes.lg}
                    color={
                      showJustASec ? Colors.textMuted : Colors.textSecondary
                    }
                  />
                </TouchableOpacity>
              )}
              <TextInput
                ref={inputRef}
                value={showJustASec ? '' : draftText}
                onChangeText={handleTextChange}
                editable={!showJustASec}
                style={[styles.input, isExpanded && styles.expandedInput]}
                placeholder={showJustASec ? 'Just a sec...' : 'Ask Kritha...'}
                placeholderTextColor="rgba(232,234,237,0.46)"
                multiline
                autoCapitalize="none"
                autoCorrect={false}
                textAlignVertical={isExpanded ? 'top' : 'center'}
                scrollEnabled={isExpanded && measuredLines >= MAX_LINES}
              />
              {!isExpanded && (
                <View style={styles.compactActions}>
                  {!showJustASec && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={() => assistantRuntime.startDictation()}
                    >
                      <Mic size={IconSizes.lg} color={Colors.textPrimary} />
                    </TouchableOpacity>
                  )}
                  <TouchableOpacity
                    onPress={handleActionPress}
                    activeOpacity={0.82}
                    style={styles.actionButton}
                  >
                    {isBusy || showJustASec ? (
                      <Square size={16} color={Colors.textOnAccent} />
                    ) : !isBusy && hasText ? (
                      <ArrowUp
                        size={IconSizes.md}
                        color={Colors.textOnAccent}
                      />
                    ) : (
                      <AudioLines
                        size={IconSizes.md}
                        color={Colors.textOnAccent}
                      />
                    )}
                  </TouchableOpacity>
                </View>
              )}
            </View>
            {isExpanded && (
              <View style={styles.expandedBottomRow}>
                <TouchableOpacity activeOpacity={0.7} style={styles.plusButton}>
                  <Plus size={IconSizes.md} color={Colors.textSecondary} />
                </TouchableOpacity>
                <View style={styles.compactActions}>
                  {!showJustASec && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={() => assistantRuntime.startDictation()}
                    >
                      <Mic size={IconSizes.lg} color={Colors.iconSlate} />
                    </TouchableOpacity>
                  )}
                  <TouchableOpacity
                    onPress={handleActionPress}
                    activeOpacity={0.82}
                    style={styles.actionButton}
                  >
                    {isBusy || showJustASec ? (
                      <Square size={16} color={Colors.textOnAccent} />
                    ) : !isBusy && hasText ? (
                      <ArrowUp
                        size={IconSizes.sm}
                        color={Colors.textOnAccent}
                      />
                    ) : (
                      <AudioLines
                        size={IconSizes.sm}
                        color={Colors.textOnAccent}
                      />
                    )}
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </>
        )}
        <View pointerEvents="none" style={styles.measurementContainer}>
          <Text
            style={styles.measurementText}
            onTextLayout={(e) => setMeasuredLines(e.nativeEvent.lines.length)}
          >
            {draftText || ' '}
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.md,
    alignItems: 'center',
    position: 'relative',
    backgroundColor: 'transparent',
  },

  composer: {
    width: '100%',
    minHeight: COMPACT_HEIGHT,
    borderRadius: Radius['2xl'],
    backgroundColor: Colors.bgSecondary,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.sm,
    position: 'relative',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.35,
    shadowRadius: 12,
    elevation: 8,
  },

  expandedComposer: {
    borderRadius: Radius.xl,
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },

  recordingRow: {
    width: '100%',
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
  },

  waveformContainer: {
    flex: 1,
    height: 44,
    justifyContent: 'center',
    paddingHorizontal: Spacing.md,
  },

  waveform: {
    width: '100%',
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.xs,
  },

  waveBar: {
    width: 2,
    minHeight: 6,
    maxHeight: 40,
    borderRadius: Radius.xs,
    backgroundColor: Colors.textOnAccent,
    opacity: 0.95,
  },

  inputArea: {
    width: '100%',
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
  },

  inputAreaExpanded: {
    flex: 1,
    height: undefined,
    alignItems: 'flex-start',
    paddingHorizontal: Spacing.sm,
    paddingTop: 0,
    paddingBottom: Spacing['2xs'],
  },

  input: {
    flex: 1,
    minHeight: LINE_HEIGHT,
    color: Colors.textSecondary,
    fontSize: Typography.sizeBase,
    lineHeight: LINE_HEIGHT,
    padding: 0,
    margin: 0,
    textAlignVertical: 'center',
  },

  expandedInput: {
    width: '100%',
    height: '100%',
    fontSize: Typography.sizeBase,
    lineHeight: LINE_HEIGHT,
    textAlignVertical: 'top',
    paddingTop: 0,
    paddingBottom: 0,
  },

  compactActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
  },

  expandedBottomRow: {
    width: '100%',
    height: BOTTOM_ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing['2xs'],
    marginTop: Spacing.xs,
  },

  plusButton: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },

  actionButton: {
    width: 40,
    height: 40,
    borderRadius: Radius.lg,
    backgroundColor: Colors.accentBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },

  stopButton: {
    width: 40,
    height: 40,
    borderRadius: Radius.lg,
    backgroundColor: Colors.bgTertiary,
    alignItems: 'center',
    justifyContent: 'center',
  },

  recordingButton: {
    backgroundColor: Colors.accentCyanBg,
    shadowColor: Colors.accentSky,
    shadowOffset: {
      width: 0,
      height: 0,
    },
    shadowOpacity: 0.85,
    shadowRadius: 10,
    elevation: 6,
  },

  liveTalkActiveButton: {
    backgroundColor: Colors.accentCyanBg,
    borderWidth: 1.5,
    borderColor: Colors.accentCyan,
    shadowColor: Colors.accentCyan,
    shadowOffset: {
      width: 0,
      height: 0,
    },
    shadowOpacity: 0.9,
    shadowRadius: 8,
    elevation: 6,
  },

  voiceModeButton: {
    width: 40,
    height: 40,
    borderRadius: Radius.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },

  measurementContainer: {
    position: 'absolute',
    left: Spacing.xl,
    right: Spacing.xl,
    top: 0,
    opacity: 0,
    pointerEvents: 'none',
  },

  measurementText: {
    fontSize: Typography.sizeBase,
    fontWeight: '400',
    lineHeight: LINE_HEIGHT,
    padding: 0,
    margin: 0,
  },

  processingTextContainer: {
    flex: 1,
    justifyContent: 'center',
    paddingLeft: Spacing.xs,
  },

  justASecText: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeBase,
    fontWeight: '400',
    fontStyle: 'italic',
  },

  editingWarningWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.bgSecondary,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: Radius.md,
    marginBottom: Spacing.md,
    width: '100%',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 4,
  },
  editingWarningText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeSm,
    fontWeight: '500',
    flex: 1,
  },
  editingWarningCloseBtn: {
    padding: Spacing.xs,
    marginLeft: Spacing.sm,
  },
});
