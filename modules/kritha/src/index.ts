import { EventSubscription } from 'expo-modules-core';
import KrithaModule, {
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  WakeWordEvent,
} from './KrithaModule';

const emitter = KrithaModule;

export function generateLocal(
  request: LocalLlmGenerateRequest,
): Promise<string> {
  return KrithaModule.generateLocal(request);
}

export function cancelLocalGeneration(requestId: string): boolean {
  return KrithaModule.cancelLocalGeneration(requestId);
}

export function addLocalLlmDeltaListener(
  listener: (event: LocalLlmDeltaEvent) => void,
): EventSubscription {
  return emitter.addListener('onLocalLlmDelta', listener);
}

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
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  WakeWordEvent,
};
