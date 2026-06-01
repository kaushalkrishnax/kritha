import { EventSubscription } from 'expo-modules-core';
import WakeWordNativeModule, { WakeWordEvent } from './WakeWordModule';

const emitter = WakeWordNativeModule;

export function start(): void {
  WakeWordNativeModule.start();
}

export function stop(): void {
  WakeWordNativeModule.stop();
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

export { WakeWordEvent };