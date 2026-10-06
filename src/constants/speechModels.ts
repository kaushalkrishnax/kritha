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
  provider: 'onnx';
  nativeReference: {
    sttModelId?: string | null;
    ttsModelId?: string | null;
  };
  capabilities: SpeechModelCapabilities;
}

export const SPEECH_MODELS: SpeechModelReference[] = [
  {
    id: 'whisper-tiny-en-onnx',
    type: 'stt',
    displayName: 'Whisper Tiny EN (ONNX)',
    provider: 'onnx',
    nativeReference: { sttModelId: 'whisper-tiny-en-onnx' },
    capabilities: {
      streaming: false,
      pauseResume: false,
      languages: ['en'],
    },
  },
  {
    id: 'piper-en-us-lessac-low',
    type: 'tts',
    displayName: 'Piper Lessac Low (EN)',
    provider: 'onnx',
    nativeReference: { ttsModelId: 'piper-en-us-lessac-low' },
    capabilities: {
      streaming: false,
      pauseResume: true,
      languages: ['en'],
    },
  },
  {
    id: 'piper-en-us-lessac-medium',
    type: 'tts',
    displayName: 'Piper Lessac Medium (EN)',
    provider: 'onnx',
    nativeReference: { ttsModelId: 'piper-en-us-lessac-medium' },
    capabilities: {
      streaming: false,
      pauseResume: true,
      languages: ['en'],
    },
  },
  {
    id: 'piper-en-us-lessac-high',
    type: 'tts',
    displayName: 'Piper Lessac High (EN)',
    provider: 'onnx',
    nativeReference: { ttsModelId: 'piper-en-us-lessac-high' },
    capabilities: {
      streaming: false,
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
