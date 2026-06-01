import { requireNativeModule, NativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type WakeWordModuleEvents = {
  onWakeWordDetected(event: WakeWordEvent): void;
};

declare class WakeWordModule extends NativeModule<WakeWordModuleEvents> {
  start(): void;
  stop(): void;
}

export default requireNativeModule<WakeWordModule>('WakeWord');