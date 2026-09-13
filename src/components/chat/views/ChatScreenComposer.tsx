import React from 'react';
import { StyleSheet } from 'react-native';
import Animated from 'react-native-reanimated';
import { ChatInput } from '@/components/chat/ui/ChatInput';
import { DictationCornerGlow } from '@/components/chat/ui/DictationCornerGlow';
import { LiveTalkBar } from '@/components/chat/ui/LiveTalkBar';
import { useAssistantKeyboard } from '@/hooks';
import { useChatInputStore, useModelStore } from '@/store';

export function ChatScreenComposer() {
  const animatedBottomStyle = useAssistantKeyboard();
  const mode = useChatInputStore((s) => s.mode);
  const selectedModelId = useModelStore((s) => s.selectedModelId);

  return (
    <>
      <DictationCornerGlow active={mode === 'DICTATION'} />
      <Animated.View style={[styles.floatingInputWrapper, animatedBottomStyle]}>
        {mode === 'LIVE_TALK' ? (
          <LiveTalkBar />
        ) : (
          <ChatInput variant="chat" modelId={selectedModelId} />
        )}
      </Animated.View>
    </>
  );
}

const styles = StyleSheet.create({
  floatingInputWrapper: { width: '100%', alignItems: 'center', paddingTop: 8 },
});
