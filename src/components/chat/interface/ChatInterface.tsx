import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Square } from 'lucide-react-native';
import { AppState, AppStateStatus, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import Animated, { useAnimatedKeyboard, useAnimatedStyle } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient as SvgGradient, Stop, Rect } from 'react-native-svg';
import Colors from '@/theme';

import { dbService } from '@/services/db.service';
import KrithaNativeModule from '../../../../modules/kritha/src/KrithaModule';

import { useChatState } from '@/hooks/use-chat-state';
import { useModelLoader } from '@/hooks/use-model-loader';
import { useNativeEvents } from '@/hooks/use-native-events';
import { useWakeWordBootstrap } from '@/hooks/use-wakeword-bootstrap';
import { wakeWordService } from '@/services/wakeword.service';

import { ChatHeader, ChatInput, ChatMessages, ChatSidebar, DictationCornerGlow, LiveTalkBar } from '@/components/chat/ui';
import { ModelSelectModal } from './ModelSelectModal';
import { ChatMessage, ModelRecord } from '@/components/chat/types';

export function ChatInterface() {
  useWakeWordBootstrap();

  const { state, dispatch } = useChatState();
  const {
    sessionId,
    sessions,
    messages,
    isSending,
    error,
    assistantBanner,
    models,
    selectedModelId,
    downloadState,
    isRecording,
    draft,
    isWakeWordOn,
    sidebarOpen,
    ttsState,
  } = state;

  const [isModelDropdownOpen, setModelDropdownOpen] = useState(false);
  const [downloadModalModel, setDownloadModalModel] = useState<ModelRecord | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isLiveTalk, setIsLiveTalk] = useState(false);

  const isLiveTalkRef = useRef(isLiveTalk);
  useEffect(() => { isLiveTalkRef.current = isLiveTalk; }, [isLiveTalk]);

  const messagesRef = useRef(messages);
  useEffect(() => { messagesRef.current = messages; }, [messages]);

  const sessionIdRef = useRef(sessionId);
  useEffect(() => { sessionIdRef.current = sessionId; }, [sessionId]);

  const isSendingRef = useRef(isSending);
  useEffect(() => { isSendingRef.current = isSending; }, [isSending]);

  const isRecordingRef = useRef(isRecording);
  useEffect(() => { isRecordingRef.current = isRecording; }, [isRecording]);

  useEffect(() => {
    const reloadSessions = () => {
      const loadedSessions = dbService.getSessions();
      dispatch({ type: 'SET_SESSIONS', sessions: loadedSessions });
      if (loadedSessions.length > 0) {
        dispatch({ type: 'SET_SESSION_ID', sessionId: loadedSessions[0].id });
        dispatch({
          type: 'SET_MESSAGES',
          messages: dbService.getMessages(loadedSessions[0].id),
        });
      } else {
        const newSession = dbService.createSession('New Chat');
        dispatch({ type: 'SET_SESSIONS', sessions: [newSession] });
        dispatch({ type: 'SET_SESSION_ID', sessionId: newSession.id });
        dispatch({ type: 'SET_MESSAGES', messages: [] });
      }
    };

    reloadSessions();

    const handleAppStateChange = (nextAppState: AppStateStatus) => {
      if (nextAppState === 'active') {
        reloadSessions();
      }
    };

    const sub = AppState.addEventListener('change', handleAppStateChange);
    return () => sub.remove();
  }, [dispatch]);

  useModelLoader(dispatch);

  const handleSessionSelect = useCallback((id: string) => {
    dispatch({ type: 'SET_SESSION_ID', sessionId: id });
    dispatch({ type: 'SET_MESSAGES', messages: dbService.getMessages(id) });
    dispatch({ type: 'TOGGLE_SIDEBAR', value: false });
  }, [dispatch]);

  const handleNewSession = useCallback(() => {
    const newSession = dbService.createSession('New Chat');
    const updatedSessions = dbService.getSessions();
    dispatch({ type: 'SET_SESSIONS', sessions: updatedSessions });
    dispatch({ type: 'SET_SESSION_ID', sessionId: newSession.id });
    dispatch({ type: 'SET_MESSAGES', messages: [] });
    dispatch({ type: 'TOGGLE_SIDEBAR', value: false });
  }, [dispatch]);

  const handleSessionDelete = useCallback((id: string) => {
    dbService.deleteSession(id);
    const updatedSessions = dbService.getSessions();
    dispatch({ type: 'SET_SESSIONS', sessions: updatedSessions });
    if (sessionIdRef.current === id) {
      if (updatedSessions.length > 0) {
        dispatch({ type: 'SET_SESSION_ID', sessionId: updatedSessions[0].id });
        dispatch({ type: 'SET_MESSAGES', messages: dbService.getMessages(updatedSessions[0].id) });
      } else {
        const newSession = dbService.createSession('New Chat');
        dispatch({ type: 'SET_SESSIONS', sessions: [newSession] });
        dispatch({ type: 'SET_SESSION_ID', sessionId: newSession.id });
        dispatch({ type: 'SET_MESSAGES', messages: [] });
      }
    }
  }, [dispatch]);

  const handleSessionRename = useCallback((id: string, newTitle: string) => {
    dbService.updateSessionTitle(id, newTitle);
    dispatch({ type: 'SET_SESSIONS', sessions: dbService.getSessions() });
  }, [dispatch]);

  const selectedModel = useMemo(
    () => models.find((m) => m.id === selectedModelId) || models[0],
    [models, selectedModelId],
  );

  const handleSelectModel = useCallback((id: string) => {
    setModelDropdownOpen(false);
    const target = models.find((m) => m.id === id);
    if (!target) return;
    if (target.downloaded) {
      KrithaNativeModule.setSelectedModel(id);
      dispatch({ type: 'SET_SELECTED_MODEL', modelId: id });
    } else {
      setDownloadModalModel(target);
    }
  }, [dispatch, models]);

  const handleStartDownload = useCallback((model: ModelRecord) => {
    dispatch({ type: 'UPDATE_DOWNLOAD', patch: { modelId: model.id, active: true, progress: 0 } });
    KrithaNativeModule.downloadModel(model.id);
  }, [dispatch]);

  const handleStatusChange = useCallback(
    (status: 'idle' | 'recording' | 'processing' | 'sending') => {
      if (status === 'recording') {
        dispatch({ type: 'SET_RECORDING', value: true });
        setIsProcessing(false);
      } else if (status === 'processing') {
        dispatch({ type: 'SET_RECORDING', value: false });
        setIsProcessing(true);
      } else {
        dispatch({ type: 'SET_RECORDING', value: false });
        setIsProcessing(false);
      }
    },
    [dispatch],
  );

  const handleDraftChange = useCallback((text: string) => {
    dispatch({ type: 'SET_DRAFT', text });
  }, [dispatch]);

  const sendMessageWithText = useCallback(
    async (text: string, autoTts = false) => {
      if (!text.trim()) return;

      const userText = text.trim();
      const currentMsgs = messagesRef.current;
      const currentSessionId = sessionIdRef.current;

      const userMessage: ChatMessage = {
        id: `${Date.now()}_user`,
        role: 'user',
        text: userText,
      };

      const assistantMsgId = `${Date.now()}_assistant`;

      const placeholderAssistantMsg: ChatMessage = {
        id: assistantMsgId,
        role: 'assistant',
        text: '',
      };

      dispatch({ type: 'SET_MESSAGES', messages: [...currentMsgs, userMessage, placeholderAssistantMsg] });
      dispatch({ type: 'SET_DRAFT', text: '' });
      dispatch({ type: 'SET_SENDING', value: true });
      dispatch({ type: 'SET_ERROR', error: null });

      if (currentMsgs.length === 0 && currentSessionId) {
        const title = userText.length > 25 ? userText.slice(0, 25) + '...' : userText;
        dbService.updateSessionTitle(currentSessionId, title);
        dispatch({ type: 'SET_SESSIONS', sessions: dbService.getSessions() });
      }

      if (currentSessionId) {
        dbService.addMessage({
          id: userMessage.id,
          session_id: currentSessionId,
          role: userMessage.role,
          text: userMessage.text,
          created_at: Date.now(),
        });
      }

      try {
        let responseText = '';
        const sub = KrithaNativeModule.addListener('onAssistantEvent', (event) => {
          if ((event as any).state === 'streaming' && (event as any).chunk) {
            const chunk = (event as any).chunk;
            dispatch({ type: 'STREAM_CHUNK', id: assistantMsgId, chunk });
            if (autoTts) {
              try { KrithaNativeModule.speakChunk(chunk); } catch { }
            }
          }
        });
        try {
          if (autoTts) {
            dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: true, isPaused: false, msgId: assistantMsgId } });
          }
          responseText = await KrithaNativeModule.generateLocalResponse(userText, selectedModel?.id || '');
          if (autoTts) {
            try { KrithaNativeModule.flushTts(); } catch { }
          }
        } finally {
          sub.remove();
        }

        if (currentSessionId) {
          dbService.addMessage({
            id: assistantMsgId,
            session_id: currentSessionId,
            role: 'assistant',
            text: responseText,
            created_at: Date.now(),
          });
        }

        dispatch({
          type: 'FINISH_ASSISTANT_STREAM',
          id: assistantMsgId,
          fullText: responseText,
        });
      } catch (err: any) {
        dispatch({ type: 'SET_ERROR', error: err?.message || 'Failed to generate response.' });
      } finally {
        isSendingRef.current = false;
        dispatch({ type: 'SET_SENDING', value: false });
      }
    },
    [dispatch, selectedModel],
  );


  const sendMessage = useCallback(async () => {
    if (!draft.trim()) return;
    await sendMessageWithText(draft.trim(), false);
  }, [draft, sendMessageWithText]);

  const handleDictatePress = useCallback(async (autoSend?: boolean | any) => {
    const shouldAutoSend = autoSend === true;
    if (isRecording) {
      try { KrithaNativeModule.stopDictation(); } catch { }
      dispatch({ type: 'SET_RECORDING', value: false });
      setIsProcessing(false);
      return;
    }

    try { KrithaNativeModule.stopTts(); } catch { }
    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
    
    dispatch({ type: 'SET_PRE_DICTATION_DRAFT', text: draft });
    dispatch({ type: 'SET_RECORDING', value: true });
    setIsProcessing(false);

    const subPartial = KrithaNativeModule.addListener('onDictationPartial', (event) => {
      if (event.text) dispatch({ type: 'SET_DRAFT', text: event.text });
    });

    try {
      const userText = await KrithaNativeModule.startDictation();
      subPartial.remove();
      dispatch({ type: 'SET_RECORDING', value: false });

      if (userText && userText.trim().length > 0) {
        dispatch({ type: 'SET_DRAFT', text: userText.trim() });
        if (shouldAutoSend) {
          sendMessageWithText(userText.trim(), true);
        }
      } else {
        dispatch({ type: 'SET_DRAFT', text: '' });
      }
    } catch {
      subPartial.remove();
      dispatch({ type: 'SET_RECORDING', value: false });
    }
  }, [dispatch, draft, isRecording, sendMessageWithText]);

  const handleLiveTalkToggle = useCallback(() => {
    if (isLiveTalkRef.current) {
      setIsLiveTalk(false);
      try { KrithaNativeModule.stopDictation(); } catch { }
      try { KrithaNativeModule.stopTts(); } catch { }
      dispatch({ type: 'SET_RECORDING', value: false });
      setIsProcessing(false);
    } else {
      setIsLiveTalk(true);
      try { KrithaNativeModule.stopTts(); } catch { }
      handleDictatePress(true);
    }
  }, [dispatch, handleDictatePress]);

  const handleLiveTalkPauseResume = useCallback(() => {
    if (ttsState.isSpeaking || isRecordingRef.current) {
      try { KrithaNativeModule.stopTts(); } catch { }
      try { KrithaNativeModule.stopDictation(); } catch { }
      dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: true, msgId: null } });
      dispatch({ type: 'SET_RECORDING', value: false });
    } else {
      dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
      handleDictatePress(true);
    }
  }, [dispatch, handleDictatePress, ttsState.isSpeaking]);

  const handleTtsDone = useCallback(() => {
    if (isLiveTalkRef.current && !isRecordingRef.current && !isSendingRef.current) {
      handleDictatePress(true);
    }
  }, [handleDictatePress]);

  const handleWakeWordDetected = useCallback(() => {
    if (!isRecordingRef.current) {
      try { KrithaNativeModule.stopTts(); } catch { }
      try { KrithaNativeModule.stopGeneration(); } catch { }
      dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
      dispatch({ type: 'SET_SENDING', value: false });
      handleDictatePress(true);
    }
  }, [dispatch, handleDictatePress]);

  useNativeEvents({
    dispatch,
    isSendingRef,
    onWakeWordDetected: handleWakeWordDetected,
    isRecordingRef,
    onTtsDone: handleTtsDone,
  });

  const insets = useSafeAreaInsets();
  const keyboard = useAnimatedKeyboard();
  const defaultBottom = Math.max(insets.bottom + 16, 28);

  const floatingStyle = useAnimatedStyle(() => {
    const kbHeight = keyboard.height.value;
    return { bottom: kbHeight > 0 ? kbHeight + 12 : defaultBottom };
  });

  const messagesStyle = useAnimatedStyle(() => {
    const kbHeight = keyboard.height.value;
    const inputHeight = 74;
    return {
      flex: 1,
      marginBottom: kbHeight > 0
        ? kbHeight + 12 + inputHeight + 8
        : defaultBottom + inputHeight - 16,
    };
  });

  return (
    <View style={styles.shell}>
      <DictationCornerGlow active={isRecording} />
      <StatusBar style="light" />

      <View style={styles.appFrame}>
        {sidebarOpen && (
          <ChatSidebar
            sessions={sessions}
            currentSessionId={sessionId}
            onSessionSelect={handleSessionSelect}
            onNewSession={handleNewSession}
            onSessionDelete={handleSessionDelete}
            onSessionRename={handleSessionRename}
            onClose={() => dispatch({ type: 'TOGGLE_SIDEBAR', value: false })}
          />
        )}

        <View style={{ flex: 1 }}>
          <View style={styles.chatPanel}>
            <ChatHeader
              sidebarOpen={sidebarOpen}
              setSidebarOpen={(val) => dispatch({ type: 'TOGGLE_SIDEBAR', value: val })}
              isWakeWordOn={isWakeWordOn}
              onWakeWordToggle={() => {
                const nextState = !isWakeWordOn;
                dispatch({ type: 'TOGGLE_WAKE_WORD', value: nextState });
                if (nextState) wakeWordService.start();
                else wakeWordService.stop();
              }}
              modelName={selectedModel?.name || 'Select Model'}
              onModelSelectClick={() => setModelDropdownOpen(true)}
              onNewSession={handleNewSession}
            />

            {assistantBanner && assistantBanner.status !== 'idle' && (
              <View style={styles.assistantBanner}>
                <View style={styles.bannerLeft}>
                  <Text style={styles.bannerText}>
                    {assistantBanner.transcript || `Assistant: ${assistantBanner.status}`}
                  </Text>
                </View>
                <TouchableOpacity
                  onPress={() => {
                    dispatch({ type: 'SET_ASSISTANT_BANNER', banner: { status: 'idle' } });
                    KrithaNativeModule.stopAssistantSession();
                  }}
                  style={styles.stopBtn}
                >
                  <Square size={16} color={Colors.error} />
                </TouchableOpacity>
              </View>
            )}

            <Animated.View style={messagesStyle}>
              <ChatMessages
                messages={messages}
                isSending={isSending}
                error={error}
                ttsMsgId={state.ttsState.msgId}
                isTtsSpeaking={state.ttsState.isSpeaking}
                isTtsPaused={state.ttsState.isPaused}
                onSpeakerPress={(id) => {
                  const msg = messages.find((m) => m.id === id);
                  if (!msg) return;
                  if (state.ttsState.isSpeaking && state.ttsState.msgId === id) {
                    try { KrithaNativeModule.stopTts(); } catch { }
                    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
                  } else {
                    try { KrithaNativeModule.stopTts(); } catch { }
                    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: true, isPaused: false, msgId: id } });
                    try { KrithaNativeModule.speakText(msg.text); } catch { }
                  }
                }}
              />
            </Animated.View>

            <Animated.View style={[styles.floatingInputWrapper, floatingStyle]}>
              {(isRecording || messages.length === 0) && (
                <View pointerEvents="none" style={styles.ambientGlowContainer}>
                  <Svg height="240" width="100%">
                    <Defs>
                      <SvgGradient id="interfaceBottomGlow" x1="0" y1="1" x2="0" y2="0">
                        <Stop
                          offset="0%"
                          stopColor={isRecording ? Colors.accentCyan : Colors.accentBlue}
                          stopOpacity="0.95"
                        />
                        <Stop
                          offset="50%"
                          stopColor={isRecording ? Colors.accentCyanDim : Colors.accentBlue}
                          stopOpacity="0.55"
                        />
                        <Stop
                          offset="100%"
                          stopColor={isRecording ? Colors.accentCyan : Colors.accentBlue}
                          stopOpacity="0"
                        />
                      </SvgGradient>
                    </Defs>
                    <Rect width="100%" height="240" fill="url(#interfaceBottomGlow)" />
                  </Svg>
                </View>
              )}

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
                  setDraft={(text) => dispatch({ type: 'SET_DRAFT', text })}
                  isSending={isSending}
                  isRecording={isRecording}
                  isProcessing={isProcessing}
                  isLiveTalk={isLiveTalk}
                  onSendMessage={sendMessage}
                  onDictatePress={handleDictatePress}
                  onLiveTalkPress={handleLiveTalkToggle}
                  onStopDictation={() => KrithaNativeModule.stopDictation()}
                  onStopResponse={() => KrithaNativeModule.stopGeneration()}
                />
              )}
            </Animated.View>
          </View>
        </View>
      </View>

      <ModelSelectModal
        isDropdownOpen={isModelDropdownOpen}
        onCloseDropdown={() => setModelDropdownOpen(false)}
        models={models}
        selectedModelId={selectedModelId}
        onSelectModel={handleSelectModel}
        downloadModalModel={downloadModalModel}
        onCloseDownloadModal={() => setDownloadModalModel(null)}
        onStartDownload={handleStartDownload}
        downloadState={downloadState}
      />
    </View>
  );
}

export default ChatInterface;

const styles = StyleSheet.create({
  shell: { flex: 1, backgroundColor: Colors.bgDeepest },
  appFrame: { flex: 1, backgroundColor: Colors.bgDeepest, position: 'relative' },
  chatPanel: {
    flex: 1,
    backgroundColor: Colors.bgSurface,
    position: 'relative',
  },
  floatingInputWrapper: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 100,
  },
  ambientGlowContainer: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: -60,
    height: 240,
    overflow: 'hidden',
  },
  assistantBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.bgElevated,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.borderAccent,
  },
  bannerLeft: { flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 },
  bannerText: { color: Colors.textPrimary, fontSize: 13, fontWeight: '600' },
  stopBtn: { padding: 4 },
});
