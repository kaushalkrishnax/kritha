import { EventSubscription } from 'expo-modules-core';
import KrithaModule, {
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  VoiceModelInfo,
  WakeWordEvent,
} from './KrithaModule';

const emitter = KrithaModule;

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
  return emitter.addListener('onLocalLlmDelta', listener);
}

export function start(): void {
  KrithaModule.start();
}

export function stop(): void {
  KrithaModule.stop();
}

export function pauseForStt(): void {
  KrithaModule.pauseForStt();
}

export function resumeFromStt(): void {
  KrithaModule.resumeFromStt();
}

export function isRunning(): boolean {
  return KrithaModule.isRunning();
}

export function isDefaultAssistant(): boolean {
  return KrithaModule.isDefaultAssistant();
}

export function openAssistantSettings(): boolean {
  return KrithaModule.openAssistantSettings();
}

export function isNotificationListenerEnabled(): boolean {
  return KrithaModule.isNotificationListenerEnabled
    ? KrithaModule.isNotificationListenerEnabled()
    : false;
}

export function requestNotificationListenerPermission(): boolean {
  return KrithaModule.requestNotificationListenerPermission
    ? KrithaModule.requestNotificationListenerPermission()
    : false;
}

export function addWakeWordListener(
  listener: (event: WakeWordEvent) => void,
): EventSubscription {
  return emitter.addListener('onWakeWordDetected', listener);
}

// Soniqo Speech replacements
export type SpeechEvent = {
  text?: string;
  isFinal?: boolean;
};

export const SoniqoSpeech = {
  initialize: async (config: {
    llmModelPath?: string | null;
    llmDevice?: string | null;
    sttModelId?: string | null;
    ttsModelId?: string | null;
  }) => {
    await KrithaModule.soniqoInitialize(
      config.llmModelPath ?? null,
      config.llmDevice ?? 'cpu',
      config.sttModelId ?? null,
      config.ttsModelId ?? null,
    );
  },
  start: async (llmModelPath?: string | null, llmDevice?: string | null) => {
    await KrithaModule.soniqoStart(llmModelPath ?? null, llmDevice ?? 'cpu');
  },
  stop: async () => {
    await KrithaModule.soniqoStop();
  },
  speak: async (text: string, voice?: string | null) => {
    await KrithaModule.soniqoSpeak(text, voice ?? null);
  },
  stopSpeaking: async () => {
    await KrithaModule.soniqoStopSpeaking();
  },
  addTool: async (name: string, desc: string) => {
    await KrithaModule.soniqoAddTool(name, desc);
  },
  addSpeechStartedListener: (listener: () => void) => {
    emitter.addListener('onSpeechStarted', listener);
    return emitter.addListener('onSpeechStarted', listener);
  },
  addSpeechEndedListener: (listener: () => void) => {
    emitter.addListener('onSpeechEnded', listener);
    return emitter.addListener('onSpeechEnded', listener);
  },
  addTranscriptListener: (listener: (e: SpeechEvent) => void) => {
    emitter.addListener('onTranscript', listener);
    return emitter.addListener('onTranscript', listener);
  },
  addResponseCreatedListener: (listener: (e: SpeechEvent) => void) => {
    emitter.addListener('onResponseCreated', listener);
    return emitter.addListener('onResponseCreated', listener);
  },
  addResponseDoneListener: (listener: () => void) => {
    emitter.addListener('onResponseDone', listener);
    return emitter.addListener('onResponseDone', listener);
  },
  addResponseInterruptedListener: (listener: () => void) => {
    emitter.addListener('onResponseInterrupted', listener);
    return emitter.addListener('onResponseInterrupted', listener);
  },
  addErrorListener: (listener: (e: any) => void) => {
    emitter.addListener('onError', listener);
    return emitter.addListener('onError', listener);
  },
  listVoiceModels: async () => {
    return await KrithaModule.listVoiceModels();
  },
  downloadVoiceModel: async (modelId: string) => {
    await KrithaModule.downloadVoiceModel(modelId);
  },
  deleteVoiceModel: async (modelId: string) => {
    await KrithaModule.deleteVoiceModel(modelId);
  },
  addVoiceModelProgressListener: (
    listener: (e: { modelId: string; progress: number }) => void,
  ) => {
    return emitter.addListener('onVoiceModelProgress', listener);
  },
};

export {
  LocalLlmDeltaEvent,
  LocalLlmGenerateRequest,
  LocalLlmMessage,
  VoiceModelInfo,
  WakeWordEvent
};

