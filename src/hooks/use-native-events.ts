import {
  addDownloadProgressListener,
  addWakeWordListener,
} from '@modules/kritha/src';
import { useEffect } from 'react';
import { ChatAction } from './use-chat-state';

interface Options {
  dispatch: (action: ChatAction) => void;
  sessionId: string | null;
  onWakeWordDetected: () => void;
  onDownloadComplete?: (modelId: string) => void;
}

export function useNativeEvents({
  dispatch,
  sessionId,
  onWakeWordDetected,
  onDownloadComplete,
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
}
