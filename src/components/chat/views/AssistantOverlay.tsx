import { ChatMessage } from '@/components/chat/types';
import {
  ChatInput,
  DictationCornerGlow,
  LiveTalkBar,
  AssistantResponseCard,
} from '@/components/chat/ui';
import { useAssistantStore } from '@/store/assistantStore';
import {
  cancel,
  dismiss,
  openMainApp,
  startListening,
  stopListening,
  submitText,
  playTts,
  pauseTts,
  resumeTts,
} from '@modules/kritha/src';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Platform, Pressable, StyleSheet, View } from 'react-native';
import { useReanimatedKeyboardAnimation } from 'react-native-keyboard-controller';
import Reanimated, { useAnimatedStyle } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export function AssistantOverlay() {
  const insets = useSafeAreaInsets();

  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const transcriptFromStore = useAssistantStore((s) => s.transcript);
  const responseText = useAssistantStore((s) => s.response);
  const error = useAssistantStore((s) => s.error);
  const isTtsSpeaking = useAssistantStore((s) => s.isTtsSpeaking);
  const isTtsPaused = useAssistantStore((s) => s.isTtsPaused);

  const isRecording = canonicalState === 'LISTENING';
  const isProcessing = canonicalState === 'THINKING';
  const isSending = canonicalState === 'GENERATING';

  const assistantRunId = useAssistantStore((s) => s.assistantRunId);

  const keyboard = useReanimatedKeyboardAnimation();

  const animatedBottomStyle = useAnimatedStyle(() => {
    const rawHeight = keyboard.height.value;
    const keyboardHeight = Math.abs(rawHeight);
    const bottomPadding =
      keyboardHeight > 0 ? keyboardHeight : Math.max(insets.bottom, 20);
    return {
      paddingBottom: bottomPadding,
    };
  }, [insets.bottom]);

  const [localDraft, setLocalDraft] = useState('');
  const [isLiveTalk, setIsLiveTalk] = useState(false);
  const isLiveTalkRef = useRef(isLiveTalk);
  useEffect(() => {
    isLiveTalkRef.current = isLiveTalk;
  }, [isLiveTalk]);

  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMsgId);

  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const [responseVisible, setResponseVisible] = useState(false);
  const responseVisibleRef = useRef(false);

  const responseOpacity = useRef(new Animated.Value(0)).current;
  const responseTranslate = useRef(new Animated.Value(25)).current;
  const glowOpacity = useRef(new Animated.Value(0.2)).current;

  const safeSetResponseVisible = useCallback((val: boolean) => {
    if (mountedRef.current) setResponseVisible(val);
  }, []);

  // Clear text when recording ends or new run starts
  const prevIsRecordingRef = useRef(isRecording);
  useEffect(() => {
    const wasRecording = prevIsRecordingRef.current;
    prevIsRecordingRef.current = isRecording;
    if (wasRecording && !isRecording) {
      setLocalDraft('');
      useAssistantStore.getState().setTranscript('');
    }
  }, [isRecording]);

  useEffect(() => {
    if (assistantRunId) {
      setLocalDraft('');
      useAssistantStore.getState().setTranscript('');
      responseVisibleRef.current = false;
      safeSetResponseVisible(false);
      responseOpacity.setValue(0);
      responseTranslate.setValue(25);
    }
  }, [
    assistantRunId,
    responseOpacity,
    responseTranslate,
    safeSetResponseVisible,
  ]);

  const handleClose = useCallback(() => {
    try {
      dismiss();
    } catch (e) {
      console.warn('Failed to dismiss assistant session:', e);
    }
  }, []);

  const handleExpandPress = useCallback(() => {
    try {
      dismiss();
      openMainApp();
    } catch (e) {
      console.warn('Failed to open main app:', e);
    }
  }, []);

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

  useEffect(() => {
    if (responseText || error) {
      showResponse();
    }
  }, [responseText, error, showResponse]);

  const handleSendMessage = useCallback(async () => {
    const text = (isRecording ? transcriptFromStore : localDraft).trim();
    if (!text || isSending || isProcessing) return;

    setLocalDraft('');
    useAssistantStore.getState().setTranscript('');
    try {
      submitText(text, { origin: 'MANUAL_TYPING' });
    } catch (e) {
      console.warn('Failed to submit text:', e);
    }
  }, [localDraft, transcriptFromStore, isRecording, isSending, isProcessing]);

  const handleStopDictation = useCallback(() => {
    try {
      stopListening();
    } catch (e) {
      console.warn('Failed to stop listening:', e);
    }
  }, []);

  const handleDictatePress = useCallback(async () => {
    if (isRecording) {
      handleStopDictation();
      return;
    }

    setLocalDraft('');
    useAssistantStore.getState().setTranscript('');

    try {
      startListening();
    } catch (e) {
      console.warn('Failed to start listening:', e);
    }
  }, [isRecording, handleStopDictation]);

  const handleLiveTalkToggle = useCallback(() => {
    if (isLiveTalkRef.current) {
      setIsLiveTalk(false);
      cancel();
    } else {
      setIsLiveTalk(true);
      startListening();
    }
  }, []);

  const handleLiveTalkPauseResume = useCallback(() => {
    if (isTtsSpeaking || isRecording) {
      cancel();
    } else {
      startListening();
    }
  }, [isRecording, isTtsSpeaking]);

  const handleStopResponse = useCallback(() => {
    cancel();
  }, []);

  const activeResponseMessageId = assistantRunId
    ? `${assistantRunId}_msg`
    : 'latest_response';

  const handleSpeakerPress = useCallback(() => {
    if (isTtsSpeaking) {
      pauseTts();
    } else if (isTtsPaused) {
      resumeTts();
    } else {
      if (responseText) {
        playTts(responseText, { messageId: activeResponseMessageId });
      }
    }
  }, [isTtsSpeaking, isTtsPaused, responseText, activeResponseMessageId]);

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(glowOpacity, {
          toValue: 0.45,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(glowOpacity, {
          toValue: 0.2,
          duration: 1000,
          useNativeDriver: true,
        }),
      ]),
    );

    if (isRecording || isProcessing || isSending) {
      animation.start();
    } else {
      animation.stop();
      glowOpacity.setValue(0.2);
    }

    return () => animation.stop();
  }, [isRecording, isProcessing, isSending, glowOpacity]);

  const latestAssistant = responseText
    ? {
        id: activeResponseMessageId || 'temp',
        role: 'assistant' as const,
        text: responseText,
      }
    : null;

  const currentDraft = isRecording ? transcriptFromStore : localDraft;

  return (
    <View style={styles.root}>
      <Pressable style={styles.backdrop} onPress={handleClose} />

      <DictationCornerGlow active={isRecording} />

      <Reanimated.View style={[styles.bottomContainer, animatedBottomStyle]}>
        <View style={{ width: '100%', paddingHorizontal: 24 }}>
          <AssistantResponseCard
            responseVisible={responseVisible}
            responseOpacity={responseOpacity}
            responseTranslate={responseTranslate}
            latestAssistant={latestAssistant || undefined}
            error={error}
            isTtsSpeaking={isTtsSpeaking}
            isTtsPaused={isTtsPaused}
            ttsMsgId={currentTtsMsgId}
            onSpeakerPress={handleSpeakerPress}
            onExpandPress={handleExpandPress}
          />
        </View>

        {isLiveTalk ? (
          <LiveTalkBar
            isRecording={isRecording}
            isSpeaking={isTtsSpeaking}
            isPaused={isTtsPaused}
            onPauseResumePress={handleLiveTalkPauseResume}
            onEndPress={handleLiveTalkToggle}
          />
        ) : (
          <ChatInput
            draft={currentDraft}
            setDraft={setLocalDraft}
            isSending={isSending}
            isRecording={isRecording}
            isProcessing={isProcessing}
            isLiveTalk={isLiveTalk}
            onSendMessage={handleSendMessage}
            onDictatePress={handleDictatePress}
            onLiveTalkPress={handleLiveTalkToggle}
            onStopDictation={handleStopDictation}
            onStopResponse={handleStopResponse}
          />
        )}
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
    paddingHorizontal: 0,
    width: '100%',
    alignItems: 'center',
  },
});
