import { TtsProvider } from './types';

const MS_PER_CHARACTER = 45;
const MIN_DURATION_MS = 800;
const MAX_DURATION_MS = 15_000;

let activeTimer: ReturnType<typeof setTimeout> | null = null;
let remainingMs = 0;
let onDoneCallback: (() => void) | null = null;

function clearActiveTimer() {
  if (activeTimer) {
    clearTimeout(activeTimer);
  }

  activeTimer = null;
}

export const stubTtsProvider: TtsProvider = {
  speak: (text, _messageId, onDone) => {
    clearActiveTimer();

    remainingMs = Math.min(
      MAX_DURATION_MS,
      Math.max(MIN_DURATION_MS, text.length * MS_PER_CHARACTER),
    );

    onDoneCallback = onDone;

    activeTimer = setTimeout(() => {
      activeTimer = null;
      onDoneCallback?.();
    }, remainingMs);
  },

  pause: () => {
    clearActiveTimer();
  },

  resume: () => {
    if (!activeTimer && onDoneCallback) {
      activeTimer = setTimeout(() => {
        activeTimer = null;
        onDoneCallback?.();
      }, remainingMs);
    }
  },

  stop: () => {
    clearActiveTimer();
    onDoneCallback = null;
  },
};
