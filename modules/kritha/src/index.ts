import { EventSubscription } from 'expo-modules-core';
import KrithaNativeModule, {
  AssistantEvent,
  WakeWordEvent,
} from './KrithaModule';

const emitter = KrithaNativeModule;

export function start(): void {
  KrithaNativeModule.start();
}

export function stop(): void {
  KrithaNativeModule.stop();
}

export function isRunning(): boolean {
  return KrithaNativeModule.isRunning();
}

export function getLocalModelDevice(): 'cpu' | 'gpu' {
  return KrithaNativeModule.getLocalModelDevice();
}

export function setLocalModelDevice(device: 'cpu' | 'gpu'): 'cpu' | 'gpu' {
  return KrithaNativeModule.setLocalModelDevice(device);
}

export function setCloudApiKey(apiKey: string): void {
  KrithaNativeModule.setCloudApiKey(apiKey);
}

export function stopGeneration(): void {
  KrithaNativeModule.stopGeneration();
}

export function stopAssistantSession(): void {
  KrithaNativeModule.stopAssistantSession();
}

export function triggerAssistantSession(): void {
  KrithaNativeModule.triggerAssistantSession();
}

export function dispatchMediaKey(keyCode: number): void {
  KrithaNativeModule.dispatchMediaKey(keyCode);
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void,
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

export function addAssistantListener(
  listener: (event: AssistantEvent) => void,
): EventSubscription {
  return emitter.addListener('onAssistantEvent', listener);
}

export function respondToAssistant(response: string): void {
  KrithaNativeModule.respondToAssistant(response);
}

export function toggleFlashlight(enable: boolean): void {
  KrithaNativeModule.toggleFlashlight(enable);
}

export function getVolume(): number {
  return KrithaNativeModule.getVolume();
}

export function setVolume(level: number): void {
  KrithaNativeModule.setVolume(level);
}

export function getBatteryStatus(): { level: number; isCharging: boolean } {
  return KrithaNativeModule.getBatteryStatus();
}

export function setWifi(enable: boolean): void {
  KrithaNativeModule.setWifi(enable);
}

export function setBluetooth(enable: boolean): void {
  KrithaNativeModule.setBluetooth(enable);
}

export function setAlarm(hour: number, minute: number, message: string): void {
  KrithaNativeModule.setAlarm(hour, minute, message);
}

export function setTimer(durationSeconds: number, message: string): void {
  KrithaNativeModule.setTimer(durationSeconds, message);
}

export function openApp(appName: string): boolean {
  return KrithaNativeModule.openApp(appName);
}

export function callContact(contactName: string): {
  success: boolean;
  resolvedName: string;
} {
  return KrithaNativeModule.callContact(contactName);
}

export function sendSMS(
  contactName: string,
  message: string,
): { success: boolean; resolvedName: string } {
  return KrithaNativeModule.sendSMS(contactName, message);
}

export function isNotificationListenerEnabled(): boolean {
  return KrithaNativeModule.isNotificationListenerEnabled();
}

export function requestNotificationListenerPermission(): void {
  KrithaNativeModule.requestNotificationListenerPermission();
}

export function readNotifications(): Array<{
  packageName: string;
  title: string;
  text: string;
}> {
  return KrithaNativeModule.readNotifications();
}

export function getCalendarEvents(): Array<{
  title: string;
  startTime: number;
  description: string;
}> {
  return KrithaNativeModule.getCalendarEvents();
}

export function openAssistantSettings(): boolean {
  return KrithaNativeModule.openAssistantSettings();
}

export { AssistantEvent, WakeWordEvent };
