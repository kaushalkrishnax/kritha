import { settingsService } from '@/services/settings.service';

import { LlmMessage, LlmProvider } from './types';

const GEMINI_MODEL = 'gemini-flash-lite-latest';
const CHUNK_SIZE = 8;
const CHUNK_INTERVAL_MS = 20;

function toGeminiPayload(messages: LlmMessage[]) {
  const systemMessages = messages.filter((m) => m.role === 'system');
  const turns = messages.filter((m) => m.role !== 'system');

  return {
    systemInstruction: systemMessages.length
      ? {
          parts: [
            {
              text: systemMessages.map((m) => m.content).join('\n\n'),
            },
          ],
        }
      : undefined,

    contents: turns.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    })),
  };
}

export const cloudLlmProvider: LlmProvider = {
  generate: (request, callbacks) => {
    const abortController = new AbortController();

    let playbackTimer: ReturnType<typeof setTimeout> | null = null;
    let cancelled = false;

    (async () => {
      const apiKey = await settingsService.readApiKey();

      if (!apiKey) {
        callbacks.onError(
          new Error('No Gemini API key configured. Add one in Settings.'),
        );
        return;
      }

      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/` +
        `${GEMINI_MODEL}:generateContent?key=${apiKey}`;

      let text: string;

      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(toGeminiPayload(request.messages)),
          signal: abortController.signal,
        });

        if (!response.ok) {
          const body = await response.text().catch(() => '');
          throw new Error(
            `Gemini request failed (${response.status}): ${body.slice(0, 200)}`,
          );
        }

        const json = await response.json();

        text =
          json?.candidates?.[0]?.content?.parts
            ?.map((part: any) => part.text)
            .join('') ?? '';

        if (!text) {
          throw new Error('Gemini returned an empty response.');
        }
      } catch (error: any) {
        if (cancelled) return;

        callbacks.onError(
          error instanceof Error ? error : new Error(String(error)),
        );
        return;
      }

      if (cancelled) return;

      let offset = 0;

      const pump = () => {
        if (cancelled) return;

        const next = text.slice(offset, offset + CHUNK_SIZE);
        offset += CHUNK_SIZE;

        if (next) {
          callbacks.onDelta(next);
        }

        if (offset < text.length) {
          playbackTimer = setTimeout(pump, CHUNK_INTERVAL_MS);
        } else {
          callbacks.onComplete(text);
        }
      };

      pump();
    })();

    return {
      cancel: () => {
        cancelled = true;
        abortController.abort();

        if (playbackTimer) {
          clearTimeout(playbackTimer);
          playbackTimer = null;
        }
      },
    };
  },
};
