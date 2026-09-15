import { useAssistantStore } from '@/stores/assistant.store';
import { useModelStore } from '@/stores/model.store';
import { useVoiceStore } from '@/stores/voice.store';
import { SoniqoSpeech, SpeechEvent } from '@modules/kritha/src';

import { modelDownloadService } from './model.service';

export type SoniqoSttEvent =
  | { kind: 'sttStarted'; requestId: string }
  | { kind: 'transcript'; requestId: string; text: string; isFinal: boolean }
  | { kind: 'sttStopped'; requestId: string; text: string }
  | { kind: 'sttCancelled'; requestId: string }
  | { kind: 'sttError'; requestId: string | null; message: string }
  | { kind: 'audioLevel'; requestId: string; level: number };

export type SoniqoTtsEvent =
  | { kind: 'ttsStarted'; requestId: string }
  | { kind: 'ttsPaused'; requestId: string }
  | { kind: 'ttsResumed'; requestId: string }
  | { kind: 'ttsCompleted'; requestId: string }
  | { kind: 'ttsStopped'; requestId: string; replaced?: boolean }
  | { kind: 'ttsError'; requestId: string | null; message: string };

export type SoniqoSpeechEvent = SoniqoSttEvent | SoniqoTtsEvent;

export type SoniqoSpeechListener = (event: SoniqoSpeechEvent) => void;

export interface VoiceModelStatus {
  id: string;
  name: string;
  size: string;
  langs: string;
  category: string;
  backend?: string;
  isDownloaded: boolean;
}

export class VoiceModelMissingError extends Error {
  readonly modelType: 'stt' | 'tts';
  readonly modelId: string | null;

  constructor(modelType: 'stt' | 'tts', modelId: string | null) {
    super(
      modelType === 'stt'
        ? 'STT model not downloaded. Please download it from Voice Models.'
        : 'TTS model not downloaded. Please download it from Voice Models.',
    );
    this.name = 'VoiceModelMissingError';
    this.modelType = modelType;
    this.modelId = modelId;
  }
}

const listeners = new Set<SoniqoSpeechListener>();
let nativeListenersAttached = false;
let initializedSelections: { stt: string | null; tts: string | null } | null =
  null;
const pendingModelLoads = { stt: 0, tts: 0 };

function beginModelLoad(forCapability: 'stt' | 'tts' | 'both'): void {
  const store = useAssistantStore.getState();
  if (forCapability === 'stt' || forCapability === 'both') {
    pendingModelLoads.stt += 1;
    store.setSttModelLoading(true);
  }
  if (forCapability === 'tts' || forCapability === 'both') {
    pendingModelLoads.tts += 1;
    store.setTtsModelLoading(true);
  }
}

function endModelLoad(forCapability: 'stt' | 'tts' | 'both'): void {
  const store = useAssistantStore.getState();
  if (forCapability === 'stt' || forCapability === 'both') {
    pendingModelLoads.stt = Math.max(0, pendingModelLoads.stt - 1);
    if (pendingModelLoads.stt === 0) store.setSttModelLoading(false);
  }
  if (forCapability === 'tts' || forCapability === 'both') {
    pendingModelLoads.tts = Math.max(0, pendingModelLoads.tts - 1);
    if (pendingModelLoads.tts === 0) store.setTtsModelLoading(false);
  }
}

function emit(event: SoniqoSpeechEvent): void {
  listeners.forEach((listener) => {
    try {
      listener(event);
    } catch (e) {
      console.warn('[soniqoRuntime] speech listener threw', e);
    }
  });
}

function attachNativeListeners(): void {
  if (nativeListenersAttached) return;
  nativeListenersAttached = true;

  SoniqoSpeech.addSttStartedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttStarted', requestId: e.requestId });
  });

  SoniqoSpeech.addTranscriptListener((e: SpeechEvent) => {
    if (!e?.requestId || typeof e.text !== 'string') return;
    emit({
      kind: 'transcript',
      requestId: e.requestId,
      text: e.text,
      isFinal: e.isFinal === true,
    });
  });

  SoniqoSpeech.addSttStoppedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttStopped', requestId: e.requestId, text: e.text ?? '' });
  });

  SoniqoSpeech.addSttCancelledListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttCancelled', requestId: e.requestId });
  });

  SoniqoSpeech.addSttErrorListener((e: SpeechEvent) => {
    emit({
      kind: 'sttError',
      requestId: e?.requestId ?? null,
      message: e?.message || e?.text || 'Speech recognition failed.',
    });
  });

  SoniqoSpeech.addAudioLevelListener((e: SpeechEvent) => {
    if (!e?.requestId || typeof e.level !== 'number') return;
    emit({
      kind: 'audioLevel',
      requestId: e.requestId,
      level: Math.max(0, Math.min(1, e.level)),
    });
  });

  SoniqoSpeech.addTtsStartedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'ttsStarted', requestId: e.requestId });
  });

  SoniqoSpeech.addTtsPausedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'ttsPaused', requestId: e.requestId });
  });

  SoniqoSpeech.addTtsResumedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'ttsResumed', requestId: e.requestId });
  });

  SoniqoSpeech.addTtsCompletedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'ttsCompleted', requestId: e.requestId });
  });

  SoniqoSpeech.addTtsStoppedListener((e: SpeechEvent) => {
    if (!e?.requestId) return;
    emit({
      kind: 'ttsStopped',
      requestId: e.requestId,
      replaced: e.replaced === true,
    });
  });

  SoniqoSpeech.addTtsErrorListener((e: SpeechEvent) => {
    emit({
      kind: 'ttsError',
      requestId: e?.requestId ?? null,
      message: e?.message || e?.text || 'Speech playback failed.',
    });
  });

  SoniqoSpeech.addErrorListener((e: any) => {
    const message =
      typeof e?.message === 'string' && e.message
        ? e.message
        : 'Speech engine error.';
    emit({ kind: 'sttError', requestId: e?.requestId ?? null, message });
  });
}

/**
 * Subscribe to normalized speech events.
 */
export function subscribeSoniqoSpeechEvents(
  listener: SoniqoSpeechListener,
): () => void {
  attachNativeListeners();
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

async function assertModelsDownloaded(
  sttModelId: string | null,
  ttsModelId: string | null,
  forCapability: 'stt' | 'tts' | 'both',
): Promise<void> {
  const models = await SoniqoSpeech.listVoiceModels();
  if (forCapability === 'stt' || forCapability === 'both') {
    const stt = models.find((m) => m.id === sttModelId);
    if (!sttModelId || !stt?.isDownloaded) {
      throw new VoiceModelMissingError('stt', sttModelId);
    }
  }
  if (forCapability === 'tts' || forCapability === 'both') {
    const tts = models.find((m) => m.id === ttsModelId);
    if (!ttsModelId || !tts?.isDownloaded) {
      throw new VoiceModelMissingError('tts', ttsModelId);
    }
  }
}

export async function ensureSoniqoInitialized(
  forCapability: 'stt' | 'tts' | 'both' = 'both',
): Promise<void> {
  attachNativeListeners();
  const sttModelId = useVoiceStore.getState().selectedSttModelId;
  const ttsModelId = useVoiceStore.getState().selectedTtsModelId;

  await assertModelsDownloaded(sttModelId, ttsModelId, forCapability);

  const selectionsMatch =
    initializedSelections !== null &&
    initializedSelections.stt === sttModelId &&
    initializedSelections.tts === ttsModelId;
  if (selectionsMatch) return;

  const modelId = useModelStore.getState().selectedModelId;
  const modelPath = await modelDownloadService.getDownloadedModelPath(modelId);

  beginModelLoad(forCapability);
  try {
    await SoniqoSpeech.initialize({
      llmModelPath: modelPath ?? undefined,
      llmDevice: 'cpu',
      sttModelId: sttModelId ?? undefined,
      ttsModelId: ttsModelId ?? undefined,
    });
    initializedSelections = { stt: sttModelId, tts: ttsModelId };
  } finally {
    endModelLoad(forCapability);
  }
}

/** Start real microphone capture for one dictation operation. */
export async function startListening(requestId: string): Promise<void> {
  await ensureSoniqoInitialized('stt');
  await SoniqoSpeech.startListening(requestId);
}

/**
 * Stop capture and await the real final transcription.
 */
export async function stopListening(requestId: string): Promise<string> {
  return await SoniqoSpeech.stopListening(requestId);
}

/** Abandon capture without producing a transcript. */
export async function cancelListening(requestId: string): Promise<void> {
  try {
    await SoniqoSpeech.cancelListening(requestId);
  } catch (e) {
    console.warn('[soniqoRuntime] cancelListening failed', e);
  }
}

export async function speak(
  requestId: string,
  text: string,
  voice?: string | null,
): Promise<void> {
  await ensureSoniqoInitialized('tts');
  await SoniqoSpeech.speak(requestId, text, voice ?? 'F1');
}

/** Hold playback at the current position (never restarts). */
export async function pauseSpeaking(requestId?: string): Promise<void> {
  await SoniqoSpeech.pauseSpeaking(requestId ?? null);
}

/** Continue from the held position. */
export async function resumeSpeaking(requestId?: string): Promise<void> {
  await SoniqoSpeech.resumeSpeaking(requestId ?? null);
}

/** Stop playback. Completion must not be inferred from a stop. */
export async function stopSpeaking(requestId?: string): Promise<void> {
  try {
    await SoniqoSpeech.stopSpeaking(requestId ?? null);
  } catch (e) {
    console.warn('[soniqoRuntime] stopSpeaking failed', e);
  }
}

/** Tear down mic capture and playback resources. */
export async function shutdownSpeech(): Promise<void> {
  try {
    await SoniqoSpeech.stop();
  } catch (e) {
    console.warn('[soniqoRuntime] shutdown failed', e);
  }
}

export async function listVoiceModels(): Promise<VoiceModelStatus[]> {
  return (await SoniqoSpeech.listVoiceModels()) as VoiceModelStatus[];
}

export async function downloadVoiceModel(modelId: string): Promise<void> {
  await SoniqoSpeech.downloadVoiceModel(modelId);
}

export async function deleteVoiceModel(modelId: string): Promise<void> {
  await SoniqoSpeech.deleteVoiceModel(modelId);
}

export function subscribeVoiceModelProgress(
  listener: (event: { modelId: string; progress: number }) => void,
): () => void {
  const sub = SoniqoSpeech.addVoiceModelProgressListener(listener);
  return () => sub.remove();
}

let _isSessionActive = false;

export const SoniqoCoordinator = {
  async init(): Promise<boolean> {
    try {
      await ensureSoniqoInitialized('both');
      attachNativeListeners();
      return true;
    } catch (e) {
      if (e instanceof VoiceModelMissingError) {
        useVoiceStore.getState().setVoiceModalOpen(true);
        return false;
      }
      console.error('Failed to initialize Soniqo', e);
      return false;
    }
  },

  async handleWakeWordDetected() {
    if (_isSessionActive) return;
    try {
      const { useAssistantStore } = await import('@/stores/assistant.store');
      const { ChatMode, LiveTalkPhase, MicOwner } = await import('@/constants');
      const ready = await this.init();
      if (!ready) return;

      _isSessionActive = true;

      const { pauseForStt } = await import('@modules/kritha/src');
      pauseForStt();

      SoniqoSpeech.addTool('torch', 'Turn flashlight on or off');
      SoniqoSpeech.addTool('mute', 'Mute or unmute device volume');
      SoniqoSpeech.addTool(
        'settings',
        'Open settings. Requires type argument (e.g. wifi, bluetooth, display)',
      );
      SoniqoSpeech.addTool('dialer', 'Open the phone dialer');

      const store = useAssistantStore.getState();
      store.setChatMode(ChatMode.LIVE_TALK);
      store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
      store.setMic(MicOwner.STT);

      const modelId = useModelStore.getState().selectedModelId;
      const modelPath =
        await modelDownloadService.getDownloadedModelPath(modelId);
      await SoniqoSpeech.start(modelPath ?? undefined, 'cpu');
    } catch (e) {
      console.error('Failed to start voice session', e);
      this.endSession();
    }
  },

  async endSession() {
    if (!_isSessionActive) return;
    try {
      await SoniqoSpeech.stop();
    } catch (e) {
      console.error('Failed to stop Soniqo', e);
    } finally {
      _isSessionActive = false;
      const { useAssistantStore } = await import('@/stores/assistant.store');
      const { ChatMode, MicOwner } = await import('@/constants');
      const { resumeFromStt } = await import('@modules/kritha/src');
      const store = useAssistantStore.getState();
      store.setChatMode(ChatMode.TEXTING);
      store.setLiveTalkPhase(null);
      store.setMic(MicOwner.NONE);
      resumeFromStt();
    }
  },
};
