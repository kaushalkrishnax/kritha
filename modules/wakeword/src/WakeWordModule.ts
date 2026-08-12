import { requireNativeModule, NativeModule } from 'expo-modules-core';

export type WakeWordEvent = {
  keyword: string;
  confidence?: number;
};

export type AssistantEvent = {
  state: 'listening' | 'processing' | 'finished' | 'error' | 'needs_cloud';
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
  triggerAssistantSession(): void;
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
  sendSMS(contactName: string, message: string): { success: boolean; resolvedName: string };
  isNotificationListenerEnabled(): boolean;
  requestNotificationListenerPermission(): void;
  readNotifications(): Array<{ packageName: string; title: string; text: string }>;
  getCalendarEvents(): Array<{ title: string; startTime: number; description: string }>;
}

export default requireNativeModule<WakeWordModule>('WakeWord');
