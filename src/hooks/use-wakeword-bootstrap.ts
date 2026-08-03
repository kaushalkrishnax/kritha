import { useEffect } from "react";
import { PermissionsAndroid, Platform } from "react-native";

import { wakeWordService } from "@/services/wakeword.service";

export function useWakeWordBootstrap() {
  useEffect(() => {
    if (Platform.OS !== "android") return;

    let cancelled = false;
    const requestPermissionsAndStart = async () => {
      const microphone = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        {
          title: "Allow microphone access",
          message:
            "Kritha uses the microphone to listen locally for your wake word, including while the app is in the background.",
          buttonPositive: "Allow",
          buttonNegative: "Not now",
        },
      );
      if (cancelled || microphone !== PermissionsAndroid.RESULTS.GRANTED) return;

      if (Number(Platform.Version) >= 33) {
        await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
          {
            title: "Allow wake-word notifications",
            message:
              "Kritha shows an ongoing listening indicator and alerts you when the wake word is detected.",
            buttonPositive: "Allow",
            buttonNegative: "Not now",
          },
        );
      }

      if (!cancelled) await wakeWordService.start();
    };

    void requestPermissionsAndStart();
    return () => {
      cancelled = true;
      // The Android foreground service intentionally outlives React screens.
    };
  }, []);
}
