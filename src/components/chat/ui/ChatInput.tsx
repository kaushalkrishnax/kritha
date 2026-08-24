import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  Animated,
  NativeSyntheticEvent,
  TextLayoutEventData,
} from 'react-native';
import { Mic, Square, ArrowUp, Plus, AudioLines } from 'lucide-react-native';
import Colors from '@/theme';
import { useAssistantStore } from '@/store/assistantStore';

export interface ChatInputProps {
  draft?: string;
  setDraft?: (text: string) => void;
  isSending?: boolean;
  isRecording?: boolean;
  isProcessing?: boolean;
  isLiveTalk?: boolean;
  onSendMessage?: () => void;
  onDictatePress?: () => void;
  onLiveTalkPress?: () => void;
  onStopDictation?: () => void;
  onStopResponse?: () => void;
}

const MULTIPLIERS = [
  0.35, 0.65, 0.95, 0.55, 0.85, 1.2, 0.7, 1.0, 1.3, 0.8, 0.45, 0.9, 1.15, 0.6,
  0.9, 0.55, 0.8, 0.35, 0.6, 1.0, 0.45, 0.7,
];

const LINE_HEIGHT = 22;
const MAX_LINES = 6;
const MAX_INPUT_HEIGHT = LINE_HEIGHT * MAX_LINES;
const COMPACT_HEIGHT = 58;
const EXPANDED_MIN_HEIGHT = 96;
const BOTTOM_ROW_HEIGHT = 38;

export function ChatInput({
  draft = '',
  setDraft,
  isSending = false,
  isRecording = false,
  isProcessing = false,
  isLiveTalk = false,
  onSendMessage,
  onDictatePress,
  onLiveTalkPress,
  onStopDictation,
  onStopResponse,
}: ChatInputProps) {
  const hasText = draft.trim().length > 0;

  const [volume, setVolume] = useState(0);
  const [isExpanded, setIsExpanded] = useState(false);
  const [measuredLines, setMeasuredLines] = useState(1);

  const dotsOpacity = useRef(new Animated.Value(1)).current;
  const glowOpacity = useRef(new Animated.Value(0.2)).current;
  const glowScale = useRef(new Animated.Value(1)).current;

  const requestOrigin = useAssistantStore((s) => s.requestOrigin);
  const responseText = useAssistantStore((s) => s.response);
  const canonicalState = useAssistantStore((s) => s.canonicalState);

  const isVoiceRequest =
    requestOrigin === 'WAKE_WORD' || requestOrigin === 'MANUAL_DICTATION';
  const isWaitingForFirstToken =
    canonicalState === 'THINKING' ||
    (canonicalState === 'GENERATING' && !responseText);
  const showJustASec = isVoiceRequest && isWaitingForFirstToken;

  const showStop = !isRecording && (isProcessing || isSending || showJustASec);
  const showSend = !isRecording && !isProcessing && !isSending && hasText;

  const fadeAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (isProcessing) {
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
    } else {
      fadeAnim.setValue(1);
    }
  }, [isProcessing, fadeAnim]);

  useEffect(() => {
    if (!hasText) {
      setIsExpanded(false);
      setMeasuredLines(1);
      return;
    }

    setIsExpanded(measuredLines > 1);
  }, [hasText, measuredLines]);

  const storeVolumeRms = useAssistantStore((state) => state.volumeRms);

  useEffect(() => {
    if (!isRecording) {
      setVolume(0);
      return;
    }
    const scaled = Math.max(0, Math.min(12, storeVolumeRms * 1.2));
    setVolume(scaled);
  }, [isRecording, storeVolumeRms]);

  useEffect(() => {
    if (!isProcessing && !isSending) {
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
  }, [isProcessing, isSending, dotsOpacity]);

  useEffect(() => {
    if (isRecording) {
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

      return;
    }

    Animated.parallel([
      Animated.timing(glowScale, {
        toValue: 1,
        duration: 250,
        useNativeDriver: true,
      }),
      Animated.timing(glowOpacity, {
        toValue: isProcessing || isSending ? 0.3 : 0.2,
        duration: 250,
        useNativeDriver: true,
      }),
    ]).start();
  }, [isRecording, volume, isProcessing, isSending, glowScale, glowOpacity]);

  const handleTextChange = (text: string) => {
    setDraft?.(text);

    if (!text.trim()) {
      setIsExpanded(false);
      setMeasuredLines(1);
    }
  };

  const handleMeasureText = (
    event: NativeSyntheticEvent<TextLayoutEventData>,
  ) => {
    const lines = event.nativeEvent.lines.length;
    setMeasuredLines(lines);
  };

  const getBarHeight = (multiplier: number) => {
    const dynamic = (volume / 12) * 20 * multiplier;
    return Math.max(3, Math.min(22, 4 + dynamic));
  };

  const handleActionPress = () => {
    if (isRecording) {
      onStopDictation?.();
      return;
    }

    if (showStop) {
      onStopResponse?.();
      return;
    }

    if (showSend) {
      onSendMessage?.();
      return;
    }

    if (onLiveTalkPress) {
      onLiveTalkPress();
    } else {
      onDictatePress?.();
    }
  };

  const renderAction = () => {
    if (isRecording) {
      return (
        <TouchableOpacity
          onPress={handleActionPress}
          activeOpacity={0.82}
          style={styles.actionButton}
        >
          <ArrowUp size={18} color={Colors.textOnAccent} />
        </TouchableOpacity>
      );
    }

    if (showStop) {
      return (
        <TouchableOpacity
          onPress={handleActionPress}
          activeOpacity={0.82}
          style={styles.actionButton}
        >
          <Square size={16} color={Colors.textOnAccent} />
        </TouchableOpacity>
      );
    }

    if (showSend) {
      return (
        <TouchableOpacity
          onPress={handleActionPress}
          activeOpacity={0.82}
          style={styles.actionButton}
        >
          <ArrowUp size={18} color={Colors.textOnAccent} />
        </TouchableOpacity>
      );
    }

    return (
      <TouchableOpacity
        onPress={handleActionPress}
        activeOpacity={0.82}
        style={[styles.actionButton, isLiveTalk && styles.liveTalkActiveButton]}
      >
        <AudioLines
          size={19}
          color={isLiveTalk ? Colors.accentCyan : Colors.textOnAccent}
        />
      </TouchableOpacity>
    );
  };

  const expandedHeight = Math.min(
    EXPANDED_MIN_HEIGHT + Math.max(0, measuredLines - 2) * LINE_HEIGHT,
    MAX_INPUT_HEIGHT + BOTTOM_ROW_HEIGHT + 16,
  );

  return (
    <View style={styles.container}>
      <View
        style={[
          styles.composer,
          isExpanded && styles.expandedComposer,
          {
            height: isExpanded ? expandedHeight : COMPACT_HEIGHT,
          },
        ]}
      >
        {isRecording ? (
          <View style={styles.recordingRow}>
            <TouchableOpacity activeOpacity={0.7} style={styles.plusButton}>
              <Plus size={22} color={Colors.textSecondary} />
            </TouchableOpacity>

            <View style={styles.waveformContainer}>
              <View style={styles.waveform} pointerEvents="none">
                {MULTIPLIERS.map((multiplier, index) => (
                  <View
                    key={index}
                    style={[
                      styles.waveBar,
                      {
                        height: getBarHeight(multiplier),
                      },
                    ]}
                  />
                ))}
              </View>
            </View>

            {renderAction()}
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
                    size={22}
                    color={
                      showJustASec ? Colors.textMuted : Colors.textSecondary
                    }
                  />
                </TouchableOpacity>
              )}

              <TextInput
                value={showJustASec ? '' : draft}
                onChangeText={handleTextChange}
                editable={!showJustASec}
                style={[styles.input, isExpanded && styles.expandedInput]}
                placeholder={showJustASec ? 'Just a sec...' : 'Ask Kritha...'}
                placeholderTextColor="rgba(232,234,237,0.46)"
                multiline
                textAlignVertical={isExpanded ? 'top' : 'center'}
                scrollEnabled={isExpanded && measuredLines >= MAX_LINES}
              />

              {!isExpanded && (
                <View style={styles.compactActions}>
                  {!isRecording && !showJustASec && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={onDictatePress}
                    >
                      <Mic size={20} color={Colors.iconSlate} />
                    </TouchableOpacity>
                  )}

                  {renderAction()}
                </View>
              )}
            </View>

            {isExpanded && (
              <View style={styles.expandedBottomRow}>
                <TouchableOpacity activeOpacity={0.7} style={styles.plusButton}>
                  <Plus size={22} color={Colors.textSecondary} />
                </TouchableOpacity>

                <View style={styles.compactActions}>
                  {!isRecording && !showJustASec && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={onDictatePress}
                    >
                      <Mic size={20} color={Colors.iconSlate} />
                    </TouchableOpacity>
                  )}

                  {renderAction()}
                </View>
              </View>
            )}
          </>
        )}

        <View pointerEvents="none" style={styles.measurementContainer}>
          <Text style={styles.measurementText} onTextLayout={handleMeasureText}>
            {draft || ' '}
          </Text>
        </View>
      </View>
    </View>
  );
}

export default ChatInput;

const styles = StyleSheet.create({
  container: {
    width: '100%',
    paddingHorizontal: 20,
    paddingTop: 6,
    paddingBottom: 12,
    alignItems: 'center',
    position: 'relative',
    backgroundColor: 'transparent',
  },

  composer: {
    width: '100%',
    minHeight: COMPACT_HEIGHT,
    borderRadius: 28,
    backgroundColor: Colors.bgCard,
    paddingHorizontal: 8,
    paddingVertical: 6,
    position: 'relative',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 6,
    },
    shadowOpacity: 0.35,
    shadowRadius: 14,
    elevation: 10,
  },

  expandedComposer: {
    borderRadius: 24,
    paddingHorizontal: 8,
    paddingTop: 10,
    paddingBottom: 8,
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
    paddingHorizontal: 6,
  },

  waveform: {
    width: '100%',
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },

  waveBar: {
    width: 2,
    minHeight: 3,
    maxHeight: 22,
    borderRadius: 2,
    backgroundColor: Colors.textOnAccent,
    opacity: 0.95,
  },

  inputArea: {
    width: '100%',
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: 2,
    paddingRight: 2,
  },

  inputAreaExpanded: {
    flex: 1,
    height: undefined,
    alignItems: 'flex-start',
    paddingHorizontal: 4,
    paddingTop: 2,
  },

  input: {
    flex: 1,
    minHeight: LINE_HEIGHT,
    color: Colors.textSecondary,
    fontSize: 15.5,
    fontWeight: '400',
    lineHeight: LINE_HEIGHT,
    padding: 0,
    margin: 0,
    textAlignVertical: 'center',
  },

  expandedInput: {
    width: '100%',
    height: '100%',
    fontSize: 15.5,
    lineHeight: LINE_HEIGHT,
    textAlignVertical: 'top',
    paddingTop: 0,
  },

  compactActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },

  expandedBottomRow: {
    width: '100%',
    height: BOTTOM_ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 2,
    paddingTop: 2,
    paddingBottom: 2,
  },

  plusButton: {
    width: 38,
    height: 38,
    alignItems: 'center',
    justifyContent: 'center',
  },

  actionButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: Colors.accentBlue,
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
    width: 36,
    height: 38,
    alignItems: 'center',
    justifyContent: 'center',
  },

  measurementContainer: {
    position: 'absolute',
    left: 48,
    right: 48,
    top: 0,
    opacity: 0,
    pointerEvents: 'none',
  },

  measurementText: {
    fontSize: 15.5,
    fontWeight: '400',
    lineHeight: LINE_HEIGHT,
    padding: 0,
    margin: 0,
  },

  processingTextContainer: {
    flex: 1,
    justifyContent: 'center',
    paddingLeft: 4,
  },

  justASecText: {
    color: Colors.textSecondary,
    fontSize: 15.5,
    fontWeight: '400',
    fontStyle: 'italic',
  },
});
