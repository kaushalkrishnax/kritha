import React from 'react';
import { View, StyleSheet } from 'react-native';
import Svg, {
  Defs,
  Rect,
  Stop,
  LinearGradient as SvgGradient,
} from 'react-native-svg';
import ChatMessages from '@/components/chat/ui/ChatMessages';
import Colors from '@/theme';

export function ChatScreenBody() {
  return (
    <View style={styles.chatArea}>
      <Svg height="100%" width="100%" style={StyleSheet.absoluteFill}>
        <Defs>
          <SvgGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <Stop offset="0%" stopColor={Colors.bgDeepest} stopOpacity="1" />
            <Stop offset="40%" stopColor="#070A0F" stopOpacity="1" />
            <Stop offset="100%" stopColor="#030508" stopOpacity="1" />
          </SvgGradient>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill="url(#bgGrad)" />
      </Svg>
      <ChatMessages />
    </View>
  );
}

const styles = StyleSheet.create({
  chatArea: { flex: 1 },
});
