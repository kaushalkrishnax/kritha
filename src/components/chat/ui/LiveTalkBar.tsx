import Colors from '@/theme';
import { Mic, MicOff, Tv, Video, X } from 'lucide-react-native';
import { useEffect, useRef } from 'react';
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import Svg, {
  Defs,
  LinearGradient as SvgGradient,
  Rect,
  Stop,
} from 'react-native-svg';

import { useAssistantStore } from '@/store/assistantStore';
import { useAssistantActions } from '@/hooks/use-assistant-interaction';

export function LiveTalkBar() {
  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const isTtsSpeaking = useAssistantStore((s) => s.isTtsSpeaking);
  const isTtsPaused = useAssistantStore((s) => s.isTtsPaused);
  const isLiveTalkHeld = useAssistantStore((s) => s.isLiveTalkHeld);

  const isRecording = canonicalState === 'LISTENING';
  const { handleLiveTalkToggle, handleLiveTalkMicToggle } =
    useAssistantActions();
  const pulseAnim = useRef(new Animated.Value(0.2)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 0.55,
          duration: 1400,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 0.2,
          duration: 1400,
          useNativeDriver: true,
        }),
      ]),
    );

    if (isRecording || isTtsSpeaking) {
      animation.start();
    } else {
      animation.stop();
      pulseAnim.setValue(0.2);
    }

    return () => animation.stop();
  }, [isRecording, isTtsSpeaking, pulseAnim]);

  const getStatusText = () => {
    if (isLiveTalkHeld) return 'Paused';
    if (isRecording) return 'Listening...';
    if (isTtsSpeaking) return 'Speaking...';
    return 'Live';
  };

  return (
    <View style={styles.outerContainer}>
      <View style={styles.container}>
        <Animated.View
          style={[styles.fluidGlow, { opacity: pulseAnim }]}
          pointerEvents="none"
        >
          <Svg height="58" width="100%">
            <Defs>
              <SvgGradient id="liveMeshGlow" x1="0" y1="1" x2="1" y2="0">
                <Stop
                  offset="0%"
                  stopColor={Colors.accentCyan}
                  stopOpacity="0.25"
                />
                <Stop
                  offset="50%"
                  stopColor={Colors.accentBlue}
                  stopOpacity="0.15"
                />
                <Stop
                  offset="100%"
                  stopColor={Colors.accentCyanDim}
                  stopOpacity="0.04"
                />
              </SvgGradient>
            </Defs>
            <Rect width="100%" height="58" rx="28" fill="url(#liveMeshGlow)" />
          </Svg>
        </Animated.View>

        <View style={styles.contentRow}>
          <View style={styles.leftActions}>
            <TouchableOpacity
              activeOpacity={0.7}
              style={styles.circleBtn}
              onPress={() => {}}
            >
              <Video size={18} color={Colors.textOnAccent} />
            </TouchableOpacity>

            <TouchableOpacity
              activeOpacity={0.7}
              style={styles.circleBtn}
              onPress={() => {}}
            >
              <Tv size={18} color={Colors.textOnAccent} />
            </TouchableOpacity>
          </View>

          <View style={styles.centerStatus}>
            <Text style={styles.statusText}>{getStatusText()}</Text>
          </View>

          <View style={styles.rightActions}>
            <TouchableOpacity
              activeOpacity={0.8}
              onPress={handleLiveTalkMicToggle}
              style={[
                styles.circleBtn,
                isRecording ? styles.micActiveBtn : styles.micIdleBtn,
              ]}
            >
              {isRecording ? (
                <MicOff size={18} color={Colors.textOnAccent} />
              ) : (
                <Mic size={18} color={Colors.textOnAccent} />
              )}
            </TouchableOpacity>

            <TouchableOpacity
              activeOpacity={0.8}
              style={[styles.circleBtn, styles.closeBtn]}
              onPress={handleLiveTalkToggle}
            >
              <X size={18} color={Colors.textOnAccent} />
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerContainer: {
    width: '100%',
    paddingHorizontal: 20,
    paddingTop: 6,
    paddingBottom: 12,
    alignItems: 'center',
    backgroundColor: 'transparent',
  },
  container: {
    height: 58,
    borderRadius: 28,
    backgroundColor: Colors.bgCard,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    overflow: 'hidden',
    justifyContent: 'center',
    paddingHorizontal: 8,
    width: '100%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.35,
    shadowRadius: 10,
    elevation: 8,
  },
  fluidGlow: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    borderRadius: 28,
    overflow: 'hidden',
  },
  contentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    zIndex: 2,
  },
  leftActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  rightActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  circleBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: Colors.borderFaint,
    justifyContent: 'center',
    alignItems: 'center',
  },
  micIdleBtn: {
    backgroundColor: Colors.borderSubtle,
  },
  // Brand theme blue when the mic is active (LISTENING).
  micActiveBtn: {
    backgroundColor: Colors.accentBlue,
    shadowColor: Colors.accentBlue,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.6,
    shadowRadius: 8,
    elevation: 5,
  },
  closeBtn: {
    backgroundColor: Colors.borderSubtle,
  },
  centerStatus: {
    flex: 1,
    alignItems: 'center',
  },
  statusText: {
    color: Colors.textSecondary,
    fontSize: 13.5,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
});
