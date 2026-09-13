import { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, View } from 'react-native';
import Reanimated from 'react-native-reanimated';
import {
  DictationCornerGlow,
  AssistantResponseCard,
  ChatInput,
  LiveTalkBar,
} from '@/components/chat/ui';
import { useAssistantKeyboard, useSpeaker, useAssistantSession } from '@/hooks';
import {
  useAssistantStore,
  useIsSttListening,
  useIsTtsSpeaking,
  useIsTtsPaused,
  useIsLiveTalk,
} from '@/stores';

export function AssistantOverlay() {
  const response = useAssistantStore((s) => s.response);
  const error = useAssistantStore((s) => s.error);
  const assistantRunId = useAssistantStore((s) => s.assistantRunId);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMessageId);
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();
  const isLiveTalk = useIsLiveTalk();

  const isRecording = useIsSttListening();
  const { handleSpeakerPress } = useSpeaker();
  const { clearInputAndTranscript } = useAssistantSession();
  const animatedBottomStyle = useAssistantKeyboard();
  const mountedRef = useRef(true);

  const [responseVisible, setResponseVisible] = useState(false);
  const responseVisibleRef = useRef(false);
  const [responseOpacity] = useState(() => new Animated.Value(0));
  const [responseTranslate] = useState(() => new Animated.Value(25));

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const safeSetResponseVisible = useCallback((value: boolean) => {
    if (mountedRef.current) {
      setResponseVisible(value);
    }
  }, []);

  // Reset UI when a new run begins
  useEffect(() => {
    if (!assistantRunId) return;

    clearInputAndTranscript();

    responseVisibleRef.current = false;
    safeSetResponseVisible(false);
    responseOpacity.setValue(0);
    responseTranslate.setValue(25);
  }, [
    assistantRunId,
    clearInputAndTranscript,
    responseOpacity,
    responseTranslate,
    safeSetResponseVisible,
  ]);

  const showResponse = useCallback(() => {
    if (responseVisibleRef.current) return;

    responseVisibleRef.current = true;
    safeSetResponseVisible(true);
    responseOpacity.setValue(0);
    responseTranslate.setValue(22);

    Animated.parallel([
      Animated.timing(responseOpacity, {
        toValue: 1,
        duration: 180,
        useNativeDriver: true,
      }),
      Animated.spring(responseTranslate, {
        toValue: 0,
        tension: 80,
        friction: 12,
        useNativeDriver: true,
      }),
    ]).start();
  }, [responseOpacity, responseTranslate, safeSetResponseVisible]);

  // Reveal the card when text or errors start generating
  useEffect(() => {
    if (response || error) {
      showResponse();
    }
  }, [response, error, showResponse]);

  const handleClose = useCallback(() => {
    try {
      // ::TODO:: Close the Natively opened Overlay
      // AssistantBridge.dismissOverlay();
    } catch (e) {
      console.warn('Failed to dismiss assistant session:', e);
    }
  }, []);

  const handleExpandPress = useCallback(() => {
    try {
      // ::TODO:: Route to the main app with the current session context
      // AssistantBridge.dismissOverlay();
      // AssistantBridge.openMainApp();
    } catch (e) {
      console.warn('Failed to open main app:', e);
    }
  }, []);

  const activeResponseMessageId = assistantRunId
    ? `${assistantRunId}_msg`
    : 'latest_response';

  const latestAssistant = response
    ? {
        id: activeResponseMessageId,
        role: 'assistant' as const,
        text: response,
      }
    : undefined;

  return (
    <View style={styles.root}>
      <Pressable style={styles.backdrop} onPress={handleClose} />
      <DictationCornerGlow active={isRecording} />
      <Reanimated.View style={[styles.bottomContainer, animatedBottomStyle]}>
        <View style={styles.responseContainer}>
          <AssistantResponseCard
            responseVisible={responseVisible}
            responseOpacity={responseOpacity}
            responseTranslate={responseTranslate}
            latestAssistant={latestAssistant}
            error={error}
            isTtsSpeaking={isTtsSpeaking}
            isTtsPaused={isTtsPaused}
            ttsMsgId={currentTtsMsgId}
            onSpeakerPress={() => {
              if (response) {
                handleSpeakerPress(activeResponseMessageId, response);
              }
            }}
            onExpandPress={handleExpandPress}
          />
        </View>

        {isLiveTalk ? <LiveTalkBar /> : <ChatInput />}
      </Reanimated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: 'transparent',
    justifyContent: 'flex-end',
  },
  backdrop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
  },
  bottomContainer: {
    width: '100%',
    alignItems: 'center',
  },
  responseContainer: {
    width: '100%',
    paddingHorizontal: 24,
  },
});
