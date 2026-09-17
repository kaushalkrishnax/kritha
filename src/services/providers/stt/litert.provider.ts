import {
  cancelListening as runtimeCancelListening,
  startListening as runtimeStartListening,
  stopListening as runtimeStopListening,
  subscribeSpeechRuntimeEvents,
  VoiceModelMissingError,
} from '@/services/speechRuntime.service';
import uuid from 'react-native-uuid';

import { SttProvider, SttResult, SttStartOptions } from './types';

let activeRequestId: string | null = null;
let partialHandler: ((text: string, requestId: string) => void) | null = null;
let audioLevelHandler: ((level: number, requestId: string) => void) | null =
  null;
let subscribed = false;

function ensureSubscribed(): void {
  if (subscribed) return;
  subscribed = true;
  subscribeSpeechRuntimeEvents((event) => {
    if (event.kind === 'transcript') {
      if (event.requestId !== activeRequestId) return;
      if (!event.isFinal) {
        partialHandler?.(event.text, event.requestId);
      }
      return;
    }
    if (event.kind === 'audioLevel') {
      if (event.requestId !== activeRequestId) return;
      audioLevelHandler?.(event.level, event.requestId);
    }
  });
}

export const lrtSttProvider: SttProvider = {
  startListening: async (options?: SttStartOptions): Promise<string> => {
    ensureSubscribed();
    if (activeRequestId !== null) {
      throw new Error('STT capture already active.');
    }
    const requestId = String(uuid.v4());
    partialHandler = options?.onPartial ?? null;
    audioLevelHandler = options?.onAudioLevel ?? null;
    try {
      await runtimeStartListening(requestId);
    } catch (e) {
      partialHandler = null;
      audioLevelHandler = null;
      if (e instanceof VoiceModelMissingError) {
        throw e;
      }
      throw new Error(
        e instanceof Error ? e.message : 'Failed to start microphone capture.',
      );
    }
    activeRequestId = requestId;
    return requestId;
  },

  stopListening: async (): Promise<SttResult> => {
    const requestId = activeRequestId;
    if (requestId === null) {
      return { requestId: '', text: '' };
    }
    try {
      const text = await runtimeStopListening(requestId);
      return { requestId, text: (text ?? '').trim() };
    } catch (e) {
      throw new Error(
        e instanceof Error ? e.message : 'Failed to transcribe recording.',
      );
    } finally {
      if (activeRequestId === requestId) {
        activeRequestId = null;
      }
      partialHandler = null;
      audioLevelHandler = null;
    }
  },

  cancelListening: async (): Promise<void> => {
    const requestId = activeRequestId;
    activeRequestId = null;
    partialHandler = null;
    audioLevelHandler = null;
    if (requestId === null) return;
    await runtimeCancelListening(requestId);
  },
};
