/**
 * PURPOSE:  Local on-device LLM provider backed by the Kotlin native bridge.
 * OWNS:     Translating LlmGenerateRequests into native generateLocal calls
 *           and mapping native delta events to provider callbacks.
 * NOT-OWNS: Local inference execution, model loading, provider selection,
 *           orchestration, or UI.
 * SEE ALSO: RULES.md §5
 */

import {
  addLocalLlmDeltaListener,
  cancelLocalGeneration,
  generateLocal,
} from '@modules/kritha/src';
import { LlmProvider } from './types';

export const localLlmProvider: LlmProvider = {
  generate: (request, callbacks) => {
    const modelPath = request.modelPath;

    if (!modelPath) {
      callbacks.onError(
        new Error('Local model is not downloaded. Download it in Model settings.'),
      );
      return { cancel: () => {} };
    }

    let cancelled = false;
    let settled = false;

    const subscription = addLocalLlmDeltaListener((event) => {
      if (cancelled) return;
      if (event.requestId !== request.requestId) return;
      callbacks.onDelta(event.delta);
    });

    (async () => {
      try {
        const text = await generateLocal({
          requestId: request.requestId,
          modelPath,
          device: 'cpu',
          messages: request.messages,
        });

        if (cancelled || settled) return;
        settled = true;
        callbacks.onComplete(text);
      } catch (error) {
        if (cancelled || settled) return;
        settled = true;
        callbacks.onError(
          error instanceof Error ? error : new Error(String(error)),
        );
      } finally {
        subscription.remove();
      }
    })();

    return {
      cancel: () => {
        if (cancelled) return;
        cancelled = true;
        subscription.remove();
        cancelLocalGeneration(request.requestId);
      },
    };
  },
};
