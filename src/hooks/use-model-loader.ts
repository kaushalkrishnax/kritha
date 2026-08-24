import { useEffect } from 'react';
import {
  getAvailableModels,
  getDownloadedModels,
  getSelectedModel,
} from '@modules/kritha/src';
import { ChatAction } from './use-chat-state';
import { ModelRecord } from '../components/chat/types';

interface RawModelInfo {
  id: string;
  name: string;
  provider?: string;
  remoteUrl?: string;
  localPath?: string;
}

export function useModelLoader(dispatch: (action: ChatAction) => void) {
  useEffect(() => {
    const load = async () => {
      try {
        const [available, downloaded, selected] = await Promise.all([
          getAvailableModels(),
          getDownloadedModels(),
          getSelectedModel(),
        ]);

        if (available && available.length > 0) {
          const models: ModelRecord[] = available.map((m: RawModelInfo) => {
            const isCloudModel = m.id === 'gemini-flash-lite-latest';
            return {
              id: m.id,
              name: m.name,
              provider: m.provider || 'Hugging Face',
              downloaded: isCloudModel || downloaded.includes(m.id),
              isCloud: isCloudModel,
            };
          });
          dispatch({ type: 'SET_MODELS', models });
        }

        if (selected) {
          dispatch({ type: 'SET_SELECTED_MODEL', modelId: selected });
        }
      } catch (err) {
        console.warn(
          '[ModelLoader] Failed to load models from native module:',
          err,
        );
      }
    };

    load();
  }, [dispatch]);
}
