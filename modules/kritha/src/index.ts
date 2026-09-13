import { EventSubscription } from 'expo-modules-core';
import KrithaModule, {
  WakeWordEvent,
} from './KrithaModule';

const emitter = KrithaModule;

export function start(): void {
  KrithaModule.start();
}

export function stop(): void {
  KrithaModule.stop();
}

export function isRunning(): boolean {
  return KrithaModule.isRunning();
}

export function isDefaultAssistant(): boolean {
  return KrithaModule.isDefaultAssistant();
}

export function openAssistantSettings(): boolean {
  return KrithaModule.openAssistantSettings();
}

export function isNotificationListenerEnabled(): boolean {
  return KrithaModule.isNotificationListenerEnabled
    ? KrithaModule.isNotificationListenerEnabled()
    : false;
}

export function requestNotificationListenerPermission(): boolean {
  return KrithaModule.requestNotificationListenerPermission
    ? KrithaModule.requestNotificationListenerPermission()
    : false;
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void,
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

export {
  WakeWordEvent
};

