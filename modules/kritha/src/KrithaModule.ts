import { NativeModule, requireNativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type LocalLlmMessage = {
  role: string;
  content: string;
};

export type LocalLlmGenerateRequest = {
  requestId: string;
  modelPath: string;
  device?: string;
  messages: LocalLlmMessage[];
};

export type LocalLlmDeltaEvent = {
  requestId: string;
  delta: string;
};

export type VoiceModelInfo = {
  id: string;
  name: string;
  size: string;
  langs: string;
  category: 'stt' | 'tts';
  backend: string;
  isDownloaded: boolean;
};

export type VoiceModelProgressEvent = {
  modelId: string;
  progress: number;
};

export type SpeechTextEvent = {
  text?: string;
  isFinal?: boolean;
};

export type SpeechErrorEvent = {
  message?: string;
};

export type KrithaModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onLocalLlmDelta(event: LocalLlmDeltaEvent): void;
  onVoiceModelProgress(event: VoiceModelProgressEvent): void;
  onSpeechStarted(): void;
  onSpeechEnded(): void;
  onTranscript(event: SpeechTextEvent): void;
  onResponseCreated(event: SpeechTextEvent): void;
  onResponseDone(): void;
  onResponseInterrupted(): void;
  onError(event: SpeechErrorEvent): void;
};

declare class KrithaModule extends NativeModule<KrithaModuleEvents> {
  start(): void;
  stop(): void;
  pauseForStt(): void;
  resumeFromStt(): void;
  isRunning(): boolean;
  isDefaultAssistant(): boolean;
  openAssistantSettings(): boolean;
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): boolean;
  generateLocal(request: LocalLlmGenerateRequest): Promise<string>;
  cancelLocalGeneration(requestId: string): boolean;
  soniqoInitialize(
    llmModelPath?: string | null,
    llmDevice?: string | null,
    sttModelId?: string | null,
    ttsModelId?: string | null,
  ): Promise<void>;
  soniqoStart(
    llmModelPath?: string | null,
    llmDevice?: string | null,
  ): Promise<void>;
  soniqoStop(): Promise<void>;
  soniqoSpeak(text: string, voice?: string | null): Promise<void>;
  soniqoStopSpeaking(): Promise<void>;
  soniqoAddTool(name: string, desc: string): Promise<void>;
  listVoiceModels(): Promise<VoiceModelInfo[]>;
  downloadVoiceModel(modelId: string): Promise<void>;
  deleteVoiceModel(modelId: string): Promise<void>;
}

export default requireNativeModule<KrithaModule>('Kritha');
