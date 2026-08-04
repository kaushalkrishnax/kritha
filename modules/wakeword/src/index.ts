import { EventSubscription } from 'expo-modules-core';
import WakeWordNativeModule, {
  AssistantEvent,
  WakeWordEvent,
} from './WakeWordModule';

const emitter = WakeWordNativeModule;

export function start(): void {
  WakeWordNativeModule.start();
}

export function stop(): void {
  WakeWordNativeModule.stop();
}

export function isRunning(): boolean {
  return WakeWordNativeModule.isRunning();
}

export function stopAssistantSession(): void {
  WakeWordNativeModule.stopAssistantSession();
}

export function dispatchMediaKey(keyCode: number): void {
  WakeWordNativeModule.dispatchMediaKey(keyCode);
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

export function addAssistantListener(
  listener: (event: AssistantEvent) => void
): EventSubscription {
  return emitter.addListener('onAssistantEvent', listener);
}

export function respondToAssistant(response: string): void {
  WakeWordNativeModule.respondToAssistant(response);
}

export function toggleFlashlight(enable: boolean): void {
  WakeWordNativeModule.toggleFlashlight(enable);
}

export function getVolume(): number {
  return WakeWordNativeModule.getVolume();
}

export function setVolume(level: number): void {
  WakeWordNativeModule.setVolume(level);
}

export function getBatteryStatus(): { level: number; isCharging: boolean } {
  return WakeWordNativeModule.getBatteryStatus();
}

export function setWifi(enable: boolean): void {
  WakeWordNativeModule.setWifi(enable);
}

export function setBluetooth(enable: boolean): void {
  WakeWordNativeModule.setBluetooth(enable);
}

export function setAlarm(hour: number, minute: number, message: string): void {
  WakeWordNativeModule.setAlarm(hour, minute, message);
}

export function setTimer(durationSeconds: number, message: string): void {
  WakeWordNativeModule.setTimer(durationSeconds, message);
}

export function openApp(appName: string): boolean {
  return WakeWordNativeModule.openApp(appName);
}

export function callContact(contactName: string): { success: boolean; resolvedName: string } {
  return WakeWordNativeModule.callContact(contactName);
}

export function sendSMS(contactName: string, message: string): { success: boolean; resolvedName: string } {
  return WakeWordNativeModule.sendSMS(contactName, message);
}

export function isNotificationListenerEnabled(): boolean {
  return WakeWordNativeModule.isNotificationListenerEnabled();
}

export function requestNotificationListenerPermission(): void {
  WakeWordNativeModule.requestNotificationListenerPermission();
}

export function readNotifications(): Array<{ packageName: string; title: string; text: string }> {
  return WakeWordNativeModule.readNotifications();
}

export function getCalendarEvents(): Array<{ title: string; startTime: number; description: string }> {
  return WakeWordNativeModule.getCalendarEvents();
}

export { AssistantEvent, WakeWordEvent };
