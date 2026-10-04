import { EventSubscription } from 'expo-modules-core';
import { AppState, AppStateStatus, NativeEventSubscription } from 'react-native';

import {
  KrithaLiveTalk,
  LiveTalkEvent,
  LiveTalkStartConfig,
} from '@modules/kritha/src';

export type LiveTalkEventHandler = (event: LiveTalkEvent) => void;

let subscription: EventSubscription | null = null;
let appStateSubscription: NativeEventSubscription | null = null;
let handler: LiveTalkEventHandler | null = null;

function ensureSubscription(): void {
  if (subscription) return;
  subscription = KrithaLiveTalk.addListener((event) => {
    handler?.(event);
  });
}

export const liveTalkService = {
  configureHandler(next: LiveTalkEventHandler): void {
    handler = next;
  },

  /**
   * The session has no foreground service, so a backgrounded app loses mic
   * access; stop to a clean IDLE instead of dying mid-capture (spec §17).
   */
  enableBackgroundStop(onBackground: () => void): void {
    if (appStateSubscription) return;
    appStateSubscription = AppState.addEventListener(
      'change',
      (status: AppStateStatus) => {
        if (status !== 'background') return;
        if (!KrithaLiveTalk.isActive()) return;
        onBackground();
      },
    );
  },

  async start(config: LiveTalkStartConfig): Promise<void> {
    ensureSubscription();
    await KrithaLiveTalk.start(config);
  },

  async stop(): Promise<void> {
    if (!KrithaLiveTalk.isActive()) return;
    await KrithaLiveTalk.stop();
  },

  interrupt(): void {
    if (!KrithaLiveTalk.isActive()) return;
    KrithaLiveTalk.interrupt();
  },

  pause(): void {
    if (!KrithaLiveTalk.isActive()) return;
    KrithaLiveTalk.pause();
  },

  resume(): void {
    if (!KrithaLiveTalk.isActive()) return;
    KrithaLiveTalk.resume();
  },

  setContext(messages: { role: string; content: string }[]): void {
    if (!KrithaLiveTalk.isActive()) return;
    KrithaLiveTalk.setContext(messages);
  },

  isActive(): boolean {
    return KrithaLiveTalk.isActive();
  },
};
