import {
  addAssistantListener,
  AssistantEvent,
  getCurrentState,
} from '@modules/kritha/src';
import { useEffect } from 'react';
import { useAssistantStore } from './assistantStore';
import { database } from '../database';

const VOLUME_EVENT_INTERVAL_MS = 100;

export function useAssistantEventStream() {
  useEffect(() => {
    let lastVolumeEventAt = 0;

    const sub = addAssistantListener((event: AssistantEvent) => {
      const store = useAssistantStore.getState();
      console.log(
        '[OverlayEvent]',
        event.type,
        'state:',
        store.canonicalState,
        'runId:',
        store.assistantRunId,
        'transcript:',
        store.transcript,
        'response:',
        store.response,
      );

      switch (event.type) {
        case 'MESSAGE_PERSISTED': {
          const { chatSessionId, messageId, role, text, createdAt } =
            event.payload;
          if (chatSessionId && messageId) {
            const currentStore = useAssistantStore.getState();
            if (!currentStore.chatSessionId) {
              currentStore.setChatSessionId(chatSessionId);
            }
            currentStore.upsertMessage({
              id: messageId,
              sessionId: chatSessionId,
              role: role as 'user' | 'assistant',
              text,
              createdAt,
            });
            database.messages.saveMessage({
              sessionId: chatSessionId,
              role: role as 'user' | 'assistant',
              content: text,
              customId: messageId,
              createdAt,
            }).catch((err: unknown) => console.error('[Database] Failed to persist message:', err));
          }
          break;
        }

        case 'SESSION_START': {
          const runId = event.payload.assistantRunId;
          if (event.payload.chatSessionId) {
            store.setChatSessionId(event.payload.chatSessionId);
          }
          if (runId) store.setAssistantRunId(runId);
          if (event.payload.requestId)
            store.setRequestId(event.payload.requestId);
          if (event.payload.origin)
            store.setRequestOrigin(event.payload.origin);
          store.setSessionActive(true);
          store.setResponse('');
          store.setTranscript('');
          // A new run invalidates any pending composer text.
          store.setDraftText('');
          store.setError(null);
          break;
        }

        case 'SESSION_END': {
          const runId = event.payload.assistantRunId;
          if (!runId || store.assistantRunId === runId) {
            store.setSessionActive(false);
          }
          break;
        }

        case 'STATE_CHANGED': {
          const runId = event.payload.assistantRunId;
          if (runId && store.assistantRunId && store.assistantRunId !== runId)
            return;
          if (event.payload.origin)
            store.setRequestOrigin(event.payload.origin);
          if (event.payload.state) {
            store.setCanonicalState(event.payload.state);
          }
          if (event.payload.transcript !== undefined) {
            store.setTranscript(event.payload.transcript);
          }
          break;
        }

        case 'TEXT_DELTA': {
          const reqId = event.payload.requestId;
          const msgId = event.payload.messageId;
          if (reqId && store.requestId && store.requestId !== reqId) return;
          if (msgId && event.payload.chunk) {
            store.appendMessageChunk(msgId, event.payload.chunk);
          }
          if (event.payload.chunk) {
            store.appendResponse(event.payload.chunk);
          }
          break;
        }

        case 'TEXT_COMPLETE': {
          const reqId = event.payload.requestId;
          const msgId = event.payload.messageId;
          if (reqId && store.requestId && store.requestId !== reqId) return;
          if (msgId && event.payload.response) {
            store.completeMessageStream(msgId, event.payload.response);
          }
          if (event.payload.response) {
            store.setResponse(event.payload.response);
          }
          if (event.payload.transcript) {
            store.setTranscript(event.payload.transcript);
          }
          break;
        }

        case 'TTS_START':
          store.setTtsState(true, false, event.payload.messageId);
          break;

        case 'TTS_PAUSE':
          store.setTtsState(false, true, event.payload.messageId);
          break;

        case 'TTS_RESUME':
          store.setTtsState(true, false, event.payload.messageId);
          break;

        case 'TTS_STOP':
        case 'TTS_COMPLETE':
          store.setTtsState(false, false, null);
          break;

        case 'TTS_ERROR':
          store.setTtsState(false, false, null);
          store.setError(event.payload.message || 'TTS Error');
          break;

        case 'MICROPHONE_CHANGED': {
          if (event.payload.volumeRms !== undefined) {
            const now = Date.now();
            if (now - lastVolumeEventAt < VOLUME_EVENT_INTERVAL_MS) break;
            lastVolumeEventAt = now;
          }
          store.setMicState(
            event.payload.owner || 'NONE',
            event.payload.isClaimed ?? event.payload.available ?? false,
            event.payload.volumeRms ?? 0,
          );
          break;
        }

        case 'ERROR': {
          const reqId = event.payload.requestId;
          if (reqId && store.requestId && store.requestId !== reqId) return;
          store.setError(event.payload.message || 'An unknown error occurred');
          break;
        }
      }
    });

    try {
      const currentState = getCurrentState();
      if (currentState && currentState.state) {
        const store = useAssistantStore.getState();
        store.setCanonicalState(currentState.state);
        if (currentState.chatSessionId)
          store.setChatSessionId(currentState.chatSessionId);
        if (currentState.assistantRunId)
          store.setAssistantRunId(currentState.assistantRunId);
        if (currentState.requestId) store.setRequestId(currentState.requestId);
        if (currentState.transcript)
          store.setTranscript(currentState.transcript);
        if (currentState.response) store.setResponse(currentState.response);
        if (currentState.ttsState) {
          store.setTtsState(
            currentState.ttsState.isSpeaking,
            currentState.ttsState.isPaused,
            currentState.ttsState.messageId,
          );
        }
      }
    } catch {
      // Ignore if native bridge hydration is not supported
    }

    return () => {
      sub.remove();
    };
  }, []);
}
