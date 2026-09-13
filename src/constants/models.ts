import { ModelRecord } from '@/types/models';

export const MODELS: ModelRecord[] = [
  {
    id: 'gemini-flash-lite-latest',
    name: 'Gemini Flash (Cloud)',
    provider: 'Google Cloud',
    remoteUrl: '',
    localPath: '',
    downloaded: true,
    isCloud: true,
  },
  {
    id: 'gemma-4-E2B-it',
    name: 'Gemma 4 E2B',
    provider: 'Hugging Face',
    remoteUrl:
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    localPath: 'gemma-4-E2B-it.litertlm',
    downloaded: false,
    isCloud: false,
  },
  {
    id: 'gemma-4-E4B-it',
    name: 'Gemma 4 E4B',
    provider: 'Hugging Face',
    remoteUrl:
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    localPath: 'gemma-4-E4B-it.litertlm',
    downloaded: false,
    isCloud: false,
  },
  {
    id: 'Qwen3-1.7B',
    name: 'Qwen 3 1.7B',
    provider: 'Hugging Face',
    remoteUrl:
      'https://huggingface.co/litert-community/Qwen3-1.7B/resolve/main/Qwen3_1.7B.litertlm',
    localPath: 'Qwen3_1.7B.litertlm',
    downloaded: false,
    isCloud: false,
  },
  {
    id: 'Qwen3-4B-Thinking-2507',
    name: 'Qwen 3 4B Thinking 2507',
    provider: 'Hugging Face',
    remoteUrl:
      'https://huggingface.co/litert-community/Qwen3-4B-Thinking-2507/resolve/main/model.litertlm',
    localPath: 'Qwen3-4B-Thinking-2507.litertlm',
    downloaded: false,
    isCloud: false,
  },
];

export const isCloudModel = (id: string): boolean => {
  const model = MODELS.find((m) => m.id === id);
  return !!model?.isCloud;
};
