import { requireNativeModule, NativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type AssistantEvent = {
  state: 'listening' | 'processing' | 'finished' | 'error';
  transcript?: string;
  response?: string;
  error?: string;
};

export type WakeWordModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
  onAssistantEvent(event: AssistantEvent): void;
};

declare class WakeWordModule extends NativeModule<WakeWordModuleEvents> {
  start(): void;
  stop(): void;
  isRunning(): boolean;
  stopAssistantSession(): void;
}

export default requireNativeModule<WakeWordModule>('WakeWord');
