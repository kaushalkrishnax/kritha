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
  fatal?: boolean;
};

export type RuntimeId = 'litert' | 'litert-lm' | 'onnx';

export type LiveTalkTtsMode = 'disabled' | 'after_generation' | 'stream';

export type LiveTalkIntelligenceConfig = {
  kind: 'local' | 'cloud';
  modelId: string;
  modelPath?: string | null;
  device?: string;
  apiKey?: string | null;
};

export type LiveTalkStartConfig = {
  intelligence: LiveTalkIntelligenceConfig;
  context: { role: string; content: string }[];
  tts: {
    enabled: boolean;
    mode: LiveTalkTtsMode;
    voice?: string | null;
  };
  sttModelId?: string | null;
  vad?: {
    speechThreshold?: number;
    silenceThreshold?: number;
    silenceTimeoutMs?: number;
    maxUtteranceMs?: number;
  };
  forceWebRtcAec?: boolean;
};

export type LiveTalkState =
  | 'idle'
  | 'listening'
  | 'user_speaking'
  | 'processing'
  | 'thinking'
  | 'speaking'
  | 'interrupted'
  | 'paused';

export type LiveTalkEvent = {
  type:
    | 'session_started'
    | 'session_stopped'
    | 'state'
    | 'speech_started'
    | 'speech_ended'
    | 'transcription_started'
    | 'transcription_completed'
    | 'thinking_started'
    | 'assistant_text'
    | 'thinking_completed'
    | 'tts_started'
    | 'tts_stopped'
    | 'interrupted'
    | 'audio_level'
    | 'latency'
    | 'error';
  state?: LiveTalkState;
  turnId?: string;
  text?: string;
  delta?: string;
  level?: number;
  interrupted?: boolean;
  aec?: 'android' | 'webrtc' | 'none';
  ttsMode?: string;
  metric?: string;
  ms?: number;
  code?: string;
  message?: string;
};

export type RuntimeInfo = {
  id: string;
  module: string;
  installed: boolean;
  displayName: string;
  description: string;
  capabilities: string[];
};

export type RuntimeInstallResult = {
  id: string;
  module: string;
  installed: boolean;
  providerAvailable: boolean;
  error?: string | null;
  errorCode?: string | null;
};

export type RuntimeInstallProgressEvent = {
  runtimeId: string;
  module: string;
  status: string;
  progress?: number | null;
};

export type KrithaModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onLocalLlmDelta(event: LocalLlmDeltaEvent): void;
  onVoiceModelProgress(event: VoiceModelProgressEvent): void;
  onRuntimeInstallProgress(event: RuntimeInstallProgressEvent): void;
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
  onLiveTalkEvent(event: LiveTalkEvent): void;
};

declare class KrithaModule extends NativeModule<KrithaModuleEvents> {
  start(): void;
  stop(): void;
  pauseForStt(): void;
  resumeFromStt(): void;
  isRunning(): boolean;
  dismissAssistantOverlay(): void;
  openMainApp(): boolean;
  isDefaultAssistant(): boolean;
  openAssistantSettings(): boolean;
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): boolean;
  generateLocal(request: LocalLlmGenerateRequest): Promise<string>;
  cancelLocalGeneration(requestId: string): boolean;
  speechInitialize(
    llmModelPath?: string | null,
    llmDevice?: string | null,
    sttModelId?: string | null,
    ttsModelId?: string | null,
  ): Promise<void>;
  startListening(requestId: string): Promise<void>;
  stopListening(requestId: string): Promise<string>;
  cancelListening(requestId: string): Promise<void>;
  speechStart(
    llmModelPath?: string | null,
    llmDevice?: string | null,
  ): Promise<void>;
  speechStop(): Promise<void>;
  speak(requestId: string, text: string, voice?: string | null): Promise<void>;
  pauseSpeaking(requestId?: string | null): Promise<void>;
  resumeSpeaking(requestId?: string | null): Promise<void>;
  stopSpeaking(requestId?: string | null): Promise<void>;
  addTool(name: string, desc: string): Promise<void>;
  canInstallPackages(): boolean;
  openInstallPermissionSettings(): boolean;
  listRuntimes(): Promise<RuntimeInfo[]>;
  installRuntime(
    runtimeIds: string | string[],
  ): Promise<RuntimeInstallResult[]>;
  listVoiceModels(): Promise<VoiceModelInfo[]>;
  downloadVoiceModel(modelId: string): Promise<void>;
  deleteVoiceModel(modelId: string): Promise<void>;
  startLiveTalk(config: LiveTalkStartConfig): Promise<void>;
  stopLiveTalk(): Promise<void>;
  interruptLiveTalk(): void;
  pauseLiveTalkSession(): void;
  resumeLiveTalkSession(): void;
  setLiveTalkContext(messages: { role: string; content: string }[]): void;
  isLiveTalkActive(): boolean;
}

export default requireNativeModule<KrithaModule>('Kritha');
