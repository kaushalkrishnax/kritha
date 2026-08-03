import { useEffect, useRef, useState } from "react";
import { Modal, Pressable, StyleSheet, Text, View } from "react-native";

import { wakeWordService } from "@/services/wakeword.service";

export function ListeningOverlay() {
  const [visible, setVisible] = useState(false);
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return wakeWordService.subscribe(() => {
      setVisible(true);
      if (timeout.current) clearTimeout(timeout.current);
      timeout.current = setTimeout(() => setVisible(false), 8_000);
    });
  }, []);

  const dismiss = () => {
    if (timeout.current) clearTimeout(timeout.current);
    setVisible(false);
    wakeWordService.stopAssistantSession();
  };

  return (
    <Modal
      animationType="fade"
      onRequestClose={dismiss}
      statusBarTranslucent
      transparent={false}
      visible={visible}
    >
      <View style={styles.container}>
        <View style={styles.orb}>
          <Text style={styles.spark}>✦</Text>
        </View>
        <Text style={styles.title}>Listening…</Text>
        <Text style={styles.subtitle}>What can I help with?</Text>
        <Pressable accessibilityRole="button" onPress={dismiss} style={styles.button}>
          <Text style={styles.buttonText}>Dismiss</Text>
        </Pressable>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    backgroundColor: "#080F1E",
    flex: 1,
    justifyContent: "center",
    padding: 32,
  },
  orb: {
    alignItems: "center",
    backgroundColor: "#208AEF",
    borderRadius: 72,
    height: 144,
    justifyContent: "center",
    marginBottom: 36,
    shadowColor: "#7950F2",
    shadowOpacity: 0.9,
    shadowRadius: 36,
    width: 144,
  },
  spark: { color: "white", fontSize: 64 },
  title: { color: "white", fontSize: 36, fontWeight: "700" },
  subtitle: { color: "#B5C3DA", fontSize: 18, marginTop: 12 },
  button: {
    backgroundColor: "#1A2942",
    borderRadius: 28,
    marginTop: 48,
    paddingHorizontal: 36,
    paddingVertical: 14,
  },
  buttonText: { color: "white", fontSize: 16, fontWeight: "600" },
});
