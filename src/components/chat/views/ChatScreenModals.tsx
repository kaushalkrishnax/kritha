import React, { useCallback } from 'react';
import { ModelSelectModal } from '@/components/chat/modals/ModelSelectModal';
import { PermissionsChecklistModal } from '@/components/chat/modals/PermissionsChecklistModal';
import { VoiceModelModal } from '@/components/chat/modals/VoiceModelModal';
import ChatSidebar from '@/components/chat/ui/ChatSidebar';
import { useChatSession, useSidebar, useSpeaker } from '@/hooks';
import { ChatSessionService, modelDownloadService } from '@/services';
import { useAssistantSessionStore, useModelStore, useVoiceStore } from '@/store';
import { ModelRecord } from '@/types';

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

export function ChatScreenModals({
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
  const isVoiceModalOpen = useVoiceStore((s) => s.isVoiceModalOpen);

  const { sessions, activeSessionId } = useSidebar();
  
  const { openChat, beginNewChat, setSessionError } = useChatSession();

  const handleSessionSelect = useCallback(
    (id: string) => {
      try {
        openChat(id);
        setSidebarOpen(false);
      } catch (e: any) {
        setSessionError(e.message || 'Failed to load messages');
      }
    },
    [setSidebarOpen, setSessionError, openChat],
  );

  const handleNewChat = useCallback(() => {
    try {
      beginNewChat();
      setSidebarOpen(false);
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
    </>
  );
}
