import {
  pauseSpeaking as runtimePauseSpeaking,
  resumeSpeaking as runtimeResumeSpeaking,
  speak as runtimeSpeak,
  stopSpeaking as runtimeStopSpeaking,
  subscribeSoniqoSpeechEvents,
  VoiceModelMissingError,
} from '@/services/soniqoRuntime.service';

import { TtsEventListener, TtsProvider, TtsSpeakOptions } from './types';

const listeners = new Set<TtsEventListener>();
let subscribed = false;

function ensureSubscribed(): void {
  if (subscribed) return;
  subscribed = true;
  subscribeSoniqoSpeechEvents((event) => {
    switch (event.kind) {
      case 'ttsStarted':
        listeners.forEach((l) =>
          l({ kind: 'started', requestId: event.requestId }),
        );
        break;
      case 'ttsPaused':
        listeners.forEach((l) =>
          l({ kind: 'paused', requestId: event.requestId }),
        );
        break;
      case 'ttsResumed':
        listeners.forEach((l) =>
          l({ kind: 'resumed', requestId: event.requestId }),
        );
        break;
      case 'ttsCompleted':
        listeners.forEach((l) =>
          l({ kind: 'completed', requestId: event.requestId }),
        );
        break;
      case 'ttsStopped':
        listeners.forEach((l) =>
          l({
            kind: 'stopped',
            requestId: event.requestId,
            replaced: event.replaced,
          }),
        );
        break;
      case 'ttsError':
        listeners.forEach((l) =>
          l({
            kind: 'error',
            requestId: event.requestId,
            message: event.message,
          }),
        );
        break;
      default:
        break;
    }
  });
}

export const soniqoTtsProvider: TtsProvider = {
  speak: async (text: string, options: TtsSpeakOptions): Promise<void> => {
    ensureSubscribed();
    if (!text.trim()) {
      throw new Error('Nothing to speak.');
    }
    try {
      await runtimeSpeak(options.requestId, text, options.voice ?? 'F1');
    } catch (e) {
      if (e instanceof VoiceModelMissingError) {
        throw e;
      }
      throw new Error(
        e instanceof Error ? e.message : 'Failed to start speech playback.',
      );
    }
  },

  pause: async (requestId?: string): Promise<void> => {
    ensureSubscribed();
    await runtimePauseSpeaking(requestId);
  },

  resume: async (requestId?: string): Promise<void> => {
    ensureSubscribed();
    await runtimeResumeSpeaking(requestId);
  },

  stop: async (requestId?: string): Promise<void> => {
    ensureSubscribed();
    await runtimeStopSpeaking(requestId);
  },

  subscribe: (listener: TtsEventListener): (() => void) => {
    ensureSubscribed();
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  },
};
