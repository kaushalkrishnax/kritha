export type SpeechModelType = 'stt' | 'tts';

export interface SpeechModelCapabilities {
  streaming: boolean;
  pauseResume: boolean;
  languages: string[];
}

export interface SpeechModelReference {
  id: string;
  type: SpeechModelType;
  displayName: string;
  provider: 'litert';
  nativeReference: {
    sttModelId?: string | null;
    ttsModelId?: string | null;
  };
  capabilities: SpeechModelCapabilities;
}

export const SPEECH_MODELS: SpeechModelReference[] = [
  {
    id: 'nemotron-multilingual-int8',
    type: 'stt',
    displayName: 'Nemotron 3.5 Multilingual (LiteRT INT8)',
    provider: 'litert',
    nativeReference: { sttModelId: 'nemotron-multilingual-int8' },
    capabilities: {
      streaming: true,
      pauseResume: false,
      languages: ['multilingual'],
    },
  },
  {
    id: 'nemotron-multilingual-fp16',
    type: 'stt',
    displayName: 'Nemotron 3.5 Multilingual (LiteRT FP16)',
    provider: 'litert',
    nativeReference: { sttModelId: 'nemotron-multilingual-fp16' },
    capabilities: {
      streaming: true,
      pauseResume: false,
      languages: ['multilingual'],
    },
  },
  {
    id: 'qwen3-tts',
    type: 'tts',
    displayName: 'Qwen3-TTS 12Hz 0.6B (LiteRT)',
    provider: 'litert',
    nativeReference: { ttsModelId: 'qwen3-tts' },
    capabilities: {
      streaming: true,
      pauseResume: true,
      languages: ['en', 'zh', 'es', 'ja', 'ko', 'fr', 'de', 'it', 'pt', 'ru'],
    },
  },
  {
    id: 'kitten-tts-nano',
    type: 'tts',
    displayName: 'KittenTTS Nano 0.8 (LiteRT)',
    provider: 'litert',
    nativeReference: { ttsModelId: 'kitten-tts-nano' },
    capabilities: {
      streaming: true,
      pauseResume: true,
      languages: ['en'],
    },
  },
];

export function getSpeechModel(
  id: string | null | undefined,
): SpeechModelReference | undefined {
  if (!id) return undefined;
  return SPEECH_MODELS.find((m) => m.id === id);
}

export function getSttModel(
  id: string | null | undefined,
): SpeechModelReference | undefined {
  const model = getSpeechModel(id);
  return model?.type === 'stt' ? model : undefined;
}

export function getTtsModel(
  id: string | null | undefined,
): SpeechModelReference | undefined {
  const model = getSpeechModel(id);
  return model?.type === 'tts' ? model : undefined;
}
