import React, { useEffect, useRef } from 'react';
import { Animated, Dimensions, StyleSheet, View } from 'react-native';
import Svg, { Defs, LinearGradient, Stop, Rect } from 'react-native-svg';
import Colors from '@/theme';

interface DictationCornerGlowProps {
  active: boolean;
}

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');
const EDGE_SIZE = 220;

export function DictationCornerGlow({ active }: DictationCornerGlowProps) {
  const visibility = useRef(new Animated.Value(0)).current;
  const breathe = useRef(new Animated.Value(0)).current;
  const breatheSlow = useRef(new Animated.Value(0)).current;

  const breatheLoop = useRef<Animated.CompositeAnimation | null>(null);
  const breatheSlowLoop = useRef<Animated.CompositeAnimation | null>(null);

  useEffect(() => {
    if (active) {
      Animated.timing(visibility, {
        toValue: 1,
        duration: 350,
        useNativeDriver: true,
      }).start();

      breatheLoop.current = Animated.loop(
        Animated.sequence([
          Animated.timing(breathe, {
            toValue: 1,
            duration: 1600,
            useNativeDriver: true,
          }),
          Animated.timing(breathe, {
            toValue: 0,
            duration: 1600,
            useNativeDriver: true,
          }),
        ]),
      );
      breatheSlowLoop.current = Animated.loop(
        Animated.sequence([
          Animated.timing(breatheSlow, {
            toValue: 1,
            duration: 2600,
            useNativeDriver: true,
          }),
          Animated.timing(breatheSlow, {
            toValue: 0,
            duration: 2600,
            useNativeDriver: true,
          }),
        ]),
      );
      breatheLoop.current.start();
      breatheSlowLoop.current.start();
    } else {
      breatheLoop.current?.stop();
      breatheSlowLoop.current?.stop();
      Animated.timing(visibility, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }

    return () => {
      breatheLoop.current?.stop();
      breatheSlowLoop.current?.stop();
    };
  }, [active, visibility, breathe, breatheSlow]);

  const opacity = breathe.interpolate({
    inputRange: [0, 1],
    outputRange: [0.1, 0.2],
  });

  const opacitySlow = breatheSlow.interpolate({
    inputRange: [0, 1],
    outputRange: [0.06, 0.14],
  });

  const scale = breathe.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.03],
  });

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        StyleSheet.absoluteFill,
        {
          opacity: visibility,
          zIndex: 9999,
        },
      ]}
    >
      <Animated.View
        style={[
          StyleSheet.absoluteFill,
          { opacity: opacitySlow, transform: [{ scale }] },
        ]}
      >
        <Edge side="top" />
        <Edge side="bottom" />
        <Edge side="left" />
        <Edge side="right" />
      </Animated.View>

      <Animated.View style={[StyleSheet.absoluteFill, { opacity }]}>
        <Edge side="top" thin />
        <Edge side="bottom" thin />
        <Edge side="left" thin />
        <Edge side="right" thin />
      </Animated.View>
    </Animated.View>
  );
}

function Edge({
  side,
  thin,
}: {
  side: 'top' | 'bottom' | 'left' | 'right';
  thin?: boolean;
}) {
  const size = thin ? EDGE_SIZE * 0.6 : EDGE_SIZE;
  const isVertical = side === 'left' || side === 'right';
  const gradId = `edgeGrad-${side}-${thin ? 'thin' : 'wide'}`;

  const positionStyle = (() => {
    switch (side) {
      case 'top':
        return { top: 0, left: 0, right: 0, height: size };
      case 'bottom':
        return { bottom: 0, left: 0, right: 0, height: size };
      case 'left':
        return { top: 0, bottom: 0, left: 0, width: size };
      case 'right':
        return { top: 0, bottom: 0, right: 0, width: size };
    }
  })();

  const x1 = side === 'right' ? '100%' : '0%';
  const x2 = side === 'right' ? '0%' : '100%';
  const y1 = side === 'bottom' ? '100%' : '0%';
  const y2 = side === 'bottom' ? '0%' : '100%';

  return (
    <View style={[styles.edgeBase, positionStyle]}>
      <Svg
        width={isVertical ? size : SCREEN_W}
        height={isVertical ? SCREEN_H : size}
      >
        <Defs>
          <LinearGradient
            id={gradId}
            x1={isVertical ? x1 : '0%'}
            y1={isVertical ? '0%' : y1}
            x2={isVertical ? x2 : '0%'}
            y2={isVertical ? '0%' : y2}
          >
            <Stop offset="0%" stopColor={Colors.accentSky} stopOpacity="0.35" />
            <Stop
              offset="25%"
              stopColor={Colors.accentCyanBg}
              stopOpacity="0.16"
            />
            <Stop
              offset="55%"
              stopColor={Colors.accentCyanBg}
              stopOpacity="0.06"
            />
            <Stop offset="100%" stopColor={Colors.accentCyanBg} stopOpacity="0" />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill={`url(#${gradId})`} />
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  edgeBase: {
    position: 'absolute',
  },
});