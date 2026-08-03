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

export { AssistantEvent, WakeWordEvent };
