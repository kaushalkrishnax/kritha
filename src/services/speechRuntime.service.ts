import { useAssistantStore } from '@/stores/assistant.store';
import { useModelStore } from '@/stores/model.store';
import { useVoiceStore } from '@/stores/voice.store';
import { KrithaSpeech, SpeechEvent } from '@modules/kritha/src';

import { modelDownloadService } from './model.service';

export type SttRuntimeEvent =
  | { kind: 'sttStarted'; requestId: string }
  | { kind: 'transcript'; requestId: string; text: string; isFinal: boolean }
  | { kind: 'sttStopped'; requestId: string; text: string }
  | { kind: 'sttCancelled'; requestId: string }
  | { kind: 'sttError'; requestId: string | null; message: string }
  | { kind: 'audioLevel'; requestId: string; level: number };

export type TtsRuntimeEvent =
  | { kind: 'ttsStarted'; requestId: string }
  | { kind: 'ttsPaused'; requestId: string }
  | { kind: 'ttsResumed'; requestId: string }
  | { kind: 'ttsCompleted'; requestId: string }
  | { kind: 'ttsStopped'; requestId: string; replaced?: boolean }
  | { kind: 'ttsError'; requestId: string | null; message: string };

export type SpeechRuntimeEvent = SttRuntimeEvent | TtsRuntimeEvent;

export type SpeechRuntimeListener = (event: SpeechRuntimeEvent) => void;

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

const listeners = new Set<SpeechRuntimeListener>();
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

function emit(event: SpeechRuntimeEvent): void {
  listeners.forEach((listener) => {
    try {
      listener(event);
    } catch (e) {
      console.warn('[speechRuntime] speech listener threw', e);
    }
  });
}

function attachNativeListeners(): void {
  if (nativeListenersAttached) return;
  nativeListenersAttached = true;

  KrithaSpeech.addSttStartedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttStarted', requestId: e.requestId });
  });

  KrithaSpeech.addTranscriptListener((e: SpeechEvent) => {
    if (!e?.requestId || typeof e.text !== 'string') return;
    emit({
      kind: 'transcript',
      requestId: e.requestId,
      text: e.text,
      isFinal: e.isFinal === true,
    });
  });

  KrithaSpeech.addSttStoppedListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttStopped', requestId: e.requestId, text: e.text ?? '' });
  });

  KrithaSpeech.addSttCancelledListener((e) => {
    if (!e?.requestId) return;
    emit({ kind: 'sttCancelled', requestId: e.requestId });
  });

  KrithaSpeech.addSttErrorListener((e: SpeechEvent) => {
    emit({
      kind: 'sttError',
      requestId: e?.requestId ?? null,
      message: e?.message || e?.text || 'Speech recognition failed.',
    });
  });

  KrithaSpeech.addAudioLevelListener((e: SpeechEvent) => {
    if (!e?.requestId || typeof e.level !== 'number') return;
    emit({
      kind: 'audioLevel',
      requestId: e.requestId,
      level: Math.max(0, Math.min(1, e.level)),
    });
  });

  KrithaSpeech.addTtsStartedListener((e) => {
    console.log('[TTS_DEBUG] speechRuntime: native event onTtsStarted', e);
    if (!e?.requestId) return;
    emit({ kind: 'ttsStarted', requestId: e.requestId });
  });

  KrithaSpeech.addTtsPausedListener((e) => {
    console.log('[TTS_DEBUG] speechRuntime: native event onTtsPaused', e);
    if (!e?.requestId) return;
    emit({ kind: 'ttsPaused', requestId: e.requestId });
  });

  KrithaSpeech.addTtsResumedListener((e) => {
    console.log('[TTS_DEBUG] speechRuntime: native event onTtsResumed', e);
    if (!e?.requestId) return;
    emit({ kind: 'ttsResumed', requestId: e.requestId });
  });

  KrithaSpeech.addTtsCompletedListener((e) => {
    console.log('[TTS_DEBUG] speechRuntime: native event onTtsCompleted', e);
    if (!e?.requestId) return;
    emit({ kind: 'ttsCompleted', requestId: e.requestId });
  });

  KrithaSpeech.addTtsStoppedListener((e: SpeechEvent) => {
    console.log('[TTS_DEBUG] speechRuntime: native event onTtsStopped', e);
    if (!e?.requestId) return;
    emit({
      kind: 'ttsStopped',
      requestId: e.requestId,
      replaced: e.replaced === true,
    });
  });

  KrithaSpeech.addTtsErrorListener((e: SpeechEvent) => {
    console.error('[TTS_DEBUG] speechRuntime: native event onTtsError', e);
    emit({
      kind: 'ttsError',
      requestId: e?.requestId ?? null,
      message: e?.message || e?.text || 'Speech playback failed.',
    });
  });

  KrithaSpeech.addErrorListener((e: any) => {
    const message =
      typeof e?.message === 'string' && e.message
        ? e.message
        : 'Speech engine error.';
    emit({ kind: 'sttError', requestId: e?.requestId ?? null, message });
  });
}

export function subscribeSpeechRuntimeEvents(
  listener: SpeechRuntimeListener,
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
  console.log('[TTS_DEBUG] speechRuntime: assertModelsDownloaded called', {
    sttModelId,
    ttsModelId,
    forCapability,
  });
  const models = await KrithaSpeech.listVoiceModels();
  console.log('[TTS_DEBUG] speechRuntime: listVoiceModels result:', models);
  if (forCapability === 'stt' || forCapability === 'both') {
    const stt = models.find((m) => m.id === sttModelId);
    if (!sttModelId || !stt?.isDownloaded) {
      console.warn('[TTS_DEBUG] speechRuntime: STT model missing or not downloaded', { sttModelId, stt });
      throw new VoiceModelMissingError('stt', sttModelId);
    }
  }
  if (forCapability === 'tts' || forCapability === 'both') {
    const tts = models.find((m) => m.id === ttsModelId);
    if (!ttsModelId || !tts?.isDownloaded) {
      console.warn('[TTS_DEBUG] speechRuntime: TTS model missing or not downloaded', { ttsModelId, tts });
      throw new VoiceModelMissingError('tts', ttsModelId);
    }
  }
}

export async function ensureSpeechRuntimeInitialized(
  forCapability: 'stt' | 'tts' | 'both' = 'both',
): Promise<void> {
  console.log('[TTS_DEBUG] speechRuntime: ensureSpeechRuntimeInitialized starting for', forCapability);
  attachNativeListeners();
  const sttModelId = useVoiceStore.getState().selectedSttModelId;
  const ttsModelId = useVoiceStore.getState().selectedTtsModelId;

  await assertModelsDownloaded(sttModelId, ttsModelId, forCapability);

  const selectionsMatch =
    initializedSelections !== null &&
    initializedSelections.stt === sttModelId &&
    initializedSelections.tts === ttsModelId;
  if (selectionsMatch) return;
  if (selectionsMatch) {
    console.log('[TTS_DEBUG] speechRuntime: selectionsMatch is true, already initialized');
    return;
  }

  const modelId = useModelStore.getState().selectedModelId;
  const modelPath = await modelDownloadService.getDownloadedModelPath(modelId);
  console.log('[TTS_DEBUG] speechRuntime: initializing KrithaSpeech with', {
    modelPath,
    sttModelId,
    ttsModelId,
  });

  beginModelLoad(forCapability);
  try {
    await KrithaSpeech.initialize({
      llmModelPath: modelPath ?? undefined,
      llmDevice: 'cpu',
      sttModelId: sttModelId ?? undefined,
      ttsModelId: ttsModelId ?? undefined,
    });
    initializedSelections = { stt: sttModelId, tts: ttsModelId };
    console.log('[TTS_DEBUG] speechRuntime: KrithaSpeech.initialize succeeded');
  } catch (initErr) {
    console.error('[TTS_DEBUG] speechRuntime: KrithaSpeech.initialize failed', initErr);
    throw initErr;
  } finally {
    endModelLoad(forCapability);
  }
}

export async function startListening(requestId: string): Promise<void> {
  await ensureSpeechRuntimeInitialized('stt');
  await KrithaSpeech.startListening(requestId);
}

export async function stopListening(requestId: string): Promise<string> {
  return await KrithaSpeech.stopListening(requestId);
}

export async function cancelListening(requestId: string): Promise<void> {
  try {
    await KrithaSpeech.cancelListening(requestId);
  } catch (e) {
    console.warn('[speechRuntime] cancelListening failed', e);
  }
}

export async function speak(
  requestId: string,
  text: string,
  voice?: string | null,
): Promise<void> {
  console.log('[TTS_DEBUG] speechRuntime: speak called', {
    requestId,
    textPreview: text?.slice(0, 50),
    textLength: text?.length,
    voice,
  });
  await ensureSpeechRuntimeInitialized('tts');
  console.log('[TTS_DEBUG] speechRuntime: calling KrithaSpeech.speak...');
  try {
    await KrithaSpeech.speak(requestId, text, voice ?? 'F1');
    console.log('[TTS_DEBUG] speechRuntime: KrithaSpeech.speak invocation finished');
  } catch (speakErr) {
    console.error('[TTS_DEBUG] speechRuntime: KrithaSpeech.speak invocation threw', speakErr);
    throw speakErr;
  }
}

export async function pauseSpeaking(requestId?: string): Promise<void> {
  await KrithaSpeech.pauseSpeaking(requestId ?? null);
}

export async function resumeSpeaking(requestId?: string): Promise<void> {
  await KrithaSpeech.resumeSpeaking(requestId ?? null);
}

/** Stop playback. Completion must not be inferred from a stop. */
export async function stopSpeaking(requestId?: string): Promise<void> {
  try {
    await KrithaSpeech.stopSpeaking(requestId ?? null);
  } catch (e) {
    console.warn('[speechRuntime] stopSpeaking failed', e);
  }
}

export async function shutdownSpeech(): Promise<void> {
  try {
    await KrithaSpeech.stop();
  } catch (e) {
    console.warn('[speechRuntime] shutdown failed', e);
  }
}

export async function listVoiceModels(): Promise<VoiceModelStatus[]> {
  return (await KrithaSpeech.listVoiceModels()) as VoiceModelStatus[];
}

export async function downloadVoiceModel(modelId: string): Promise<void> {
  await KrithaSpeech.downloadVoiceModel(modelId);
}

export async function deleteVoiceModel(modelId: string): Promise<void> {
  await KrithaSpeech.deleteVoiceModel(modelId);
}

export function subscribeVoiceModelProgress(
  listener: (event: { modelId: string; progress: number }) => void,
): () => void {
  const sub = KrithaSpeech.addVoiceModelProgressListener(listener);
  return () => sub.remove();
}

let _isSessionActive = false;

export const SpeechCoordinator = {
  async init(): Promise<boolean> {
    try {
      await ensureSpeechRuntimeInitialized('both');
      attachNativeListeners();
      return true;
    } catch (e) {
      if (e instanceof VoiceModelMissingError) {
        useVoiceStore.getState().setVoiceModalOpen(true);
        return false;
      }
      console.error('Failed to initialize Kritha speech', e);
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

      KrithaSpeech.addTool('torch', 'Turn flashlight on or off');
      KrithaSpeech.addTool('mute', 'Mute or unmute device volume');
      KrithaSpeech.addTool(
        'settings',
        'Open settings. Requires type argument (e.g. wifi, bluetooth, display)',
      );
      KrithaSpeech.addTool('dialer', 'Open the phone dialer');

      const store = useAssistantStore.getState();
      store.setChatMode(ChatMode.LIVE_TALK);
      store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
      store.setMic(MicOwner.STT);

      const modelId = useModelStore.getState().selectedModelId;
      const modelPath =
        await modelDownloadService.getDownloadedModelPath(modelId);
      await KrithaSpeech.start(modelPath ?? undefined, 'cpu');
    } catch (e) {
      console.error('Failed to start voice session', e);
      this.endSession();
    }
  },

  async endSession() {
    if (!_isSessionActive) return;
    try {
      await KrithaSpeech.stop();
    } catch (e) {
      console.error('Failed to stop Kritha speech', e);
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
