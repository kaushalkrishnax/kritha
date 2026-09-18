import { EventSubscription } from 'expo-modules-core';

import KrithaModule, {
  KrithaModuleEvents,
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  RuntimeId,
  RuntimeInfo,
  RuntimeInstallProgressEvent,
  RuntimeInstallResult,
  VoiceModelInfo,
  WakeWordEvent,
} from './KrithaModule';

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
  return KrithaModule.addListener('onLocalLlmDelta', listener);
}

export function listRuntimes(): Promise<RuntimeInfo[]> {
  return KrithaModule.listRuntimes();
}

export function installRuntime(
  runtimeIds: string | string[],
): Promise<RuntimeInstallResult[]> {
  console.log('installRuntime called with runtimeIds:', runtimeIds);
  return KrithaModule.installRuntime(runtimeIds);
}

export function canInstallPackages(): boolean {
  return KrithaModule.canInstallPackages?.() ?? true;
}

export function openInstallPermissionSettings(): boolean {
  return KrithaModule.openInstallPermissionSettings?.() ?? false;
}

export function addRuntimeInstallProgressListener(
  listener: (event: RuntimeInstallProgressEvent) => void,
): EventSubscription {
  return KrithaModule.addListener('onRuntimeInstallProgress', listener);
}

export const start = (): void => KrithaModule.start();
export const stop = (): void => KrithaModule.stop();
export const pauseForStt = (): void => KrithaModule.pauseForStt();
export const resumeFromStt = (): void => KrithaModule.resumeFromStt();
export const isRunning = (): boolean => KrithaModule.isRunning();
export const isDefaultAssistant = (): boolean =>
  KrithaModule.isDefaultAssistant();
export const openAssistantSettings = (): boolean =>
  KrithaModule.openAssistantSettings();

export function isNotificationListenerEnabled(): boolean {
  return KrithaModule.isNotificationListenerEnabled?.() ?? false;
}

export function requestNotificationListenerPermission(): boolean {
  return KrithaModule.requestNotificationListenerPermission?.() ?? false;
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void,
): EventSubscription {
  return KrithaModule.addListener('onWakeWordDetected', listener);
}

export type SpeechEvent = {
  requestId?: string;
  text?: string;
  isFinal?: boolean;
  replaced?: boolean;
  message?: string;
  level?: number;
};

export type SpeechRequestEvent = {
  requestId: string;
};

const addListener = <E extends keyof KrithaModuleEvents>(
  event: E,
  listener: KrithaModuleEvents[E],
): EventSubscription => KrithaModule.addListener(event, listener);

export const KrithaSpeech = {
  initialize: (config: {
    llmModelPath?: string | null;
    llmDevice?: string | null;
    sttModelId?: string | null;
    ttsModelId?: string | null;
  }) =>
    KrithaModule.speechInitialize(
      config.llmModelPath ?? null,
      config.llmDevice ?? 'cpu',
      config.sttModelId ?? null,
      config.ttsModelId ?? null,
    ),

  startListening: (requestId: string) =>
    KrithaModule.startListening(requestId),

  stopListening: (requestId: string): Promise<string> =>
    KrithaModule.stopListening(requestId),

  cancelListening: (requestId: string) =>
    KrithaModule.cancelListening(requestId),

  start: (llmModelPath?: string | null, llmDevice?: string | null) =>
    KrithaModule.speechStart(llmModelPath ?? null, llmDevice ?? 'cpu'),

  stop: () => KrithaModule.speechStop(),

  speak: (requestId: string, text: string, voice?: string | null) =>
    KrithaModule.speak(requestId, text, voice ?? null),

  pauseSpeaking: (requestId?: string | null) =>
    KrithaModule.pauseSpeaking(requestId ?? null),

  resumeSpeaking: (requestId?: string | null) =>
    KrithaModule.resumeSpeaking(requestId ?? null),

  stopSpeaking: (requestId?: string | null) =>
    KrithaModule.stopSpeaking(requestId ?? null),

  addTool: (name: string, desc: string) =>
    KrithaModule.addTool(name, desc),

  addSpeechStartedListener: (listener: () => void) =>
    addListener('onSpeechStarted', listener),

  addSpeechEndedListener: (listener: () => void) =>
    addListener('onSpeechEnded', listener),

  addTranscriptListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onTranscript', listener),

  addResponseCreatedListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onResponseCreated', listener),

  addResponseDoneListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onResponseDone', listener),

  addResponseInterruptedListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onResponseInterrupted', listener),

  addErrorListener: (listener: (event: unknown) => void) =>
    addListener('onError', listener),

  addSttStartedListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onSttStarted', listener),

  addSttStoppedListener: (
    listener: (event: { requestId: string; text?: string }) => void,
  ) => addListener('onSttStopped', listener),

  addSttCancelledListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onSttCancelled', listener),

  addSttErrorListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onSttError', listener),

  addAudioLevelListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onAudioLevel', listener),

  addTtsStartedListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onTtsStarted', listener),

  addTtsPausedListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onTtsPaused', listener),

  addTtsResumedListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onTtsResumed', listener),

  addTtsCompletedListener: (listener: (event: SpeechRequestEvent) => void) =>
    addListener('onTtsCompleted', listener),

  addTtsStoppedListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onTtsStopped', listener),

  addTtsErrorListener: (listener: (event: SpeechEvent) => void) =>
    addListener('onTtsError', listener),

  listVoiceModels: () => KrithaModule.listVoiceModels(),

  downloadVoiceModel: (modelId: string) =>
    KrithaModule.downloadVoiceModel(modelId),

  deleteVoiceModel: (modelId: string) =>
    KrithaModule.deleteVoiceModel(modelId),

  addVoiceModelProgressListener: (
    listener: (event: { modelId: string; progress: number }) => void,
  ) => addListener('onVoiceModelProgress', listener),
};

export {
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  RuntimeId,
  RuntimeInfo,
  RuntimeInstallProgressEvent,
  RuntimeInstallResult,
  VoiceModelInfo,
  WakeWordEvent,
};