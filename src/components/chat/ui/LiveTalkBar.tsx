import Colors from '@/theme';
import { Pause, Play, Tv, Video, X } from 'lucide-react-native';
import { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import Svg, { Defs, LinearGradient as SvgGradient, Rect, Stop } from 'react-native-svg';

export interface LiveTalkBarProps {
  isRecording?: boolean;
  isSpeaking?: boolean;
  isPaused?: boolean;
  onPauseResumePress: () => void;
  onEndPress: () => void;
  onVideoPress?: () => void;
  onScreenSharePress?: () => void;
}

export function LiveTalkBar({
  isRecording,
  isSpeaking,
  isPaused,
  onPauseResumePress,
  onEndPress,
  onVideoPress,
  onScreenSharePress,
}: LiveTalkBarProps) {
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
    if (isRecording || isSpeaking) {
      animation.start();
    } else {
      animation.stop();
      pulseAnim.setValue(0.2);
    }
    return () => animation.stop();
  }, [isRecording, isSpeaking, pulseAnim]);

  const getStatusText = () => {
    if (isPaused) return 'Paused';
    if (isRecording) return 'Listening...';
    if (isSpeaking) return 'Speaking...';
    return 'Live';
  };

  return (
    <View style={styles.container}>
      <Animated.View style={[styles.fluidGlow, { opacity: pulseAnim }]} pointerEvents="none">
        <Svg height="68" width="100%">
          <Defs>
            <SvgGradient id="liveMeshGlow" x1="0" y1="1" x2="1" y2="0">
              <Stop offset="0%" stopColor={Colors.accentCyan} stopOpacity="0.25" />
              <Stop offset="50%" stopColor={Colors.accentBlue} stopOpacity="0.15" />
              <Stop offset="100%" stopColor={Colors.accentCyanDim} stopOpacity="0.04" />
            </SvgGradient>
          </Defs>
          <Rect width="100%" height="68" rx="34" fill="url(#liveMeshGlow)" />
        </Svg>
      </Animated.View>

      <View style={styles.contentRow}>
        <View style={styles.leftActions}>
          <TouchableOpacity
            activeOpacity={0.7}
            style={styles.circleBtn}
            onPress={onVideoPress}
          >
            <Video size={20} color="#FFFFFF" />
          </TouchableOpacity>

          <TouchableOpacity
            activeOpacity={0.7}
            style={styles.circleBtn}
            onPress={onScreenSharePress}
          >
            <Tv size={20} color="#FFFFFF" />
          </TouchableOpacity>
        </View>

        <View style={styles.centerStatus}>
          <Text style={styles.statusText}>{getStatusText()}</Text>
        </View>

        <View style={styles.rightActions}>
          <TouchableOpacity
            activeOpacity={0.8}
            style={[styles.circleBtn, styles.actionBtnActive]}
            onPress={onPauseResumePress}
          >
            {isPaused ? (
              <Play size={22} color="#FFFFFF" fill="#FFFFFF" />
            ) : (
              <Pause size={22} color="#FFFFFF" fill="#FFFFFF" />
            )}
          </TouchableOpacity>

          <TouchableOpacity
            activeOpacity={0.8}
            style={[styles.circleBtn, styles.closeBtn]}
            onPress={onEndPress}
          >
            <X size={22} color="#FFFFFF" />
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 64,
    borderRadius: 32,
    backgroundColor: '#16171B',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.14)',
    overflow: 'hidden',
    justifyContent: 'center',
    paddingHorizontal: 10,
    width: '100%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  fluidGlow: {
    ...StyleSheet.absoluteFill,
    borderRadius: 32,
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
    gap: 8,
  },
  rightActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  circleBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  actionBtnActive: {
    backgroundColor: 'rgba(255, 255, 255, 0.18)',
  },
  closeBtn: {
    backgroundColor: 'rgba(255, 255, 255, 0.22)',
  },
  centerStatus: {
    flex: 1,
    alignItems: 'center',
  },
  statusText: {
    color: 'rgba(255, 255, 255, 0.75)',
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
});
