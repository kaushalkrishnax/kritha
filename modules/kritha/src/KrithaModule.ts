import { NativeModule, requireNativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type AssistantEvent = {
  state:
    | 'listening'
    | 'partial'
    | 'rms'
    | 'processing'
    | 'streaming'
    | 'finished'
    | 'error'
    | 'tts_start'
    | 'tts_pause'
    | 'tts_done';
  transcript?: string;
  response?: string;
  chunk?: string;
  error?: string;
  rms?: number;
};

export type ModelMetadata = {
  id: string;
  name: string;
  provider: string;
  remoteUrl: string;
  localPath: string;
};

export type KrithaModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onAssistantEvent(event: AssistantEvent): void;
  onDownloadProgress(event: {
    modelId: string;
    downloadedMb: number;
    totalMb: number;
    speedMbps: number;
  }): void;
  onDictationVolume(event: { volume: number }): void;
  onDictationPartial(event: { text: string }): void;
};

declare class KrithaModule extends NativeModule<KrithaModuleEvents> {
  start(): void;
  stop(): void;
  isRunning(): boolean;
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
  generateLocalResponse(prompt: string, modelId?: string): Promise<string>;
  setCloudApiKey(apiKey: string): void;
  stopGeneration(): void;
  stopAssistantSession(): void;
  openMainApp(): void;
  triggerAssistantSession(): void;
  sendToAssistant(text: string, autoTts: boolean): void;
  speakText(text: string): void;
  speakChunk(chunk: string): void;
  flushTts(): void;
  pauseTts(): void;
  resumeTts(): void;
  replayTts(): void;
  stopTts(): void;
  startDictation(): Promise<string>;
  stopDictation(): void;
  cancelDictation(): void;
  dispatchMediaKey(keyCode: number): void;
  respondToAssistant(response: string): void;
  toggleFlashlight(enable: boolean): void;
  getVolume(): number;
  setVolume(level: number): void;
  getBatteryStatus(): { level: number; isCharging: boolean };
  setWifi(enable: boolean): void;
  setBluetooth(enable: boolean): void;
  setAlarm(hour: number, minute: number, message: string): void;
  setTimer(durationSeconds: number, message: string): void;
  openApp(appName: string): boolean;
  callContact(contactName: string): { success: boolean; resolvedName: string };
  sendSMS(
    contactName: string,
    message: string,
  ): { success: boolean; resolvedName: string };
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): void;
  readNotifications(): Array<{
    packageName: string;
    title: string;
    text: string;
  }>;
  getCalendarEvents(): Array<{
    title: string;
    startTime: number;
    description: string;
  }>;
  openAssistantSettings(): boolean;
}

export default requireNativeModule<KrithaModule>('Kritha');
