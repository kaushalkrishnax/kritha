import { useEffect } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';

import { wakeWordService } from '../services/wakeword.service';

export function useWakeWordBootstrap() {
  useEffect(() => {
    if (Platform.OS !== 'android') return;

    let cancelled = false;
    const checkAndStartWakeWord = async () => {
      try {
        const recordGranted = await PermissionsAndroid.check(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        );
        if (cancelled || !recordGranted) return;
        await wakeWordService.start();
      } catch (e) {
        console.warn('Failed to start wake word service:', e);
      }
    };

    void checkAndStartWakeWord();
    return () => {
      cancelled = true;
    };
  }, []);
}
