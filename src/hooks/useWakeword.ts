import { useCallback, useEffect } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';

import { AssistantBridge } from '@/services';
import { useWakewordStore } from '@/stores';

export function useWakeword() {
  const isEnabled = useWakewordStore((s) => s.isEnabled);
  const setIsEnabled = useWakewordStore((s) => s.setIsEnabled);

  const toggle = useCallback(async () => {
    try {
      if (isEnabled) {
        if (AssistantBridge.isWakewordRunning()) {
          AssistantBridge.stopWakewordListening();
        }
        setIsEnabled(false);
      } else {
        if (!AssistantBridge.isWakewordRunning()) {
          AssistantBridge.startWakewordListening();
        }
        setIsEnabled(true);
      }
    } catch (e) {
      console.warn('Failed to toggle wakeword:', e);
    }
  }, [isEnabled, setIsEnabled]);

  return { isEnabled, toggle };
}

export function useWakeWordBootstrap() {
  const setIsEnabled = useWakewordStore((s) => s.setIsEnabled);

  useEffect(() => {
    if (Platform.OS !== 'android') return;

    let cancelled = false;
    const checkAndStartWakeWord = async () => {
      try {
        const recordGranted = await PermissionsAndroid.check(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        );
        if (cancelled || !recordGranted) return;

        if (!AssistantBridge.isWakewordRunning()) {
          AssistantBridge.startWakewordListening();
        }
        setIsEnabled(true);
      } catch (e) {
        console.warn('Failed to start wake word service:', e);
      }
    };

    void checkAndStartWakeWord();
    return () => {
      cancelled = true;
    };
  }, [setIsEnabled]);
}
