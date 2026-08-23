import { ChatMessage } from '@/components/chat/types';
import { ChatInput, DictationCornerGlow, LiveTalkBar } from '@/components/chat/ui';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Animated,
  Platform,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import { KeyboardAvoidingView } from 'react-native-keyboard-controller';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { dbService } from '@/services/db.service';
import KrithaNativeModule from '../../../../modules/kritha/src/KrithaModule';
import { AssistantResponseCard } from './AssistantResponseCard';

export function AssistantOverlay() {
  const insets = useSafeAreaInsets();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [status, setStatus] = useState<'idle' | 'recording' | 'processing' | 'sending'>('idle');
  const [error, setError] = useState<string | null>(null);

  const [isLiveTalk, setIsLiveTalk] = useState(false);
  const isLiveTalkRef = useRef(isLiveTalk);
  useEffect(() => { isLiveTalkRef.current = isLiveTalk; }, [isLiveTalk]);

  const [ttsState, setTtsState] = useState<{ isSpeaking: boolean; isPaused: boolean; msgId: string | null }>({
    isSpeaking: false,
    isPaused: false,
    msgId: null,
  });

  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    return () => { mountedRef.current = false; };
  }, []);

  const safeSetResponseVisible = useCallback((val: boolean) => {
    if (mountedRef.current) setResponseVisible(val);
  }, []);

  const isRecording = status === 'recording';
  const isProcessing = status === 'processing';
  const isSending = status === 'sending';

  const [responseVisible, setResponseVisible] = useState(false);
  const responseVisibleRef = useRef(false);

  const responseOpacity = useRef(new Animated.Value(0)).current;
  const responseTranslate = useRef(new Animated.Value(25)).current;
  const glowOpacity = useRef(new Animated.Value(0.2)).current;

  const isRecordingRef = useRef(isRecording);
  useEffect(() => {
    isRecordingRef.current = isRecording;
  }, [isRecording]);

  const handleClose = useCallback(() => {
    try {
      KrithaNativeModule.stopAssistantSession();
    } catch (e) {
      console.warn('Failed to stop assistant session:', e);
    }
  }, []);

  const handleExpandPress = useCallback(() => {
    if (messages.length > 0) {
      try {
        const firstUserMsg = messages.find((m) => m.role === 'user');
        const title = firstUserMsg ? firstUserMsg.text.slice(0, 28) : 'Voice Chat';
        const session = dbService.createSession(title);
        messages.forEach((m, idx) => {
          dbService.addMessage({
            id: m.id || `${Date.now()}_${idx}`,
            session_id: session.id,
            role: m.role,
            text: m.text,
            created_at: Date.now() + idx,
          });
        });
      } catch (e) {
        console.warn('Failed to save overlay session to DB:', e);
      }
    }
    try {
      KrithaNativeModule.stopAssistantSession();
      if (KrithaNativeModule.openMainApp) {
        KrithaNativeModule.openMainApp();
      }
    } catch (e) {
      console.warn('Failed to open main app:', e);
    }
  }, [messages]);

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

  const hideResponse = useCallback(() => {
    if (!responseVisibleRef.current) return;
    Animated.parallel([
      Animated.timing(responseOpacity, {
        toValue: 0,
        duration: 130,
        useNativeDriver: true,
      }),
      Animated.timing(responseTranslate, {
        toValue: 20,
        duration: 130,
        useNativeDriver: true,
      }),
    ]).start(() => {
      responseVisibleRef.current = false;
      safeSetResponseVisible(false);
    });
  }, [responseOpacity, responseTranslate, safeSetResponseVisible]);

  useEffect(() => {
    let nativeAssistantMsgId: string | null = null;
    let appendedUserMsgForNative = false;
    let isAutoDictated = false;

    const sub1 = KrithaNativeModule.addListener('onAssistantEvent', (event) => {
      if (!mountedRef.current) return;

      if (event.state === 'listening') {
        setStatus('recording');
        setError(null);
        hideResponse();
        nativeAssistantMsgId = null;
        appendedUserMsgForNative = false;
        isAutoDictated = true;
        setTtsState({ isSpeaking: false, isPaused: false, msgId: null });
        return;
      }

      if (event.state === 'partial') {
        if (isAutoDictated) setStatus('recording');
        if (event.transcript) {
          setDraft(event.transcript);
        }
        return;
      }

      if (event.state === 'processing') {
        setStatus('processing');
        if (event.transcript) {
          setDraft(event.transcript);
        }
        return;
      }

      if (event.state === 'streaming') {
        setStatus('idle');
        setDraft('');
        showResponse();

        if (!appendedUserMsgForNative && event.transcript) {
          appendedUserMsgForNative = true;
          setMessages((prev) => [...prev, { id: `${Date.now()}_user`, role: 'user', text: event.transcript! }]);
        }

        if (event.chunk) {
          if (!nativeAssistantMsgId) {
            nativeAssistantMsgId = `${Date.now()}_native_assistant`;
            setMessages((prev) => [...prev, { id: nativeAssistantMsgId!, role: 'assistant', text: event.chunk! }]);
            setTtsState((prev) => ({ ...prev, msgId: nativeAssistantMsgId }));
          } else {
            setMessages((prev) => prev.map((m) => (m.id === nativeAssistantMsgId ? { ...m, text: m.text + event.chunk } : m)));
          }
        }
        return;
      }

      if (event.state === 'finished') {
        setStatus('idle');
        setDraft('');
        showResponse();

        if (!appendedUserMsgForNative && event.transcript) {
          appendedUserMsgForNative = true;
          setMessages((prev) => [...prev, { id: `${Date.now()}_user`, role: 'user', text: event.transcript! }]);
        }

        if (event.response) {
          if (!nativeAssistantMsgId) {
            nativeAssistantMsgId = `${Date.now()}_native_assistant`;
            setMessages((prev) => [...prev, { id: nativeAssistantMsgId!, role: 'assistant', text: event.response! }]);
          } else {
            setMessages((prev) => prev.map((m) => (m.id === nativeAssistantMsgId ? { ...m, text: event.response! } : m)));
          }
        }

        const activeId = nativeAssistantMsgId;
        setTtsState((prev) => ({ ...prev, msgId: activeId || prev.msgId }));
        
        nativeAssistantMsgId = null;
        appendedUserMsgForNative = false;
        isAutoDictated = false;
        return;
      }

      if (event.state === 'tts_start') {
        setTtsState((prev) => ({
          ...prev,
          isSpeaking: true,
          isPaused: false,
          msgId: prev.msgId || (messages.length > 0 ? messages[messages.length - 1].id : null),
        }));
        return;
      }

      if (event.state === 'tts_pause') {
        setTtsState((prev) => ({ ...prev, isSpeaking: false, isPaused: true }));
        return;
      }

      if (event.state === 'tts_done') {
        setTtsState((prev) => ({ ...prev, isSpeaking: false, isPaused: false }));
        if (isLiveTalkRef.current && !isRecordingRef.current) {
          handleDictatePress();
        }
        return;
      }

      if (event.state === 'error') {
        setStatus('idle');
        setError(event.error || 'Something went wrong.');
        showResponse();
        nativeAssistantMsgId = null;
        appendedUserMsgForNative = false;
        isAutoDictated = false;
      }
    });

    const sub2 = KrithaNativeModule.addListener('onDictationPartial', (event) => {
      if (event.text && isRecordingRef.current) {
        setDraft(event.text);
      }
    });

    const sub3 = KrithaNativeModule.addListener('onWakeWordDetected', () => {
      if (!mountedRef.current) return;
      try { KrithaNativeModule.stopTts(); } catch { }
      try { KrithaNativeModule.stopGeneration(); } catch { }
      setTtsState({ isSpeaking: false, isPaused: false, msgId: null });
      try { KrithaNativeModule.triggerAssistantSession(); } catch { }
    });

    return () => {
      sub1.remove();
      sub2.remove();
      sub3.remove();
    };
  }, [hideResponse, showResponse]);

  const [isTyped, setIsTyped] = useState(true);

  const handleSendMessage = useCallback(async () => {
    const text = draft.trim();
    if (!text || isSending || isProcessing) return;

    const autoTts = !isTyped;
    
    setDraft('');
    setStatus('sending');
    
    try {
      KrithaNativeModule.sendToAssistant(text, autoTts);
    } catch (e) {
      console.warn("Failed to send message to assistant", e);
      setStatus('idle');
    }
  }, [draft, isSending, isProcessing, isTyped]);

  const handleStopDictation = useCallback(() => {
    try {
      KrithaNativeModule.stopDictation();
    } catch (e) {
      console.warn('Failed to stop dictation:', e);
    }
    setStatus('idle');
  }, []);

  const handleDictatePress = useCallback(async () => {
    if (isRecording) {
      handleStopDictation();
      return;
    }

    try { KrithaNativeModule.stopTts(); } catch { }
    try { KrithaNativeModule.stopGeneration(); } catch { }
    setTtsState({ isSpeaking: false, isPaused: false, msgId: null });

    setIsTyped(false); // Mark as dictated
    setStatus('recording');
    setDraft('');
    
    try {
      const userText = await KrithaNativeModule.startDictation();
      setStatus('idle');
      if (userText && userText.trim().length > 0) {
        setDraft(userText.trim());
      }
    } catch {
      setStatus('idle');
    }
  }, [isRecording, handleStopDictation]);

  const handleLiveTalkToggle = useCallback(() => {
    if (isLiveTalkRef.current) {
      setIsLiveTalk(false);
      try { KrithaNativeModule.stopDictation(); } catch { }
      try { KrithaNativeModule.stopTts(); } catch { }
      setStatus('idle');
    } else {
      setIsLiveTalk(true);
      try { KrithaNativeModule.stopTts(); } catch { }
      handleDictatePress();
    }
  }, [handleDictatePress]);

  const handleLiveTalkPauseResume = useCallback(() => {
    if (ttsState.isSpeaking || isRecording) {
      try { KrithaNativeModule.stopTts(); } catch { }
      try { KrithaNativeModule.stopDictation(); } catch { }
      setTtsState({ isSpeaking: false, isPaused: true, msgId: null });
      setStatus('idle');
    } else {
      setTtsState({ isSpeaking: false, isPaused: false, msgId: null });
      handleDictatePress();
    }
  }, [handleDictatePress, isRecording, ttsState.isSpeaking]);

  const handleStopResponse = useCallback(() => {
    setStatus('idle');
    try {
      KrithaNativeModule.stopGeneration();
    } catch (e) {}
  }, []);

  const handleSpeakerPress = useCallback((msgId: string) => {
    try {
      if (ttsState.isSpeaking && ttsState.msgId === msgId) {
        KrithaNativeModule.pauseTts();
      } else if (ttsState.isPaused && ttsState.msgId === msgId) {
        KrithaNativeModule.resumeTts();
      } else {
        KrithaNativeModule.replayTts();
      }
    } catch (e) {}
  }, [ttsState]);

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

  const latestAssistant = messages
    .slice()
    .reverse()
    .find((m) => m.role === 'assistant' && m.text.trim());

  return (
    <View style={styles.root}>
      <DictationCornerGlow active={isRecording} />
      <Pressable style={styles.backdrop} onPress={handleClose} />

      <Animated.View
        style={[
          styles.bottomGlow,
          {
            opacity: glowOpacity,
          },
        ]}
        pointerEvents="none"
      />

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.overlay}
        pointerEvents="box-none"
      >
        <View
          style={[
            styles.bottomArea,
            { paddingBottom: Math.max(insets.bottom, 2) },
          ]}
          pointerEvents="box-none"
        >
          <AssistantResponseCard
            responseVisible={responseVisible}
            responseOpacity={responseOpacity}
            responseTranslate={responseTranslate}
            latestAssistant={latestAssistant}
            error={error}
            isTtsSpeaking={ttsState.isSpeaking}
            isTtsPaused={ttsState.isPaused}
            ttsMsgId={ttsState.msgId}
            onSpeakerPress={(id) => handleSpeakerPress(id)}
            onExpandPress={handleExpandPress}
            hideActions={isLiveTalk}
          />

          <View style={styles.composerWrapper}>
            {isLiveTalk ? (
              <LiveTalkBar
                isRecording={isRecording}
                isSpeaking={ttsState.isSpeaking}
                isPaused={ttsState.isPaused}
                onPauseResumePress={handleLiveTalkPauseResume}
                onEndPress={handleLiveTalkToggle}
              />
            ) : (
              <ChatInput
                draft={draft}
                setDraft={(val) => {
                  setDraft(val);
                  if (val.trim() === '') setIsTyped(true);
                }}
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
          </View>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'transparent',
  },
  backdrop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(10, 10, 15, 0.45)',
  },
  overlay: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  bottomArea: {
    width: '100%',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 16,
  },
  composerWrapper: {
    width: '100%',
    maxWidth: 600,
  },
  bottomGlow: {
    position: 'absolute',
    bottom: -100,
    left: -100,
    right: -100,
    height: 400,
    backgroundColor: 'var(--kritha-color-primary)',
    opacity: 0.15,
    borderRadius: 200,
    transform: [{ scaleX: 1.5 }, { scaleY: 0.5 }],
  },
});
