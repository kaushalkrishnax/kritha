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

export type KrithaModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onLocalLlmDelta(event: LocalLlmDeltaEvent): void;
};

declare class KrithaModule extends NativeModule<KrithaModuleEvents> {
  start(): void;
  stop(): void;
  isRunning(): boolean;
  isDefaultAssistant(): boolean;
  openAssistantSettings(): boolean;
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): boolean;
  generateLocal(request: LocalLlmGenerateRequest): Promise<string>;
  cancelLocalGeneration(requestId: string): boolean;
}

export default requireNativeModule<KrithaModule>('Kritha');
