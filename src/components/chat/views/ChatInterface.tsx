import Colors from '@/theme';
import * as SecureStore from 'expo-secure-store';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AppState, AppStateStatus, StyleSheet, View } from 'react-native';
import Animated from 'react-native-reanimated';
import Svg, {
    Defs,
    Rect,
    Stop,
    LinearGradient as SvgGradient,
} from 'react-native-svg';

import { useAssistantKeyboard } from '@/hooks/use-assistant-keyboard';
import { useChatState } from '@/hooks/use-chat-state';
import { useModelLoader } from '@/hooks/use-model-loader';
import { useNativeEvents } from '@/hooks/use-native-events';
import { useWakeWordBootstrap } from '@/hooks/use-wakeword-bootstrap';
import { chatApi } from '@/services/chat.service';
import { getConversationContext } from '@/services/conversation-context.service';
import { wakeWordService } from '@/services/wakeword.service';
import { useAssistantStore } from '@/store/assistantStore';

import {
    downloadModel,
    getUserName as getNativeUserName,
    isDefaultAssistant,
    setSelectedModel,
    startListening,
} from '@modules/kritha/src';

import {
    ModelSelectModal,
    PERMISSIONS_ONBOARDING_KEY,
    PermissionsChecklistModal,
} from '@/components/chat/modals';
import { ModelRecord } from '@/components/chat/types';
import {
    ChatHeader,
    ChatInput,
    ChatMessages,
    ChatSidebar,
    DictationCornerGlow,
    LiveTalkBar,
} from '@/components/chat/ui';
export function ChatInterface() {
  useWakeWordBootstrap();

  const sessions = useAssistantStore((s) => s.sessions);
  const chatSessionId = useAssistantStore((s) => s.chatSessionId);
  const canonicalState = useAssistantStore((s) => s.canonicalState);
  const isLiveTalk = useAssistantStore((s) => s.isLiveTalk);
  const setSessions = useAssistantStore((s) => s.setSessions);
  const setDraftText = useAssistantStore((s) => s.setDraftText);
  const setTranscript = useAssistantStore((s) => s.setTranscript);
  const setUserName = useAssistantStore((s) => s.setUserName);
  const setError = useAssistantStore((s) => s.setError);

  const { state, dispatch } = useChatState();
  const { models, selectedModelId, downloadState, isWakeWordOn, sidebarOpen } =
    state;

  const [isModelDropdownOpen, setModelDropdownOpen] = useState(false);
  const [downloadModalModel, setDownloadModalModel] =
    useState<ModelRecord | null>(null);
  const [permissionsModalVisible, setPermissionsModalVisible] = useState(false);

  const isRecording = canonicalState === 'LISTENING';

  // First-launch permission onboarding
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

  // Clear draft when recording ends
  const prevIsRecordingRef = useRef(isRecording);
  useEffect(() => {
    const wasRecording = prevIsRecordingRef.current;
    prevIsRecordingRef.current = isRecording;

    if (wasRecording && !isRecording) {
      setDraftText('');
      setTranscript('');
    }
  }, [isRecording]);

  useEffect(() => {
    try {
      chatApi.beginNewChat();
    } catch {}

    const reloadSessions = async () => {
      try {
        const nativeName = getNativeUserName();
        if (nativeName) {
          setUserName(nativeName);
        }
        const loadedSessions = await chatApi.loadSessions();
        setSessions(loadedSessions);
      } catch (e) {
        console.warn('Failed to load chat sessions:', e);
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
      } catch (e: any) {
        setError(e.message || 'Failed to load messages');
      }
    },
    [dispatch],
  );

  const handleNewChat = useCallback(() => {
    try {
      chatApi.beginNewChat();
      dispatch({ type: 'TOGGLE_SIDEBAR', value: false });
    } catch (e: any) {
      setError(e.message || 'Failed to create new chat session');
    }
  }, [dispatch]);

  const handleDeleteSession = useCallback((id: string) => {
    try {
      chatApi.deleteChat(id);
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  const handleRenameSession = useCallback((id: string, title: string) => {
    try {
      chatApi.renameChat(id, title);
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  const handleArchiveSession = useCallback((id: string) => {
    try {
      chatApi.archiveChat(id, true);
    } catch (e: any) {
      setError(e.message);
    }
  }, []);

  const handlePinSession = useCallback((id: string) => {
    try {
      const session = sessions.find((s) => s.id === id);
      chatApi.pinChat(id, !session?.pinned);
    } catch (e: any) {
      setError(e.message);
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

  useNativeEvents({
    dispatch,
    onWakeWordDetected: () => {
      try {
        startListening(
          chatSessionId || undefined,
          undefined,
          getConversationContext(),
        );
      } catch (e) {
        console.warn('Failed to handle wake word:', e);
      }
    },
    onTtsDone: () => {
      if (isLiveTalk) {
        try {
          startListening(
            chatSessionId || undefined,
            undefined,
            getConversationContext(),
          );
        } catch (e) {
          console.warn('Failed to restart dictation after TTS:', e);
        }
      }
    },
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

  const toggleWakeWord = useCallback(() => {
    const nextState = !isWakeWordOn;
    dispatch({ type: 'TOGGLE_WAKE_WORD', value: nextState });
    if (nextState) {
      wakeWordService.start();
    } else {
      wakeWordService.stop();
    }
  }, [isWakeWordOn, dispatch]);

  const selectedModel = useMemo(
    () => models.find((m) => m.id === selectedModelId) || models[0],
    [models, selectedModelId],
  );

  useEffect(() => {
    if (!sidebarOpen) return;
    chatApi.syncSessions().catch((e) => {
      console.warn('Failed to refresh chat sessions:', e);
    });
  }, [sidebarOpen]);

  const animatedBottomStyle = useAssistantKeyboard();

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
          modelName={selectedModel?.name || ''}
          isWakeWordOn={isWakeWordOn}
          onMenu={() => dispatch({ type: 'TOGGLE_SIDEBAR', value: true })}
          onNewSession={handleNewChat}
          onModelSelectClick={() => setModelDropdownOpen((prev) => !prev)}
          onWakeWordToggle={toggleWakeWord}
        />

        <View style={styles.chatArea}>
          <ChatMessages />
        </View>

        <Animated.View
          style={[styles.floatingInputWrapper, animatedBottomStyle]}
        >
          {isLiveTalk ? (
            <LiveTalkBar />
          ) : (
            <ChatInput variant="chat" modelId={selectedModelId} />
          )}
        </Animated.View>
      </View>

      {sidebarOpen && (
        <ChatSidebar
          sessions={sessions}
          currentSessionId={chatSessionId}
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
  container: { flex: 1, backgroundColor: Colors.bgDeepest },
  mainLayout: { flex: 1 },
  chatArea: { flex: 1 },
  floatingInputWrapper: { width: '100%', alignItems: 'center', paddingTop: 8 },
});
