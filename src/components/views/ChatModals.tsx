import { useCallback, useEffect, useRef, useState } from 'react';

import { useChatSession, useSidebar, useSpeaker } from '@/hooks';
import { ChatSessionService, modelDownloadService } from '@/services';
import { useModelStore, useUpdateStore, useVoiceStore } from '@/stores';
import { ModelRecord } from '@/types';

import {
  LlmModelModal,
  ModelSelectModal,
  PermissionsChecklistModal,
  UpdateModal,
  VoiceModelModal,
} from '../modals';
import { ChatSidebar } from './ChatSidebar';

interface Props {
  sidebarOpen: boolean;
  setSidebarOpen: (o: boolean) => void;
  isModelDropdownOpen: boolean;
  setModelDropdownOpen: (o: boolean) => void;
  downloadModalModel: ModelRecord | null;
  setDownloadModalModel: (m: ModelRecord | null) => void;
  permissionsModalVisible: boolean;
  setPermissionsModalVisible: (o: boolean) => void;
}

export function ChatModals({
  sidebarOpen,
  setSidebarOpen,
  isModelDropdownOpen,
  setModelDropdownOpen,
  downloadModalModel,
  setDownloadModalModel,
  permissionsModalVisible,
  setPermissionsModalVisible,
}: Props) {
  const { closeVoiceModal } = useSpeaker();
  const models = useModelStore((s) => s.models);
  const selectedModelId = useModelStore((s) => s.selectedModelId);
  const downloadState = useModelStore((s) => s.downloadState);
  const isLlmModalOpen = useModelStore((s) => s.isLlmModalOpen);
  const setLlmModalOpen = useModelStore((s) => s.setLlmModalOpen);
  const isVoiceModalOpen = useVoiceStore((s) => s.isVoiceModalOpen);

  const { appUpdate } = useUpdateStore();
  const [updateModalVisible, setUpdateModalVisible] = useState(false);
  const shownVersionRef = useRef<string | null>(null);

  useEffect(() => {
    if (appUpdate.available && appUpdate.info) {
      const seenVersion = appUpdate.seenVersion;
      const latestVersion = appUpdate.info.latestVersion;
      const shouldShow = !seenVersion || latestVersion !== seenVersion;
      const isHighSeverity = appUpdate.info.severity === 'high';
      if (shouldShow && isHighSeverity && shownVersionRef.current !== latestVersion) {
        shownVersionRef.current = latestVersion;
        setUpdateModalVisible(true);
      }
    }
  }, [appUpdate.available, appUpdate.info, appUpdate.seenVersion]);

  const { sessions, activeSessionId } = useSidebar();

  const { openChat, beginNewChat, setSessionError } = useChatSession();

  const handleSessionSelect = useCallback(
    async (id: string) => {
      try {
        setSidebarOpen(false);
        await openChat(id);
      } catch (e: any) {
        setSessionError(e.message || 'Failed to load messages');
      }
    },
    [setSidebarOpen, setSessionError, openChat],
  );

  const handleNewChat = useCallback(async () => {
    try {
      setSidebarOpen(false);
      await beginNewChat();
    } catch (e: any) {
      setSessionError(e.message || 'Failed to create new chat session');
    }
  }, [setSidebarOpen, setSessionError, beginNewChat]);

  const handleModelSelect = useCallback(
    (id: string) => {
      const model = models.find((m) => m.id === id);
      if (model && !model.downloaded && !model.isCloud) {
        setDownloadModalModel(model);
        setModelDropdownOpen(false);
        return;
      }
      try {
        modelDownloadService.setSelectedModelId(id);
      } catch (e) {
        console.warn('Failed to set selected model in store:', e);
      }
      setModelDropdownOpen(false);
    },
    [models, setDownloadModalModel, setModelDropdownOpen],
  );

  return (
    <>
      {sidebarOpen && (
        <ChatSidebar
          sessions={sessions}
          currentSessionId={activeSessionId}
          onClose={() => setSidebarOpen(false)}
          onSessionSelect={handleSessionSelect}
          onNewSession={handleNewChat}
          onSessionDelete={(id) => ChatSessionService.deleteChat(id)}
          onSessionRename={(id, title) =>
            ChatSessionService.renameChat(id, title)
          }
          onSessionPin={(id) => {
            const session = sessions.find((s) => s.id === id);
            ChatSessionService.pinChat(id, !session?.pinned);
          }}
          onSessionArchive={(id) => ChatSessionService.archiveChat(id, true)}
          onSessionShare={(id) => ChatSessionService.shareChat(id)}
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
        onStartDownload={async (model: ModelRecord) => {
          try {
            await modelDownloadService.startDownload(model.id);
            setDownloadModalModel(null);
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

      <VoiceModelModal
        visible={isVoiceModalOpen}
        onClose={() => closeVoiceModal()}
      />

      <LlmModelModal
        visible={isLlmModalOpen}
        onClose={() => setLlmModalOpen(false)}
      />

      <UpdateModal
        visible={updateModalVisible}
        onClose={() => setUpdateModalVisible(false)}
      />
    </>
  );
}
