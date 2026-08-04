import { useEffect } from "react";
import { PermissionsAndroid, Platform } from "react-native";

import { wakeWordService } from "@/services/wakeword.service";

export function useWakeWordBootstrap() {
  useEffect(() => {
    if (Platform.OS !== "android") return;

    let cancelled = false;
    const requestPermissionsAndStart = async () => {
      const permissions = [
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
        PermissionsAndroid.PERMISSIONS.READ_CALENDAR,
        PermissionsAndroid.PERMISSIONS.CALL_PHONE,
      ];

      if (Number(Platform.Version) >= 33) {
        permissions.push(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
      }

      const results = await PermissionsAndroid.requestMultiple(permissions);
      
      const recordGranted = results[PermissionsAndroid.PERMISSIONS.RECORD_AUDIO] === PermissionsAndroid.RESULTS.GRANTED;
      if (cancelled || !recordGranted) return;

      if (!cancelled) await wakeWordService.start();
    };

    void requestPermissionsAndStart();
    return () => {
      cancelled = true;
      // The Android foreground service intentionally outlives React screens.
    };
  }, []);
}
