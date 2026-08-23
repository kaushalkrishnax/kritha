import { useEffect, useState, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  PermissionsAndroid,
  Platform,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
} from "react-native";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
  cancelAnimation,
} from "react-native-reanimated";
import { wakeWordService } from "../services/wakeword.service";
import { cloudService } from "../services/cloud.service";


export default function Index() {
  const [hasPermission, setHasPermission] = useState(false);
  const [isListening, setIsListening] = useState(wakeWordService.getIsRunning());
  const [assistantState, setAssistantState] = useState<string>("idle");
  const [transcript, setTranscript] = useState<string>("");
  const [responseText, setResponseText] = useState<string>("");
  const [errorText, setErrorText] = useState<string>("");

  const [lastDetected, setLastDetected] = useState<string | null>(null);
  const [confidence, setConfidence] = useState<number | null>(null);

  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Animation values
  const scale = useSharedValue(1);
  const opacity = useSharedValue(0);

  useEffect(() => {
    async function checkMicPermission() {
      if (Platform.OS === "android") {
        const granted = await PermissionsAndroid.check(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        );
        setHasPermission(granted);
        setIsListening(wakeWordService.getIsRunning());
      }
    }

    void checkMicPermission();

    const unsubscribeWakeWord = wakeWordService.subscribe((keyword, score) => {
      console.log(
        `Wake word detected from Android: ${keyword}, Confidence: ${score}`,
      );
      setLastDetected(keyword);
      setConfidence(score ?? null);

      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      timeoutRef.current = setTimeout(() => {
        setLastDetected(null);
        setConfidence(null);
      }, 8000);
    });

    const unsubscribeAssistant = wakeWordService.subscribeToAssistant(async (event) => {
      console.log("Assistant event:", event);



      setAssistantState(event.state);
      if (event.transcript !== undefined && event.transcript !== null) {
        setTranscript(event.transcript);
      }
      if (event.response !== undefined && event.response !== null) {
        setResponseText(event.response);
      }
      if (event.error !== undefined && event.error !== null) {
        setErrorText(event.error);
      }
    });

    return () => {
      unsubscribeWakeWord();
      unsubscribeAssistant();
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, []);

  useEffect(() => {
    if (assistantState === "listening") {
      scale.value = withRepeat(
        withSequence(
          withTiming(1.3, { duration: 1000 }),
          withTiming(1.0, { duration: 1000 })
        ),
        -1,
        true
      );
      opacity.value = withRepeat(
        withSequence(
          withTiming(0.6, { duration: 1000 }),
          withTiming(0.1, { duration: 1000 })
        ),
        -1,
        true
      );
    } else {
      cancelAnimation(scale);
      cancelAnimation(opacity);
      scale.value = withTiming(1.0);
      opacity.value = withTiming(0);
    }
  }, [assistantState]);

  const pulseStyle = useAnimatedStyle(() => {
    return {
      transform: [{ scale: scale.value }],
      opacity: opacity.value,
    };
  });

  const toggleListening = async () => {
    if (!hasPermission) {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      );
      const allowed = granted === PermissionsAndroid.RESULTS.GRANTED;
      setHasPermission(allowed);
      if (!allowed) return;
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
      await wakeWordService.start();
      setIsListening(true);
    }
  };

  const triggerAssistant = async () => {
    if (!hasPermission) {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      );
      const allowed = granted === PermissionsAndroid.RESULTS.GRANTED;
      setHasPermission(allowed);
      if (!allowed) return;
    }

    setTranscript("");
    setResponseText("");
    setErrorText("");
    setAssistantState("listening");

    // Starts the assistant session natively (and starts service if not already running)
    wakeWordService.triggerAssistantSession();
  };

  const handlePressButton = () => {
    if (assistantState === "listening" || assistantState === "processing") {
      void wakeWordService.stopAssistantSession();
      setAssistantState("idle");
    } else {
      void triggerAssistant();
    }
  };

  const getAssistantStatusText = () => {
    switch (assistantState) {
      case "listening":
        return "Listening...";
      case "processing":
        return "Thinking...";
      case "finished":
        return "Command Executed";
      case "error":
        return "Assistant Error";
      default:
        return "Ready to Assist";
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Kritha AI Assistant</Text>

      <ScrollView contentContainerStyle={styles.scrollContent} style={styles.scroll}>
        <View style={styles.statusCard}>
          <Text style={styles.statusTitle}>Assistant Status</Text>
          <Text style={styles.statusText}>{getAssistantStatusText()}</Text>

          {assistantState === "processing" && (
            <ActivityIndicator size="small" color="#6366f1" style={{ marginTop: 12 }} />
          )}

           {!!transcript && transcript.length > 0 && (
            <View style={styles.bubbleContainer}>
              <Text style={styles.bubbleLabel}>You said</Text>
              <View style={styles.transcriptBubble}>
                <Text style={styles.transcriptText}>{transcript}</Text>
              </View>
            </View>
          )}

          {!!responseText && responseText.length > 0 && (
            <View style={styles.bubbleContainer}>
              <Text style={styles.bubbleLabel}>Kritha</Text>
              <View style={styles.responseBubble}>
                <Text style={styles.responseText}>{responseText}</Text>
              </View>
            </View>
          )}

          {!!errorText && errorText.length > 0 && (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{errorText}</Text>
            </View>
          )}

          {lastDetected && confidence !== null && (
            <View style={styles.detectionContainer}>
              <Text style={styles.detectedText}>Wake Word Detected!</Text>
              <Text style={styles.confidenceText}>
                Confidence: {(confidence * 100).toFixed(1)}%
              </Text>
            </View>
          )}
        </View>

        {/* Pulsating Trigger Button */}
        <View style={styles.micButtonContainer}>
          <Animated.View style={[styles.pulseRing, pulseStyle]} />
          <TouchableOpacity
            style={[
              styles.micButton,
              (assistantState === "listening" || assistantState === "processing")
                ? styles.micButtonActive
                : styles.micButtonInactive,
            ]}
            onPress={handlePressButton}
            activeOpacity={0.85}
          >
            <Text style={styles.micIcon}>
              {assistantState === "listening" ? "🔊" : assistantState === "processing" ? "⚡" : "🎙️"}
            </Text>
            <Text style={styles.micButtonText}>Hey Kritha</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Secondary Toggle for Background Service */}
      <TouchableOpacity
        style={[
          styles.toggleButton,
          isListening ? styles.toggleActive : styles.toggleInactive,
        ]}
        onPress={toggleListening}
        activeOpacity={0.8}
      >
        <Text style={styles.toggleButtonText}>
          {isListening
            ? "Background Listening is ON 🟢"
            : "Background Listening is OFF 🔴"}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#0F172A", // Dark blue-slate background
    paddingTop: Platform.OS === "android" ? 40 : 60,
    paddingHorizontal: 20,
    alignItems: "center",
  },
  scroll: {
    width: "100%",
    flex: 1,
  },
  scrollContent: {
    alignItems: "center",
    paddingBottom: 40,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#F8FAFC",
    marginBottom: 25,
    letterSpacing: 0.5,
  },
  statusCard: {
    width: "100%",
    padding: 20,
    backgroundColor: "#1E293B", // slate-800
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#334155",
    alignItems: "center",
    minHeight: 120,
    marginBottom: 40,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 5,
  },
  statusTitle: {
    fontSize: 12,
    color: "#94A3B8",
    textTransform: "uppercase",
    fontWeight: "600",
    marginBottom: 6,
    letterSpacing: 1,
  },
  statusText: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#F1F5F9",
    textAlign: "center",
  },
  bubbleContainer: {
    width: "100%",
    marginTop: 15,
  },
  bubbleLabel: {
    fontSize: 11,
    color: "#64748B",
    fontWeight: "700",
    marginBottom: 4,
    textTransform: "uppercase",
  },
  transcriptBubble: {
    width: "100%",
    padding: 14,
    backgroundColor: "#334155",
    borderRadius: 12,
    borderTopLeftRadius: 0,
  },
  transcriptText: {
    fontSize: 16,
    color: "#E2E8F0",
    fontStyle: "italic",
  },
  responseBubble: {
    width: "100%",
    padding: 14,
    backgroundColor: "rgba(99, 102, 241, 0.15)",
    borderWidth: 1,
    borderColor: "rgba(99, 102, 241, 0.3)",
    borderRadius: 12,
    borderTopRightRadius: 0,
  },
  responseText: {
    fontSize: 16,
    color: "#C7D2FE",
    fontWeight: "500",
  },
  errorContainer: {
    width: "100%",
    marginTop: 15,
    padding: 12,
    backgroundColor: "rgba(239, 68, 68, 0.1)",
    borderWidth: 1,
    borderColor: "rgba(239, 68, 68, 0.3)",
    borderRadius: 12,
  },
  errorText: {
    fontSize: 14,
    color: "#FCA5A5",
    textAlign: "center",
  },
  detectionContainer: {
    marginTop: 15,
    alignItems: "center",
    padding: 10,
    borderRadius: 10,
    backgroundColor: "rgba(16, 185, 129, 0.1)",
    borderWidth: 1,
    borderColor: "rgba(16, 185, 129, 0.2)",
  },
  detectedText: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#34D399",
  },
  confidenceText: {
    fontSize: 13,
    color: "#6EE7B7",
    marginTop: 2,
  },
  micButtonContainer: {
    width: 170,
    height: 170,
    justifyContent: "center",
    alignItems: "center",
    marginVertical: 20,
  },
  pulseRing: {
    position: "absolute",
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: "rgba(99, 102, 241, 0.4)",
  },
  micButton: {
    width: 130,
    height: 130,
    borderRadius: 65,
    justifyContent: "center",
    alignItems: "center",
    shadowColor: "#6366f1",
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 10,
    elevation: 8,
  },
  micButtonActive: {
    backgroundColor: "#EF4444", // red when recording
    shadowColor: "#ef4444",
  },
  micButtonInactive: {
    backgroundColor: "#6366F1", // indigo when idle
  },
  micIcon: {
    fontSize: 42,
    marginBottom: 4,
  },
  micButtonText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "bold",
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  toggleButton: {
    width: "100%",
    paddingVertical: 14,
    borderRadius: 30,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: Platform.OS === "android" ? 30 : 50,
    borderWidth: 1,
  },
  toggleActive: {
    backgroundColor: "rgba(16, 185, 129, 0.1)",
    borderColor: "rgba(16, 185, 129, 0.4)",
  },
  toggleInactive: {
    backgroundColor: "rgba(100, 116, 139, 0.1)",
    borderColor: "rgba(100, 116, 139, 0.3)",
  },
  toggleButtonText: {
    fontSize: 15,
    fontWeight: "600",
    color: "#F1F5F9",
  },
});
