import {
  addDownloadProgressListener,
  addWakeWordListener,
  addAssistantListener
} from '@modules/kritha/src';
import { useEffect } from 'react';
import { ChatAction } from './use-chat-state';

interface Options {
  dispatch: (action: ChatAction) => void;
  onWakeWordDetected: () => void;
  onDownloadComplete?: (modelId: string) => void;
  onTtsDone?: () => void;
}

export function useNativeEvents({
  dispatch,
  onWakeWordDetected,
  onDownloadComplete,
  onTtsDone,
}: Options) {
  useEffect(() => {
    const subWakeWord = addWakeWordListener(() => {
      onWakeWordDetected();
    });

    return () => {
      subWakeWord.remove();
    };
  }, [onWakeWordDetected]);

  useEffect(() => {
    const sub = addDownloadProgressListener((event) => {
      const isComplete =
        event.downloadedMb >= event.totalMb && event.totalMb > 0;
      if (isComplete) {
        dispatch({ type: 'MARK_MODEL_DOWNLOADED', modelId: event.modelId });
        dispatch({
          type: 'UPDATE_DOWNLOAD',
          patch: {
            progress: 1,
            downloadedMb: event.totalMb,
            active: false,
            paused: false,
            speed: 0,
          },
        });
        if (onDownloadComplete) {
          onDownloadComplete(event.modelId);
        }
      } else {
        dispatch({
          type: 'UPDATE_DOWNLOAD',
          patch: {
            progress:
              event.totalMb > 0 ? event.downloadedMb / event.totalMb : 0,
            downloadedMb: event.downloadedMb,
            totalMb: event.totalMb,
            speed: event.speedMbps,
          },
        });
      }
    });
    return () => sub.remove();
  }, [dispatch]);

  useEffect(() => {
    const sub = addAssistantListener((event) => {
      if (event.type === 'TTS_COMPLETE') {
        if (onTtsDone) {
          onTtsDone();
        }
      }
    });
    return () => sub.remove();
  }, [onTtsDone]);
}
