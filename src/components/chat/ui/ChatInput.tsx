import React, { useEffect, useRef, useState } from 'react';
import { View, Text, TextInput, StyleSheet, TouchableOpacity, Animated } from 'react-native';
import { Mic, Square, ArrowUp, Plus, AudioLines } from 'lucide-react-native';
import Colors from '@/theme';
import KrithaNativeModule from '../../../../modules/kritha/src/KrithaModule';

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
  0.35, 0.65, 0.95, 0.55, 0.85, 1.2, 0.7, 1.0, 1.3, 0.8, 0.45,
  0.9, 1.15, 0.6, 0.9, 0.55, 0.8, 0.35, 0.6, 1.0, 0.45, 0.7,
];


const LINE_HEIGHT = 24;
const MAX_LINES = 8;
const MAX_INPUT_HEIGHT = LINE_HEIGHT * MAX_LINES;
const COMPACT_HEIGHT = 74;
const EXPANDED_MIN_HEIGHT = 116;
const BOTTOM_ROW_HEIGHT = 44;

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

  const dotsOpacity = useRef(
    new Animated.Value(1),
  ).current;

  const glowOpacity = useRef(
    new Animated.Value(0.2),
  ).current;

  const glowScale = useRef(
    new Animated.Value(1),
  ).current;

  const showStop =
    !isRecording &&
    (isProcessing || isSending);

  const showSend =
    !isRecording &&
    !isProcessing &&
    !isSending &&
    hasText;

  const fadeAnim = useRef(
    new Animated.Value(1),
  ).current;

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

  useEffect(() => {
    if (!isRecording) {
      setVolume(0);
      return;
    }

    const subDictation =
      KrithaNativeModule.addListener(
        'onDictationVolume',
        event => {
          const value = Number(
            event?.volume ?? 0,
          );

          setVolume(
            Math.max(
              0,
              Math.min(12, value),
            ),
          );
        },
      );

    const subAssistant =
      KrithaNativeModule.addListener(
        'onAssistantEvent',
        event => {
          if (event.state === 'rms' && typeof event.rms === 'number') {
            const rawRms = Number(event.rms);
            const scaled = Math.max(0, Math.min(12, rawRms * 1.2));
            setVolume(scaled);
          }
        },
      );

    return () => {
      subDictation.remove();
      subAssistant.remove();
    };
  }, [isRecording]);

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
  }, [
    isProcessing,
    isSending,
    dotsOpacity,
  ]);

  useEffect(() => {
    if (isRecording) {
      Animated.parallel([
        Animated.spring(glowScale, {
          toValue:
            1 + (volume / 12) * 0.12,
          tension: 120,
          friction: 8,
          useNativeDriver: true,
        }),
        Animated.timing(glowOpacity, {
          toValue:
            0.35 + (volume / 12) * 0.4,
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
        toValue:
          isProcessing || isSending
            ? 0.3
            : 0.2,
        duration: 250,
        useNativeDriver: true,
      }),
    ]).start();
  }, [
    isRecording,
    volume,
    isProcessing,
    isSending,
    glowScale,
    glowOpacity,
  ]);

  const handleTextChange = (
    text: string,
  ) => {
    setDraft?.(text);

    if (!text.trim()) {
      setIsExpanded(false);
      setMeasuredLines(1);
    }
  };

  const handleMeasureText = (
    event: any,
  ) => {
    const lines =
      event.nativeEvent.lines.length;

    setMeasuredLines(lines);
  };

  const getBarHeight = (
    multiplier: number,
  ) => {
    const dynamic =
      (volume / 12) *
      22 *
      multiplier;

    return Math.max(
      4,
      Math.min(
        28,
        5 + dynamic,
      ),
    );
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
          style={[
            styles.actionButton,
            styles.recordingButton,
          ]}
        >
          <Mic
            size={21}
            color="#FFFFFF"
          />
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
          <Square
            size={20}
            color="#FFFFFF"
          />
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
          <ArrowUp
            size={21}
            color="#FFFFFF"
          />
        </TouchableOpacity>
      );
    }

    return (
      <TouchableOpacity
        onPress={handleActionPress}
        activeOpacity={0.82}
        style={[
          styles.actionButton,
          isLiveTalk && styles.liveTalkActiveButton,
        ]}
      >
        <AudioLines size={23} color={isLiveTalk ? Colors.accentCyan : Colors.textOnAccent} />
      </TouchableOpacity>
    );
  };

  const expandedHeight = Math.min(
    EXPANDED_MIN_HEIGHT +
    Math.max(
      0,
      measuredLines - 2,
    ) *
    LINE_HEIGHT,
    MAX_INPUT_HEIGHT +
    BOTTOM_ROW_HEIGHT +
    20,
  );

  return (
    <View style={styles.container}>

      <View
        style={[
          styles.composer,
          isExpanded &&
          styles.expandedComposer,
          {
            height: isExpanded
              ? expandedHeight
              : COMPACT_HEIGHT,
          },
        ]}
      >
        {isRecording ? (
          <View
            style={styles.recordingRow}
          >
            <TouchableOpacity
              activeOpacity={0.7}
              style={styles.plusButton}
            >
              <Plus
                size={25}
                color={Colors.textSecondary}
              />
            </TouchableOpacity>

            <View
              style={styles.waveformContainer}
            >
              <View
                style={styles.waveform}
                pointerEvents="none"
              >
                {MULTIPLIERS.map(
                  (
                    multiplier,
                    index,
                  ) => (
                    <View
                      key={index}
                      style={[
                        styles.waveBar,
                        {
                          height:
                            getBarHeight(
                              multiplier,
                            ),
                        },
                      ]}
                    />
                  ),
                )}
              </View>
            </View>

            {renderAction()}
          </View>
        ) : (
          <>
            <View
              style={[
                styles.inputArea,
                isExpanded &&
                styles.inputAreaExpanded,
              ]}
            >
              {!isExpanded && (
                <TouchableOpacity
                  activeOpacity={0.7}
                  style={styles.plusButton}
                >
                  <Plus
                    size={25}
                    color={Colors.textSecondary}
                  />
                </TouchableOpacity>
              )}

              <TextInput
                value={isProcessing ? '' : draft}
                onChangeText={handleTextChange}
                style={[
                  styles.input,
                  isExpanded && styles.expandedInput,
                ]}
                placeholder={
                  isProcessing
                    ? 'Just a Sec...'
                    : 'Ask Kritha...'
                }
                placeholderTextColor="rgba(232,234,237,0.46)"
                multiline
                textAlignVertical={isExpanded ? 'top' : 'center'}
                scrollEnabled={isExpanded && measuredLines >= MAX_LINES}
              />

              {!isExpanded && (
                <View style={styles.compactActions}>
                  {!isRecording && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={onDictatePress}
                    >
                      <Mic
                        size={22}
                        color={Colors.iconSlate}
                      />
                    </TouchableOpacity>
                  )}

                  {renderAction()}
                </View>
              )}
            </View>

            {isExpanded && (
              <View style={styles.expandedBottomRow}>
                <TouchableOpacity
                  activeOpacity={0.7}
                  style={styles.plusButton}
                >
                  <Plus
                    size={25}
                    color={Colors.textSecondary}
                  />
                </TouchableOpacity>

                <View style={styles.compactActions}>
                  {!isRecording && (
                    <TouchableOpacity
                      activeOpacity={0.7}
                      style={styles.voiceModeButton}
                      onPress={onDictatePress}
                    >
                      <Mic
                        size={22}
                        color={Colors.iconSlate}
                      />
                    </TouchableOpacity>
                  )}

                  {renderAction()}
                </View>
              </View>
            )}
          </>
        )}

        <View
          pointerEvents="none"
          style={styles.measurementContainer}
        >
          <Text
            style={styles.measurementText}
            onTextLayout={
              handleMeasureText
            }
          >
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
    paddingHorizontal: 24,
    paddingTop: 8,
    paddingBottom: 4,
    alignItems: 'center',
    position: 'relative',
    backgroundColor: 'transparent',
  },

  composer: {
    width: '100%',
    minHeight: COMPACT_HEIGHT,
    borderRadius: 36,
    backgroundColor: '#1E1F22',
    paddingHorizontal: 12,
    paddingVertical: 12,
    position: 'relative',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.12)',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.45,
    shadowRadius: 20,
    elevation: 14,
  },

  expandedComposer: {
    borderRadius: 36,
    paddingHorizontal: 10,
    paddingTop: 14,
    paddingBottom: 14,
  },

  recordingRow: {
    width: '100%',
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
  },

  waveformContainer: {
    flex: 1,
    height: 48,
    justifyContent: 'center',
    paddingHorizontal: 8,
  },

  waveform: {
    width: '100%',
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 5,
  },

  waveBar: {
    width: 2,
    minHeight: 4,
    maxHeight: 28,
    borderRadius: 2,
    backgroundColor: Colors.textOnAccent,
    opacity: 0.95,
  },

  inputArea: {
    width: '100%',
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: 4,
    paddingRight: 4,
  },

  inputAreaExpanded: {
    flex: 1,
    height: undefined,
    alignItems: 'flex-start',
    paddingHorizontal: 6,
    paddingTop: 2,
  },

  input: {
    flex: 1,
    minHeight: LINE_HEIGHT,
    color: Colors.textSecondary,
    fontSize: 16.5,
    fontWeight: '400',
    lineHeight: LINE_HEIGHT,
    padding: 0,
    margin: 0,
    textAlignVertical: 'center',
  },

  expandedInput: {
    width: '100%',
    height: '100%',
    fontSize: 16.5,
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
    paddingHorizontal: 4,
    paddingTop: 4,
    paddingBottom: 4,
  },

  plusButton: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },

  actionButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
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
    shadowRadius: 12,
    elevation: 8,
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
    shadowRadius: 10,
    elevation: 8,
  },

  voiceModeButton: {
    width: 40,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },

  measurementContainer: {
    position: 'absolute',
    left: 58,
    right: 58,
    top: 0,
    opacity: 0,
    pointerEvents: 'none',
  },

  measurementText: {
    fontSize: 16.5,
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
    fontSize: 16.5,
    fontWeight: '400',
    fontStyle: 'italic',
  },
});
