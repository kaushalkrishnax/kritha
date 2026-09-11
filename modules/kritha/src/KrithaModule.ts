import { NativeModule, requireNativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type CanonicalAssistantState =
  | 'IDLE'
  | 'LISTENING'
  | 'TRANSCRIBING'
  | 'THINKING'
  | 'GENERATING'
  | 'SPEAKING'
  | 'CANCELLING'
  | 'ERROR';

export type MicOwner = 'STT' | 'WAKE_WORD' | 'NONE';

export type RequestOrigin = 'MANUAL_TYPING' | 'MANUAL_DICTATION' | 'WAKE_WORD' | 'LIVE_TALK';

export type BaseAssistantEventPayload = {
  chatSessionId?: string;
  assistantRunId?: string;
  requestId?: string;
  origin?: RequestOrigin;
};

export type AssistantEvent =
  | {
      type: 'CHAT_CREATED';
      payload: { chatSessionId: string; title: string; createdAt: number };
    }
  | {
      type: 'CHAT_RENAMED';
      payload: { chatSessionId: string; title: string };
    }
  | {
      type: 'CHAT_PINNED';
      payload: { chatSessionId: string; pinned: boolean };
    }
  | {
      type: 'CHAT_ARCHIVED';
      payload: { chatSessionId: string; archived: boolean };
    }
  | {
      type: 'CHAT_DELETED';
      payload: { chatSessionId: string };
    }
  | {
      type: 'ACTIVE_CHAT_CLEARED';
      payload: {};
    }
  | {
      type: 'MESSAGE_PERSISTED';
      payload: {
        chatSessionId: string;
        messageId: string;
        role: 'user' | 'assistant';
        text: string;
        createdAt: number;
      };
    }
  | { type: 'SESSION_START'; payload: BaseAssistantEventPayload }
  | { type: 'SESSION_END'; payload: BaseAssistantEventPayload }
  | {
      type: 'STATE_CHANGED';
      payload: BaseAssistantEventPayload & {
        state: CanonicalAssistantState;
        transcript?: string;
      };
    }
  | {
      type: 'TEXT_DELTA';
      payload: BaseAssistantEventPayload & {
        messageId: string;
        chunk: string;
      };
    }
  | {
      type: 'TEXT_COMPLETE';
      payload: BaseAssistantEventPayload & {
        messageId: string;
        response: string;
        transcript?: string;
      };
    }
  | {
      type: 'MICROPHONE_CHANGED';
      payload: BaseAssistantEventPayload & {
        owner?: MicOwner;
        isClaimed?: boolean;
        available?: boolean;
        volumeRms?: number;
      };
    }
  | {
      type: 'ERROR';
      payload: BaseAssistantEventPayload & {
        message: string;
      };
    }
  | {
      type: 'VOICE_MODEL_DOWNLOAD_PROGRESS';
      payload: {
        modelType: 'stt' | 'tts' | 'voice';
        progress: number;
        fileName?: string;
      };
    };

export type AssistantCommand =
  | {
      type: 'SUBMIT_TEXT';
      chatSessionId?: string;
      text: string;
      modelId?: string;
      assistantRunId?: string;
      origin?: RequestOrigin;
      history?: Array<Record<string, unknown>>;
    }
  | { type: 'CANCEL'; assistantRunId?: string; requestId?: string }
  | { type: 'DISMISS' }
  | { type: 'OPEN_MAIN_APP' };

export type ModelMetadata = {
  id: string;
  name: string;
  provider: string;
  remoteUrl: string;
  localPath: string;
};

export type NativeChatSession = {
  id: string;
  title: string;
  pinned: number;
  archived: number;
  createdAt: number;
};

export type DownloadProgressEvent = {
  modelId: string;
  downloadedMb: number;
  totalMb: number;
  speedMbps: number;
};

export type KrithaModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onAssistantEvent(event: AssistantEvent): void;
  onDownloadProgress(event: DownloadProgressEvent): void;
};

declare class KrithaModule extends NativeModule<KrithaModuleEvents> {
  dispatchCommand(command: AssistantCommand): boolean;
  getCurrentState(): {
    state: CanonicalAssistantState;
    chatSessionId?: string;
    assistantRunId?: string;
    requestId?: string;
    transcript?: string;
    response?: string;
    ttsState?: { isSpeaking: boolean; isPaused: boolean; messageId?: string };
  };

  // System & Model Utilities
  start(): void;
  stop(): void;
  isRunning(): boolean;
  setBargeInEnabled(enabled: boolean): void;
  setCloudApiKey(apiKey: string): void;
  getCustomInstructions(): string;
  setCustomInstructions(instructions: string): void;
  getUserName(): string;
  setUserName(name: string): void;
  getLocalModelDevice(): 'cpu' | 'gpu';
  setLocalModelDevice(device: 'cpu' | 'gpu'): 'cpu' | 'gpu';
  getAvailableModels(): ModelMetadata[];
  getSelectedModel(): string;
  setSelectedModel(modelId: string): string;
  isModelDownloaded(modelId: string): boolean;
  getDownloadedModels(): string[];
  downloadModel(modelId: string): void;
  pauseDownload(modelId: string): void;
  resumeDownload(modelId: string): void;
  cancelDownload(modelId: string): void;
  isDefaultAssistant(): boolean;
  openAssistantSettings(): boolean;
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): boolean;
}

export default requireNativeModule<KrithaModule>('Kritha');
