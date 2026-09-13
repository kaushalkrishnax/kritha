import { useSpeaker } from '@/hooks';
import { AssistantBridge, settingsService } from '@/services';
import Colors from '@/theme';
import { Save, X } from 'lucide-react-native';
import { useEffect, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View
} from 'react-native';
import { KeyboardAvoidingView } from 'react-native-keyboard-controller';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

type SettingsModalProps = {
  visible: boolean;
  onClose: () => void;
};

export function SettingsModal({ visible, onClose }: SettingsModalProps) {
  const { openVoiceModal } = useSpeaker();
  const [userName, setUserName] = useState('Your Name');
  const [apiKey, setApiKey] = useState('');
  const [customInstructions, setCustomInstructions] = useState('');
  const insets = useSafeAreaInsets();

  useEffect(() => {
    if (visible) {
      loadSettings();
    }
  }, [visible]);

  const loadSettings = async () => {
    try {
      const data = await settingsService.loadSettings();
      setUserName(data.userName);
      setApiKey(data.apiKey);
      setCustomInstructions(data.customInstructions);
    } catch (e) {
      console.error('Failed to load settings', e);
    }
  };

  const handleSave = async () => {
    try {
      const nameToSave = userName.trim() || 'Your Name';
      settingsService.setUserName(nameToSave);
      await settingsService.saveApiKey(apiKey);
      settingsService.setCustomInstructions(customInstructions);

      onClose();
    } catch (e) {
      console.error('Failed to save settings', e);
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <View style={styles.modalContainer}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />

        <KeyboardAvoidingView
          behavior="padding"
          style={styles.keyboardContainer}
        >
          <View style={styles.content}>
            <View style={styles.header}>
              <Text style={styles.title}>Settings</Text>
              <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
                <X size={20} color={Colors.textMuted} />
              </TouchableOpacity>
            </View>

            <ScrollView
              style={styles.scrollArea}
              contentContainerStyle={styles.scrollContent}
              showsVerticalScrollIndicator={true}
              bounces={true}
            >
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Your Name</Text>
                <TextInput
                  style={styles.input}
                  value={userName}
                  onChangeText={setUserName}
                  placeholder="Enter your name"
                  placeholderTextColor={Colors.textMuted}
                  autoCapitalize="words"
                />
              </View>

              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Gemini API Key</Text>
                <TextInput
                  style={styles.input}
                  value={apiKey}
                  onChangeText={setApiKey}
                  placeholder="Enter API Key"
                  placeholderTextColor={Colors.textMuted}
                  secureTextEntry
                  autoCapitalize="none"
                />
              </View>

              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Voice Models</Text>
                <Text style={styles.sectionDesc}>
                  Download and select TTS & STT models.
                </Text>
                <TouchableOpacity
                  style={[
                    styles.saveBtn,
                    { marginTop: 10, backgroundColor: Colors.borderStrong },
                  ]}
                  onPress={() => {
                    onClose();
                    openVoiceModal();
                  }}
                >
                  <Text
                    style={[styles.saveText, { color: Colors.textOnAccent }]}
                  >
                    Manage Voice Models
                  </Text>
                </TouchableOpacity>
              </View>

              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Custom Instructions</Text>
                <Text style={styles.sectionDesc}>
                  What would you like Kritha to know about you to provide better
                  responses?
                </Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  value={customInstructions}
                  onChangeText={setCustomInstructions}
                  placeholder="Enter instructions..."
                  placeholderTextColor={Colors.textMuted}
                  multiline
                  textAlignVertical="top"
                />
              </View>
            </ScrollView>

            <View
              style={[
                styles.footer,
                { paddingBottom: Math.max(insets.bottom, 16) },
              ]}
            >
              <TouchableOpacity
                style={styles.saveBtn}
                activeOpacity={0.85}
                onPress={handleSave}
              >
                <Save
                  size={18}
                  color={Colors.accentPrimary}
                  style={{ marginRight: 8 }}
                />
                <Text style={styles.saveText}>Save Settings</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: Colors.bgScrim,
  },
  keyboardContainer: {
    width: '100%',
    maxHeight: '82%',
    justifyContent: 'flex-end',
  },
  content: {
    backgroundColor: Colors.bgSurface,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '100%',
    display: 'flex',
    flexDirection: 'column',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSubtle,
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  closeBtn: {
    padding: 6,
  },
  scrollArea: {
    flexShrink: 1,
  },
  scrollContent: {
    padding: 20,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  sectionDesc: {
    fontSize: 13,
    color: Colors.textMuted,
    marginBottom: 10,
    lineHeight: 18,
  },
  input: {
    backgroundColor: Colors.bgSurface,
    color: Colors.textPrimary,
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
  },
  textArea: {
    minHeight: 110,
    maxHeight: 180,
  },
  footer: {
    paddingHorizontal: 20,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSubtle,
    backgroundColor: Colors.bgSurface,
  },
  saveBtn: {
    backgroundColor: Colors.accentPrimary,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 14,
    borderRadius: 8,
  },
  saveText: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: 15,
  },
});
