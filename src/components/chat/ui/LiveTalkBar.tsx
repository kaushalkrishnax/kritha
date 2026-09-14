import { Mic, MicOff, ScreenShare, Video, X } from 'lucide-react-native';
import { useEffect, useState } from 'react';
import { Animated, StyleSheet, TouchableOpacity, View } from 'react-native';
import Svg, {
  Defs,
  Rect,
  Stop,
  LinearGradient as SvgGradient,
} from 'react-native-svg';
import { LiveTalkPhase } from '@/constants';
import * as assistantRuntime from '@/services/assistantRuntime.service';
import { useAssistantStore } from '@/stores';
import { Colors, IconSizes, Radius } from '@/theme';

export function LiveTalkBar() {
  const liveTalkPhase = useAssistantStore((s) => s.liveTalkPhase);

  const getActiveState = () => {
    if (liveTalkPhase === LiveTalkPhase.LISTENING) return 'Listening';
    if (liveTalkPhase === LiveTalkPhase.SPEAKING) return 'Speaking';
    return 'Paused';
  };

  const activeState = getActiveState();
  const isRecording = activeState === 'Listening';
  const isSpeaking = activeState === 'Speaking';

  const [pulseAnim] = useState(() => new Animated.Value(0.4));

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 0.95,
          duration: 1200,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 0.35,
          duration: 1200,
          useNativeDriver: true,
        }),
      ]),
    );

    if (isRecording || isSpeaking) {
      animation.start();
    } else {
      animation.stop();
      pulseAnim.setValue(0.35);
    }

    return () => animation.stop();
  }, [isRecording, isSpeaking, pulseAnim]);

  return (
    <View style={styles.outerContainer}>
      <View style={styles.barRow}>
        {/* Button 1: Video / Camera */}
        <TouchableOpacity
          activeOpacity={0.75}
          style={styles.circleBtn}
          onPress={() => {}}
        >
          <Video size={IconSizes.lg} color={Colors.textPrimary} />
        </TouchableOpacity>

        {/* Button 2: Screen share */}
        <TouchableOpacity
          activeOpacity={0.75}
          style={styles.circleBtn}
          onPress={() => {}}
        >
          <ScreenShare size={IconSizes.lg} color={Colors.textPrimary} />
        </TouchableOpacity>

        {/* Center: Glowing Visualizer Pill */}
        <View style={styles.glowPill}>
          <Animated.View
            style={[styles.glowSvgWrap, { opacity: pulseAnim }]}
            pointerEvents="none"
          >
            <Svg height="50" width="100%">
              <Defs>
                <SvgGradient id="liveMeshGlow" x1="0" y1="1" x2="0" y2="0">
                  <Stop
                    offset="0%"
                    stopColor={Colors.accentLightBlue}
                    stopOpacity="0.95"
                  />
                  <Stop
                    offset="40%"
                    stopColor={Colors.accentBlue}
                    stopOpacity="0.6"
                  />
                  <Stop
                    offset="75%"
                    stopColor={Colors.accentCyanBg}
                    stopOpacity="0.2"
                  />
                  <Stop
                    offset="100%"
                    stopColor={Colors.bgSurface}
                    stopOpacity="0"
                  />
                </SvgGradient>
              </Defs>
              <Rect
                width="100%"
                height="50"
                rx={25}
                fill="url(#liveMeshGlow)"
              />
            </Svg>
          </Animated.View>
        </View>

        {/* Button 3: Mic toggle */}
        <TouchableOpacity
          activeOpacity={0.75}
          onPress={
            activeState === 'Paused'
              ? assistantRuntime.resumeLiveTalk
              : assistantRuntime.pauseLiveTalk
          }
          style={styles.circleBtn}
        >
          {isRecording ? (
            <Mic size={IconSizes.lg} color={Colors.textPrimary} />
          ) : (
            <MicOff size={IconSizes.lg} color={Colors.textMuted} />
          )}
        </TouchableOpacity>

        {/* Button 4: Close (X) */}
        <TouchableOpacity
          activeOpacity={0.75}
          style={styles.circleBtn}
          onPress={assistantRuntime.stopLiveTalk}
        >
          <X size={IconSizes.lg} color={Colors.textPrimary} />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerContainer: {
    width: '100%',
    paddingHorizontal: 16,
    paddingTop: 6,
    paddingBottom: 12,
    alignItems: 'center',
    backgroundColor: 'transparent',
  },
  barRow: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  circleBtn: {
    width: 48,
    height: 48,
    borderRadius: Radius.xl,
    backgroundColor: Colors.bgTertiary,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
  },
  glowPill: {
    flex: 1,
    height: 50,
    maxWidth: 120,
    borderRadius: Radius.xl,
    backgroundColor: Colors.bgDeepest,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.borderFaint,
  },
  glowSvgWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    borderRadius: Radius.xl,
    overflow: 'hidden',
  },
});
