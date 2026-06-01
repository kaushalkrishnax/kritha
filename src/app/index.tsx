import { useEffect, useState, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  PermissionsAndroid,
  Platform,
  StyleSheet,
} from "react-native";
import { wakeWordService } from "../services/wakeword.service";

export default function Index() {
  const [hasPermission, setHasPermission] = useState(false);
  const [isListening, setIsListening] = useState(false);

  const [lastDetected, setLastDetected] = useState<string | null>(null);
  const [confidence, setConfidence] = useState<number | null>(null);

  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    async function requestMicPermission() {
      if (Platform.OS === "android") {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          {
            title: "Microphone Permission",
            message:
              "This app needs access to your microphone to detect the wake word.",
            buttonNeutral: "Ask Me Later",
            buttonNegative: "Cancel",
            buttonPositive: "OK",
          },
        );
        setHasPermission(granted === PermissionsAndroid.RESULTS.GRANTED);
      }
    }

    requestMicPermission();

    return () => {
      wakeWordService.stop();
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  const toggleListening = async () => {
    if (!hasPermission) {
      console.warn("Cannot start: Microphone permission denied.");
      return;
    }

    if (isListening) {
      await wakeWordService.stop();
      setIsListening(false);

      setLastDetected(null);
      setConfidence(null);
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    } else {
      await wakeWordService.start((keyword, score) => {
        console.log(
          `Wake word detected from Kotlin: ${keyword}, Confidence: ${score}`,
        );

        setLastDetected(keyword);
        setConfidence(score as number);

        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
        }

        timeoutRef.current = setTimeout(() => {
          setLastDetected(null);
          setConfidence(null);
        }, 2000);
      });
      setIsListening(true);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>AI Assistant</Text>

      <View style={styles.statusCard}>
        <Text style={styles.statusText}>
          Engine Status: {isListening ? "🟢 Listening..." : "🔴 Stopped"}
        </Text>

        {lastDetected && confidence !== null && (
          <View style={styles.detectionContainer}>
            <Text style={styles.detectedText}>Detected: "{lastDetected}"</Text>
            <Text style={styles.confidenceText}>
              Confidence: {(confidence * 100).toFixed(1)}%
            </Text>
          </View>
        )}
      </View>

      <TouchableOpacity
        style={[
          styles.button,
          isListening ? styles.buttonStop : styles.buttonStart,
        ]}
        onPress={toggleListening}
      >
        <Text style={styles.buttonText}>
          {isListening ? "Stop Engine" : "Start Engine"}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 20,
    backgroundColor: "#f5f5f5",
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    marginBottom: 40,
    color: "#333",
  },
  statusCard: {
    width: "100%",
    padding: 20,
    backgroundColor: "#fff",
    borderRadius: 12,
    marginBottom: 40,
    alignItems: "center",
    elevation: 3,
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 5,
    minHeight: 120,
  },
  statusText: {
    fontSize: 18,
    fontWeight: "600",
    color: "#555",
  },
  detectionContainer: {
    marginTop: 15,
    alignItems: "center",
  },
  detectedText: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#007AFF",
  },
  confidenceText: {
    fontSize: 16,
    color: "#34C759",
    marginTop: 5,
    fontWeight: "500",
  },
  button: {
    paddingVertical: 15,
    paddingHorizontal: 40,
    borderRadius: 30,
  },
  buttonStart: {
    backgroundColor: "#007AFF",
  },
  buttonStop: {
    backgroundColor: "#FF3B30",
  },
  buttonText: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "bold",
  },
});
