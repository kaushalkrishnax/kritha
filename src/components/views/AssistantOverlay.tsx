import { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import Reanimated from 'react-native-reanimated';

import {
  AssistantResponseCard,
  TextComposer,
  DictationCornerGlow,
  LiveTalkBar,
} from '@/components/ui';
import { useAssistantKeyboard, useAssistantSession, useSpeaker } from '@/hooks';
import {
  useAssistantStore,
  useChatStore,
  useIsLiveTalk,
  useIsSttListening,
  useIsTtsModelLoading,
  useIsTtsPaused,
  useIsTtsSpeaking,
} from '@/stores';
import { Colors, Radius } from '@/theme';

export function AssistantOverlay() {
  const response = useAssistantStore((s) => s.response);
  const error = useAssistantStore((s) => s.error);
  const assistantRunId = useAssistantStore((s) => s.assistantRunId);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMessageId);
  const isTtsSpeaking = useIsTtsSpeaking();
  const isTtsPaused = useIsTtsPaused();
  const isTtsModelLoading = useIsTtsModelLoading();
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
    import('@/services/speechRuntime.service').then((m) =>
      m.SpeechCoordinator.handleWakeWordDetected(),
    );
    return () => {
      mountedRef.current = false;
      import('@/services/speechRuntime.service').then((m) =>
        m.SpeechCoordinator.endSession(),
      );
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
    import('@modules/kritha/src')
      .then((m) => m.dismissAssistantOverlay())
      .catch((e) => console.warn('Failed to dismiss assistant session:', e));
  }, []);

  const handleExpandPress = useCallback(() => {
    import('@modules/kritha/src')
      .then((m) => m.openMainApp())
      .catch((e) => console.warn('Failed to open main app:', e));
  }, []);

  const messages = useChatStore((s) => s.messages);
  const latestUserText = [...messages].reverse().find((m) => m.role === 'user')?.text;

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
        {!!latestUserText && (
          <View style={styles.userMessageContainer}>
            <View style={styles.userBubble}>
              <Text style={styles.userBubbleText} numberOfLines={3}>
                {latestUserText}
              </Text>
            </View>
          </View>
        )}
        <View style={styles.responseContainer}>
          <AssistantResponseCard
            responseVisible={responseVisible}
            responseOpacity={responseOpacity}
            responseTranslate={responseTranslate}
            latestAssistant={latestAssistant}
            error={error}
            isTtsSpeaking={isTtsSpeaking}
            isTtsPaused={isTtsPaused}
            isTtsBuffering={isTtsModelLoading}
            ttsMsgId={currentTtsMsgId}
            onSpeakerPress={() => {
              if (response) {
                handleSpeakerPress(activeResponseMessageId, response);
              }
            }}
            onExpandPress={handleExpandPress}
          />
        </View>

        {isLiveTalk ? <LiveTalkBar /> : <TextComposer />}
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
  userMessageContainer: {
    width: '100%',
    paddingHorizontal: 24,
    alignItems: 'flex-end',
    marginBottom: 8,
  },
  userBubble: {
    maxWidth: '80%',
    backgroundColor: Colors.accentBlue,
    borderRadius: Radius.xl,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  userBubbleText: {
    color: Colors.textOnAccent,
    fontSize: 15,
  },
});
