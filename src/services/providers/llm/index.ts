import { MODELS } from '@/constants';
import { cloudLlmProvider } from './cloud.provider';
import { localLlmProvider } from './local.provider';
import { LlmProvider } from './types';

export * from './types';

export function pickLlmProvider(modelId: string): LlmProvider {
  const model = MODELS.find((entry) => entry.id === modelId);
  const isCloud = model?.isCloud ?? false;

  return isCloud ? cloudLlmProvider : localLlmProvider;
}
