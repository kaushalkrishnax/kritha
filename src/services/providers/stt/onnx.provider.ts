import uuid from 'react-native-uuid';

import {
  cancelListening as runtimeCancelListening,
  startListening as runtimeStartListening,
  stopListening as runtimeStopListening,
  subscribeSpeechRuntimeEvents,
  VoiceModelMissingError,
} from '@/services/speechRuntime.service';

import { SttProvider, SttResult, SttStartOptions } from './types';

let activeRequestId: string | null = null;
let partialHandler: ((text: string, requestId: string) => void) | null = null;
let audioLevelHandler: ((level: number, requestId: string) => void) | null =
  null;
let errorHandler: ((message: string, fatal: boolean) => void) | null = null;
let lastErrorMessage: string | null = null;
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
      return;
    }
    if (event.kind === 'sttError') {
      // Only errors for the in-flight capture; module-level errors carry a
      // null requestId (e.g. model download failures) and are handled elsewhere.
      if (event.requestId !== activeRequestId) return;
      lastErrorMessage = event.message;
      errorHandler?.(event.message, event.fatal);
    }
  });
}

export const onnxSttProvider: SttProvider = {
  startListening: async (options?: SttStartOptions): Promise<string> => {
    ensureSubscribed();
    if (activeRequestId !== null) {
      throw new Error('STT capture already active.');
    }
    const requestId = String(uuid.v4());
    // Accept events for this request immediately: the native side emits
    // onSttStarted (and possibly errors) before the start promise resolves.
    activeRequestId = requestId;
    partialHandler = options?.onPartial ?? null;
    audioLevelHandler = options?.onAudioLevel ?? null;
    errorHandler = options?.onError ?? null;
    lastErrorMessage = null;
    try {
      await runtimeStartListening(requestId);
    } catch (e) {
      activeRequestId = null;
      partialHandler = null;
      audioLevelHandler = null;
      errorHandler = null;
      lastErrorMessage = null;
      if (e instanceof VoiceModelMissingError) {
        throw e;
      }
      throw new Error(
        e instanceof Error ? e.message : 'Failed to start microphone capture.',
      );
    }
    return requestId;
  },

  stopListening: async (): Promise<SttResult> => {
    const requestId = activeRequestId;
    if (requestId === null) {
      return { requestId: '', text: '' };
    }
    try {
      const text = await runtimeStopListening(requestId);
      const trimmed = (text ?? '').trim();
      if (!trimmed && lastErrorMessage) {
        // Capture died before anything was transcribed — surface the cause
        // instead of silently returning an empty transcript.
        throw new Error(lastErrorMessage);
      }
      return { requestId, text: trimmed };
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
      errorHandler = null;
      lastErrorMessage = null;
    }
  },

  cancelListening: async (): Promise<void> => {
    const requestId = activeRequestId;
    activeRequestId = null;
    partialHandler = null;
    audioLevelHandler = null;
    errorHandler = null;
    lastErrorMessage = null;
    if (requestId === null) return;
    await runtimeCancelListening(requestId);
  },
};
