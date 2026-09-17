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

export const KrithaSpeech = {
  initialize: async (config: {
    llmModelPath?: string | null;
    llmDevice?: string | null;
    sttModelId?: string | null;
    ttsModelId?: string | null;
  }) => {
    await KrithaModule.speechInitialize(
      config.llmModelPath ?? null,
      config.llmDevice ?? 'cpu',
      config.sttModelId ?? null,
      config.ttsModelId ?? null,
    );
  },
  startListening: async (requestId: string) => {
    await KrithaModule.startListening(requestId);
  },
  stopListening: async (requestId: string): Promise<string> => {
    return await KrithaModule.stopListening(requestId);
  },
  cancelListening: async (requestId: string) => {
    await KrithaModule.cancelListening(requestId);
  },
  start: async (llmModelPath?: string | null, llmDevice?: string | null) => {
    await KrithaModule.speechStart(llmModelPath ?? null, llmDevice ?? 'cpu');
  },
  stop: async () => {
    await KrithaModule.speechStop();
  },
  speak: async (requestId: string, text: string, voice?: string | null) => {
    await KrithaModule.speak(requestId, text, voice ?? null);
  },
  pauseSpeaking: async (requestId?: string | null) => {
    await KrithaModule.pauseSpeaking(requestId ?? null);
  },
  resumeSpeaking: async (requestId?: string | null) => {
    await KrithaModule.resumeSpeaking(requestId ?? null);
  },
  stopSpeaking: async (requestId?: string | null) => {
    await KrithaModule.stopSpeaking(requestId ?? null);
  },
  addTool: async (name: string, desc: string) => {
    await KrithaModule.addTool(name, desc);
  },
  addSpeechStartedListener: (listener: () => void) => {
    return emitter.addListener('onSpeechStarted', listener);
  },
  addSpeechEndedListener: (listener: () => void) => {
    return emitter.addListener('onSpeechEnded', listener);
  },
  addTranscriptListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onTranscript', listener);
  },
  addResponseCreatedListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onResponseCreated', listener);
  },
  addResponseDoneListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onResponseDone', listener);
  },
  addResponseInterruptedListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onResponseInterrupted', listener);
  },
  addErrorListener: (listener: (e: any) => void) => {
    return emitter.addListener('onError', listener);
  },
  addSttStartedListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onSttStarted', listener);
  },
  addSttStoppedListener: (
    listener: (e: { requestId: string; text?: string }) => void,
  ) => {
    return emitter.addListener('onSttStopped', listener);
  },
  addSttCancelledListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onSttCancelled', listener);
  },
  addSttErrorListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onSttError', listener);
  },
  addAudioLevelListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onAudioLevel', listener);
  },
  addTtsStartedListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onTtsStarted', listener);
  },
  addTtsPausedListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onTtsPaused', listener);
  },
  addTtsResumedListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onTtsResumed', listener);
  },
  addTtsCompletedListener: (listener: (e: SpeechRequestEvent) => void) => {
    return emitter.addListener('onTtsCompleted', listener);
  },
  addTtsStoppedListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onTtsStopped', listener);
  },
  addTtsErrorListener: (listener: (e: SpeechEvent) => void) => {
    return emitter.addListener('onTtsError', listener);
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
  WakeWordEvent,
};
