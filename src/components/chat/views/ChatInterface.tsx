import Colors from '@/theme';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AppState,
  AppStateStatus,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useReanimatedKeyboardAnimation } from 'react-native-keyboard-controller';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, {
  Defs,
  Rect,
  Stop,
  LinearGradient as SvgGradient,
} from 'react-native-svg';

import { chatApi } from '@/services/chatApi';
import { useAssistantStore } from '@/store/assistantStore';
import {
  cancel,
  downloadModel,
  isDefaultAssistant,
  playTts,
  resumeTts,
  setSelectedModel,
  startListening,
  getUserName as getNativeUserName,
  setUserName as setNativeUserName,
  stopListening,
  stopTts,
  submitText,
} from '@modules/kritha/src';

import { useChatState } from '@/hooks/use-chat-state';
import { useModelLoader } from '@/hooks/use-model-loader';
import { useNativeEvents } from '@/hooks/use-native-events';
import { useWakeWordBootstrap } from '@/hooks/use-wakeword-bootstrap';
import { wakeWordService } from '@/services/wakeword.service';

import { ModelRecord } from '@/components/chat/types';
import {
  ChatHeader,
  ChatInput,
  ChatMessages,
  ChatSidebar,
  DictationCornerGlow,
  LiveTalkBar,
} from '@/components/chat/ui';
import {
  ModelSelectModal,
  PermissionsChecklistModal,
  PERMISSIONS_ONBOARDING_KEY,
} from '@/components/chat/modals';
import * as SecureStore from 'expo-secure-store';

export function ChatInterface() {
  useWakeWordBootstrap();

  const { state, dispatch } = useChatState();
  const {
    models,
    selectedModelId,
    downloadState,
    draft,
    isWakeWordOn,
    sidebarOpen,
  } = state;

  const [isModelDropdownOpen, setModelDropdownOpen] = useState(false);
  const [downloadModalModel, setDownloadModalModel] =
    useState<ModelRecord | null>(null);
  const [isLiveTalk, setIsLiveTalk] = useState(false);
  const [permissionsModalVisible, setPermissionsModalVisible] = useState(false);

  useEffect(() => {
    const checkFirstEverStart = async () => {
      try {
        const hasSeen = await SecureStore.getItemAsync(
          PERMISSIONS_ONBOARDING_KEY,
        );
        const isDefault = isDefaultAssistant();
        if (!hasSeen || !isDefault) {
          setPermissionsModalVisible(true);
        }
      } catch (e) {
        console.error('Failed checking first start onboarding key:', e);
      }
    };
    checkFirstEverStart();
  }, []);

  const sessionId = useAssistantStore((s) => s.chatSessionId);
  const sessions = useAssistantStore((s) => s.sessions);
  const messages = useAssistantStore((s) => s.messages);
  const error = useAssistantStore((s) => s.error);

  const transcriptFromStore = useAssistantStore((s) => s.transcript);
  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const responseFromStore = useAssistantStore((s) => s.response);
  const isTtsSpeaking = useAssistantStore((s) => s.isTtsSpeaking);
  const isTtsPaused = useAssistantStore((s) => s.isTtsPaused);
  const currentTtsMsgId = useAssistantStore((s) => s.currentTtsMsgId);

  const isRecording = canonicalState === 'LISTENING';
  const isProcessing =
    canonicalState === 'THINKING' || canonicalState === 'GENERATING';
  const isSending =
    canonicalState === 'THINKING' || canonicalState === 'GENERATING';

  const displayMessages = messages;

  useEffect(() => {
    if (transcriptFromStore && isRecording) {
      dispatch({ type: 'SET_DRAFT', text: transcriptFromStore });
    }
  }, [transcriptFromStore, isRecording, dispatch]);

  const prevIsRecordingRef = useRef(isRecording);
  useEffect(() => {
    const wasRecording = prevIsRecordingRef.current;
    prevIsRecordingRef.current = isRecording;
    if (wasRecording && !isRecording) {
      dispatch({ type: 'SET_DRAFT', text: '' });
      useAssistantStore.getState().setTranscript('');
    }
  }, [isRecording, dispatch]);

  const isLiveTalkRef = useRef(isLiveTalk);
  useEffect(() => {
    isLiveTalkRef.current = isLiveTalk;
  }, [isLiveTalk]);

  const messagesRef = useRef(messages);
  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  const sessionIdRef = useRef(sessionId);
  useEffect(() => {
    sessionIdRef.current = sessionId;
  }, [sessionId]);

  const isSendingRef = useRef(isSending);
  useEffect(() => {
    isSendingRef.current = isSending;
  }, [isSending]);

  const isRecordingRef = useRef(isRecording);
  useEffect(() => {
    isRecordingRef.current = isRecording;
  }, [isRecording]);

  useEffect(() => {
    try {
      chatApi.beginNewChat();
    } catch {}

    const reloadSessions = async () => {
      try {
        const nativeName = getNativeUserName();
        if (nativeName) {
          useAssistantStore.getState().setUserName(nativeName);
        }
      } catch {}

      try {
        const loadedSessions = chatApi.loadSessions();
        useAssistantStore.getState().setSessions(loadedSessions);
      } catch (e: unknown) {
        useAssistantStore
          .getState()
          .setError((e as Error).message || 'Failed to load database sessions');
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
  }, []);

  useModelLoader(dispatch);

  const handleSessionSelect = useCallback(
    (id: string) => {
      try {
        chatApi.openChat(id);
        dispatch({ type: 'TOGGLE_SIDEBAR', value: false });
      } catch (e: unknown) {
        useAssistantStore
          .getState()
          .setError((e as Error).message || 'Failed to load messages');
      }
    },
    [dispatch],
  );

  const handleNewChat = useCallback(() => {
    try {
      chatApi.beginNewChat();
      dispatch({ type: 'TOGGLE_SIDEBAR', value: false });
    } catch (e: unknown) {
      useAssistantStore
        .getState()
        .setError((e as Error).message || 'Failed to create new chat');
    }
  }, [dispatch]);

  const handleDeleteSession = useCallback((id: string) => {
    try {
      chatApi.deleteChat(id);
    } catch (e: unknown) {
      useAssistantStore
        .getState()
        .setError((e as Error).message || 'Failed to delete chat session');
    }
  }, []);

  const handleRenameSession = useCallback((id: string, title: string) => {
    try {
      chatApi.renameChat(id, title);
    } catch (e: unknown) {
      useAssistantStore
        .getState()
        .setError((e as Error).message || 'Failed to rename chat session');
    }
  }, []);

  const handleArchiveSession = useCallback((id: string) => {
    try {
      chatApi.archiveChat(id, true);
    } catch (e: unknown) {
      useAssistantStore
        .getState()
        .setError((e as Error).message || 'Failed to archive chat session');
    }
  }, []);

  const handlePinSession = useCallback((id: string) => {
    try {
      const session = useAssistantStore
        .getState()
        .sessions.find((s) => s.id === id);
      const isCurrentlyPinned = session?.pinned === 1;
      chatApi.pinChat(id, !isCurrentlyPinned);
    } catch (e: unknown) {
      useAssistantStore
        .getState()
        .setError((e as Error).message || 'Failed to pin chat session');
    }
  }, []);

  const handleModelSelect = useCallback(
    (id: string) => {
      const model = models.find((m) => m.id === id);
      if (model && !model.downloaded && !model.isCloud) {
        setDownloadModalModel(model);
        setModelDropdownOpen(false);
        return;
      }
      try {
        setSelectedModel(id);
      } catch (e) {
        console.warn('Failed to set selected model natively:', e);
      }
      dispatch({ type: 'SET_SELECTED_MODEL', modelId: id });
      setModelDropdownOpen(false);
    },
    [models, dispatch],
  );

  const handleTtsDone = useCallback(() => {
    if (isLiveTalkRef.current) {
      try {
        startListening();
      } catch (e) {
        console.warn('Failed to restart dictation after TTS completion:', e);
      }
    }
  }, []);

  const handleWakeWordDetected = useCallback(() => {
    startListening(sessionIdRef.current || undefined);
  }, []);

  useNativeEvents({
    dispatch,
    sessionId,
    onWakeWordDetected: handleWakeWordDetected,
    onDownloadComplete: (modelId) => {
      setDownloadModalModel(null);
      try {
        setSelectedModel(modelId);
      } catch (e) {
        console.warn('Failed to set selected model natively:', e);
      }
      dispatch({ type: 'SET_SELECTED_MODEL', modelId });
    },
  });

  const selectedModel = useMemo(
    () => models.find((m) => m.id === selectedModelId) || models[0],
    [models, selectedModelId],
  );

  const handleSendMessage = useCallback(
    async (textToSend?: string) => {
      const userText = (textToSend !== undefined ? textToSend : draft).trim();
      if (!userText || isSending) return;

      dispatch({ type: 'SET_DRAFT', text: '' });
      dispatch({ type: 'SET_ERROR', error: null });
      useAssistantStore.getState().setTranscript('');

      try {
        submitText(userText, {
          chatSessionId: sessionId || undefined,
          modelId: selectedModelId,
          origin: 'MANUAL_TYPING',
        });
      } catch (e: unknown) {
        dispatch({
          type: 'SET_ERROR',
          error: (e as Error).message || 'Failed to generate response',
        });
      }
    },
    [draft, isSending, dispatch, sessionId, selectedModelId],
  );

  const handleDictatePress = useCallback(async () => {
    if (isRecording) {
      try {
        stopListening();
      } catch (e) {
        console.warn('Failed to stop listening:', e);
      }
      return;
    }

    dispatch({ type: 'SET_DRAFT', text: '' });
    try {
      startListening(sessionId || undefined);
    } catch (e) {
      console.warn('Failed to start listening:', e);
    }
  }, [isRecording, dispatch, sessionId]);

  const handleStopDictation = useCallback(() => {
    try {
      stopListening();
    } catch (e) {
      console.warn('Failed to stop dictation:', e);
    }
  }, []);

  const handleLiveTalkToggle = useCallback(() => {
    if (isLiveTalk) {
      setIsLiveTalk(false);
      cancel();
    } else {
      setIsLiveTalk(true);
      startListening(sessionId || undefined);
    }
  }, [isLiveTalk, sessionId]);

  const handleLiveTalkPauseResume = useCallback(() => {
    if (isTtsSpeaking || isRecording) {
      cancel();
    } else {
      startListening(sessionId || undefined);
    }
  }, [isRecording, isTtsSpeaking, sessionId]);

  const handleStopResponse = useCallback(() => {
    cancel();
  }, []);

  const handleSpeakerPress = useCallback(
    (msgId: string) => {
      if (isTtsSpeaking && (!currentTtsMsgId || currentTtsMsgId === msgId)) {
        stopTts();
      } else if (
        isTtsPaused &&
        (!currentTtsMsgId || currentTtsMsgId === msgId)
      ) {
        resumeTts();
      } else {
        const msg = messagesRef.current.find((m) => m.id === msgId);
        if (msg && msg.text) {
          playTts(msg.text, {
            chatSessionId: sessionId || undefined,
            messageId: msgId,
          });
        }
      }
    },
    [isTtsSpeaking, isTtsPaused, currentTtsMsgId, sessionId],
  );

  const toggleWakeWord = useCallback(() => {
    const nextState = !isWakeWordOn;
    dispatch({ type: 'TOGGLE_WAKE_WORD', value: nextState });
    if (nextState) {
      wakeWordService.start();
    } else {
      wakeWordService.stop();
    }
  }, [isWakeWordOn, dispatch]);

  const insets = useSafeAreaInsets();
  const keyboard = useReanimatedKeyboardAnimation();

  const animatedBottomStyle = useAnimatedStyle(() => {
    const rawHeight = keyboard.height.value;
    const keyboardHeight = Math.abs(rawHeight);
    const bottomPadding =
      keyboardHeight > 0 ? keyboardHeight : Math.max(insets.bottom, 16);
    return {
      paddingBottom: bottomPadding,
    };
  }, [insets.bottom]);

  return (
    <View style={styles.container}>
      <StatusBar style="light" />

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

      <DictationCornerGlow active={isRecording} />

      <View style={styles.mainLayout}>
        <ChatHeader
          modelName={selectedModel.name}
          isWakeWordOn={isWakeWordOn}
          onMenu={() => dispatch({ type: 'TOGGLE_SIDEBAR', value: true })}
          onNewSession={handleNewChat}
          onModelSelectClick={() => setModelDropdownOpen((p) => !p)}
          onWakeWordToggle={toggleWakeWord}
        />

        <View style={styles.chatArea}>
          <ChatMessages
            messages={displayMessages}
            isSending={isSending}
            error={error}
            ttsMsgId={currentTtsMsgId}
            isTtsSpeaking={isTtsSpeaking}
            isTtsPaused={isTtsPaused}
            onSpeakerPress={handleSpeakerPress}
          />
        </View>

        <Animated.View
          style={[styles.floatingInputWrapper, animatedBottomStyle]}
        >
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
              draft={draft}
              setDraft={(val) => dispatch({ type: 'SET_DRAFT', text: val })}
              isSending={isSending}
              isRecording={isRecording}
              isProcessing={isProcessing}
              isLiveTalk={isLiveTalk}
              onSendMessage={() => handleSendMessage()}
              onDictatePress={handleDictatePress}
              onLiveTalkPress={handleLiveTalkToggle}
              onStopDictation={handleStopDictation}
              onStopResponse={handleStopResponse}
            />
          )}
        </Animated.View>
      </View>

      {sidebarOpen && (
        <ChatSidebar
          sessions={sessions}
          currentSessionId={sessionId}
          onClose={() => dispatch({ type: 'TOGGLE_SIDEBAR', value: false })}
          onSessionSelect={handleSessionSelect}
          onNewSession={handleNewChat}
          onSessionDelete={handleDeleteSession}
          onSessionRename={handleRenameSession}
          onSessionPin={handlePinSession}
          onSessionArchive={handleArchiveSession}
        />
      )}

      <ModelSelectModal
        isDropdownOpen={isModelDropdownOpen}
        onCloseDropdown={() => setModelDropdownOpen(false)}
        models={models}
        selectedModelId={selectedModelId}
        onSelectModel={handleModelSelect}
        downloadModalModel={downloadModalModel}
        onCloseDownloadModal={() => setDownloadModalModel(null)}
        onStartDownload={(model: ModelRecord) => {
          try {
            downloadModel(model.id);
            dispatch({
              type: 'UPDATE_DOWNLOAD',
              patch: {
                active: true,
                progress: 0,
                downloadedMb: 0,
                totalMb: model.totalMb || 0,
              },
            });
          } catch (e) {
            console.error('Failed to start download:', e);
          }
        }}
        downloadState={downloadState}
      />

      <PermissionsChecklistModal
        visible={permissionsModalVisible}
        onClose={() => setPermissionsModalVisible(false)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bgDeepest,
  },
  mainLayout: {
    flex: 1,
  },
  chatArea: {
    flex: 1,
  },
  floatingInputWrapper: {
    width: '100%',
    alignItems: 'center',
    paddingTop: 8,
  },
  stopButton: {
    position: 'absolute',
    bottom: 90,
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(239, 68, 68, 0.85)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    gap: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 6,
  },
  stopButtonText: {
    color: Colors.textOnAccent,
    fontSize: 13,
    fontWeight: '600',
  },
});
