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
  requestId?: string;
  text?: string;
  isFinal?: boolean;
};

export type SpeechRequestEvent = {
  requestId: string;
};

export type SpeechAudioLevelEvent = {
  requestId?: string;
  level?: number;
};

export type SpeechStoppedEvent = {
  requestId: string;
  text?: string;
  replaced?: boolean;
};

export type SpeechErrorEvent = {
  requestId?: string;
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
  onResponseDone(event: SpeechTextEvent): void;
  onResponseInterrupted(event: SpeechTextEvent): void;
  onError(event: SpeechErrorEvent): void;
  onSttStarted(event: SpeechRequestEvent): void;
  onSttStopped(event: SpeechStoppedEvent): void;
  onSttCancelled(event: SpeechRequestEvent): void;
  onSttError(event: SpeechErrorEvent): void;
  onAudioLevel(event: SpeechAudioLevelEvent): void;
  onTtsStarted(event: SpeechRequestEvent): void;
  onTtsPaused(event: SpeechRequestEvent): void;
  onTtsResumed(event: SpeechRequestEvent): void;
  onTtsCompleted(event: SpeechRequestEvent): void;
  onTtsStopped(event: SpeechStoppedEvent): void;
  onTtsError(event: SpeechErrorEvent): void;
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
  soniqoStartListening(requestId: string): Promise<void>;
  soniqoStopListening(requestId: string): Promise<string>;
  soniqoCancelListening(requestId: string): Promise<void>;
  soniqoStart(
    llmModelPath?: string | null,
    llmDevice?: string | null,
  ): Promise<void>;
  soniqoStop(): Promise<void>;
  soniqoSpeak(
    requestId: string,
    text: string,
    voice?: string | null,
  ): Promise<void>;
  soniqoPauseSpeaking(requestId?: string | null): Promise<void>;
  soniqoResumeSpeaking(requestId?: string | null): Promise<void>;
  soniqoStopSpeaking(requestId?: string | null): Promise<void>;
  soniqoAddTool(name: string, desc: string): Promise<void>;
  listVoiceModels(): Promise<VoiceModelInfo[]>;
  downloadVoiceModel(modelId: string): Promise<void>;
  deleteVoiceModel(modelId: string): Promise<void>;
}

export default requireNativeModule<KrithaModule>('Kritha');
