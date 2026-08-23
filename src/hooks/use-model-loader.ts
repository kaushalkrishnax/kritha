/**
 * use-model-loader.ts
 *
 * Loads model state from the native module on mount and syncs it into the reducer.
 */
import { useEffect } from 'react';
import KrithaNativeModule from '../../modules/kritha/src/KrithaModule';
import { ChatAction } from './use-chat-state';
import { ModelRecord } from '../components/chat/types';

export function useModelLoader(dispatch: (action: ChatAction) => void) {
  useEffect(() => {
    const load = async () => {
      try {
        const [available, downloaded, selected] = await Promise.all([
          KrithaNativeModule.getAvailableModels(),
          KrithaNativeModule.getDownloadedModels(),
          KrithaNativeModule.getSelectedModel(),
        ]);

        if (available && available.length > 0) {
          const models: ModelRecord[] = available.map((m: any) => {
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
