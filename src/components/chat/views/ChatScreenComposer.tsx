import React from 'react';
import { StyleSheet } from 'react-native';
import Animated from 'react-native-reanimated';
import { ChatInput, DictationCornerGlow, LiveTalkBar } from '@/components/chat/ui';
import { ChatMode } from '@/constants';
import { useAssistantKeyboard } from '@/hooks';
import { useAssistantStore, useModelStore } from '@/stores';

export function ChatScreenComposer() {
  const animatedBottomStyle = useAssistantKeyboard();
  const chatMode = useAssistantStore((s) => s.chatMode);
  const selectedModelId = useModelStore((s) => s.selectedModelId);

  return (
    <>
      <DictationCornerGlow active={chatMode === ChatMode.DICTATION} />
      <Animated.View style={[styles.floatingInputWrapper, animatedBottomStyle]}>
        {chatMode === ChatMode.LIVE_TALK ? (
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
