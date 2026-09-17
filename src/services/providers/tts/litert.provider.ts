import {
  pauseSpeaking as runtimePauseSpeaking,
  resumeSpeaking as runtimeResumeSpeaking,
  speak as runtimeSpeak,
  stopSpeaking as runtimeStopSpeaking,
  subscribeSpeechRuntimeEvents,
  VoiceModelMissingError,
} from '@/services/speechRuntime.service';

import { TtsEventListener, TtsProvider, TtsSpeakOptions } from './types';

const listeners = new Set<TtsEventListener>();
let subscribed = false;

function ensureSubscribed(): void {
  if (subscribed) return;
  subscribed = true;
  console.log('[TTS_DEBUG] litert.provider: subscribing to speechRuntime events');
  subscribeSpeechRuntimeEvents((event) => {
    console.log('[TTS_DEBUG] litert.provider: received speechRuntime event', event);
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

export const lrtTtsProvider: TtsProvider = {
  speak: async (text: string, options: TtsSpeakOptions): Promise<void> => {
    console.log('[TTS_DEBUG] litert.provider: speak called', {
      textPreview: text?.slice(0, 50),
      options,
    });
    ensureSubscribed();
    if (!text.trim()) {
      console.warn('[TTS_DEBUG] litert.provider: text is empty');
      throw new Error('Nothing to speak.');
    }
    try {
      console.log('[TTS_DEBUG] litert.provider: calling runtimeSpeak with voice', options.voice ?? 'F1');
      await runtimeSpeak(options.requestId, text, options.voice ?? 'F1');
      console.log('[TTS_DEBUG] litert.provider: runtimeSpeak finished successfully');
    } catch (e) {
      console.error('[TTS_DEBUG] litert.provider: runtimeSpeak threw error', e);
      if (e instanceof VoiceModelMissingError) {
        throw e;
      }
      throw new Error(
        e instanceof Error ? e.message : 'Failed to start speech playback.',
      );
    }
  },

  pause: async (requestId?: string): Promise<void> => {
    console.log('[TTS_DEBUG] litert.provider: pause called', { requestId });
    ensureSubscribed();
    await runtimePauseSpeaking(requestId);
  },

  resume: async (requestId?: string): Promise<void> => {
    console.log('[TTS_DEBUG] litert.provider: resume called', { requestId });
    ensureSubscribed();
    await runtimeResumeSpeaking(requestId);
  },

  stop: async (requestId?: string): Promise<void> => {
    console.log('[TTS_DEBUG] litert.provider: stop called', { requestId });
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
