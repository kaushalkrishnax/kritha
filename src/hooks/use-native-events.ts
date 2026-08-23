import { useEffect } from 'react';
import KrithaNativeModule from '../../modules/kritha/src/KrithaModule';
import { wakeWordService } from '../services/wakeword.service';
import { ChatAction } from './use-chat-state';

interface Options {
  dispatch: (action: ChatAction) => void;
  isSendingRef: React.RefObject<boolean>;
  onWakeWordDetected: () => void;
  isRecordingRef: React.RefObject<boolean>;
}

export function useNativeEvents({
  dispatch,
  isSendingRef,
  onWakeWordDetected,
  isRecordingRef,
}: Options) {
  useEffect(() => {
    const subWakeWord = KrithaNativeModule.addListener(
      'onWakeWordDetected',
      () => {
        onWakeWordDetected();
      },
    );

    return () => {
      subWakeWord.remove();
    };
  }, [dispatch, onWakeWordDetected, isRecordingRef, isSendingRef]);

  useEffect(() => {
    const sub = KrithaNativeModule.addListener(
      'onDownloadProgress',
      (event) => {
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
      },
    );
    return () => sub.remove();
  }, [dispatch]);

  useEffect(() => {
    let currentStreamingId: string | null = null;

    const unsub = wakeWordService.subscribeToAssistant((event) => {
      if (isSendingRef.current) return;

      if (event.state === 'listening') {
        dispatch({
          type: 'SET_ASSISTANT_BANNER',
          banner: { status: 'listening' },
        });
      } else if (event.state === 'processing') {
        dispatch({
          type: 'SET_ASSISTANT_BANNER',
          banner: { status: 'processing', transcript: event.transcript },
        });
        if (event.transcript) {
          dispatch({
            type: 'ADD_MESSAGE',
            payload: {
              id: `${Date.now()}-user`,
              role: 'user',
              text: event.transcript,
            },
          });
        }
      } else if ((event as any).state === 'streaming') {
        const ev = event as any;
        dispatch({ type: 'SET_DRAFT', text: '' });
        dispatch({
          type: 'SET_ASSISTANT_BANNER',
          banner: { status: 'streaming' },
        });
        if (ev.chunk) {
          if (!currentStreamingId) {
            currentStreamingId = `${Date.now()}-assistant`;
            dispatch({
              type: 'ADD_MESSAGE',
              payload: { id: currentStreamingId, role: 'assistant', text: '' },
            });
          }
          dispatch({
            type: 'STREAM_CHUNK',
            id: currentStreamingId,
            chunk: ev.chunk,
          });
        }
      } else if (event.state === 'finished') {
        dispatch({ type: 'SET_ASSISTANT_BANNER', banner: { status: 'idle' } });
        if (event.response && currentStreamingId) {
          dispatch({
            type: 'FINISH_ASSISTANT_STREAM',
            id: currentStreamingId,
            fullText: event.response,
          });
        } else if (event.response) {
          if (event.transcript) {
            dispatch({
              type: 'ADD_MESSAGE',
              payload: {
                id: `${Date.now()}-user`,
                role: 'user',
                text: event.transcript,
              },
            });
          }
          dispatch({
            type: 'ADD_MESSAGE',
            payload: {
              id: `${Date.now()}-assistant`,
              role: 'assistant',
              text: event.response,
            },
          });
        }
        currentStreamingId = null;
      } else if (event.state === 'error') {
        dispatch({ type: 'SET_ASSISTANT_BANNER', banner: { status: 'idle' } });
        if (event.error) dispatch({ type: 'SET_ERROR', error: event.error });
        currentStreamingId = null;
      }
    });

    return unsub;
  }, [dispatch, isSendingRef]);
}
