import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import Svg, { Defs, LinearGradient, Stop, Rect } from 'react-native-svg';
import Colors from '@/theme';

interface DictationCornerGlowProps {
  active: boolean;
}

export function DictationCornerGlow({ active }: DictationCornerGlowProps) {
  const opacityAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (active) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(opacityAnim, {
            toValue: 0.45,
            duration: 1100,
            useNativeDriver: true,
          }),
          Animated.timing(opacityAnim, {
            toValue: 0.2,
            duration: 1100,
            useNativeDriver: true,
          }),
        ]),
      ).start();
    } else {
      opacityAnim.stopAnimation();
      Animated.timing(opacityAnim, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true,
      }).start();
    }
  }, [active, opacityAnim]);

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        StyleSheet.absoluteFill,
        {
          opacity: opacityAnim,
          zIndex: 9999,
        },
      ]}
    >
      {/* Top Left Glow */}
      <View style={[styles.corner, styles.topLeft]}>
        <Svg height="100%" width="100%">
          <Defs>
            <LinearGradient id="tlGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <Stop
                offset="0%"
                stopColor={Colors.accentSky}
                stopOpacity="0.45"
              />
              <Stop
                offset="45%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0.18"
              />
              <Stop
                offset="100%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0"
              />
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#tlGrad)" />
        </Svg>
      </View>

      {/* Top Right Glow */}
      <View style={[styles.corner, styles.topRight]}>
        <Svg height="100%" width="100%">
          <Defs>
            <LinearGradient id="trGrad" x1="100%" y1="0%" x2="0%" y2="100%">
              <Stop
                offset="0%"
                stopColor={Colors.accentSky}
                stopOpacity="0.45"
              />
              <Stop
                offset="45%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0.18"
              />
              <Stop
                offset="100%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0"
              />
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#trGrad)" />
        </Svg>
      </View>

      {/* Bottom Left Glow */}
      <View style={[styles.corner, styles.bottomLeft]}>
        <Svg height="100%" width="100%">
          <Defs>
            <LinearGradient id="blGrad" x1="0%" y1="100%" x2="100%" y2="0%">
              <Stop
                offset="0%"
                stopColor={Colors.accentSky}
                stopOpacity="0.45"
              />
              <Stop
                offset="45%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0.18"
              />
              <Stop
                offset="100%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0"
              />
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#blGrad)" />
        </Svg>
      </View>

      {/* Bottom Right Glow */}
      <View style={[styles.corner, styles.bottomRight]}>
        <Svg height="100%" width="100%">
          <Defs>
            <LinearGradient id="brGrad" x1="100%" y1="100%" x2="0%" y2="0%">
              <Stop
                offset="0%"
                stopColor={Colors.accentSky}
                stopOpacity="0.45"
              />
              <Stop
                offset="45%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0.18"
              />
              <Stop
                offset="100%"
                stopColor={Colors.accentCyanBg}
                stopOpacity="0"
              />
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#brGrad)" />
        </Svg>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  corner: {
    position: 'absolute',
    width: 220,
    height: 220,
  },
  topLeft: {
    top: 0,
    left: 0,
  },
  topRight: {
    top: 0,
    right: 0,
  },
  bottomLeft: {
    bottom: 0,
    left: 0,
  },
  bottomRight: {
    bottom: 0,
    right: 0,
  },
});
