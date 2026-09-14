import { Download, Trash2, X } from 'lucide-react-native';
import { useCallback, useEffect, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSpeaker } from '@/hooks';
import * as assistantRuntime from '@/services/assistantRuntime.service';
import { useVoiceStore } from '@/stores';
import { Colors, IconSizes, Radius, Spacing, Typography } from '@/theme';
import { stubAction } from '@/utils';

type Progress = any;
enum ModelCategory {
  Tts = 'tts',
  Stt = 'stt',
}
const deleteModel = async (...args: any[]) =>
  stubAction('VoiceModelModal.deleteModel');
const ensureModel = async (...args: any[]) =>
  stubAction('VoiceModelModal.ensureModel');
const listDownloadedModels = async (...args: any[]) => {
  stubAction('VoiceModelModal.listDownloadedModels');
  return [];
};
const onProgress = (...args: any[]) => stubAction('VoiceModelModal.onProgress');
const refreshModels = async (...args: any[]) =>
  stubAction('VoiceModelModal.refreshModels');

export interface VoiceModelModalProps {
  visible: boolean;
  onClose: () => void;
}

const HARDCODED_MODELS = {
  [ModelCategory.Stt]: [
    {
      id: 'sherpa-onnx-streaming-zipformer-en-2023-02-21',
      name: 'Ultra-Fast (Zipformer INT8)',
      size: '18 MB',
      langs: 'English',
    },
    {
      id: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
      name: 'Accurate (Zipformer)',
      size: '137 MB',
      langs: 'English',
    },
    {
      id: 'sherpa-onnx-moonshine-tiny-en-int8',
      name: 'Offline Speed (Moonshine)',
      size: '41 MB',
      langs: 'English',
    },
    {
      id: 'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17',
      name: 'Multilingual Fast (SenseVoice)',
      size: '150 MB',
      langs: 'EN/ZH/JA/KO',
    },
    {
      id: 'sherpa-onnx-cohere-transcribe-14-lang-int8-2026-04-01',
      name: 'Cohere Transcribe (14 Langs)',
      size: '110 MB',
      langs: 'Multilingual',
    },
  ],
  [ModelCategory.Tts]: [
    {
      id: 'kokoro-int8-en-v0_19',
      name: 'Kokoro (Expressive & Natural)',
      size: '82 MB',
      langs: 'English',
    },
    {
      id: 'matcha-icefall-en_US-ljspeech',
      name: 'Matcha TTS (Fast)',
      size: '60 MB',
      langs: 'English',
    },
    {
      id: 'vits-piper-en_US-amy-low',
      name: 'Piper (Amy, Low Latency)',
      size: '14 MB',
      langs: 'English',
    },
    {
      id: 'vits-coqui-en-ljspeech',
      name: 'VITS LJSpeech (Classic)',
      size: '28 MB',
      langs: 'English',
    },
    {
      id: 'sherpa-onnx-supertonic-tts-int8-2026-03-06',
      name: 'Supertonic 2026 (INT8)',
      size: '50 MB',
      langs: 'English',
    },
  ],
};

export function VoiceModelModal({ visible, onClose }: VoiceModelModalProps) {
  const [tab, setTab] = useState<ModelCategory>(ModelCategory.Stt);
  const [downloadedIds, setDownloadedIds] = useState<Set<string>>(new Set());
  const [progresses, setProgresses] = useState<Record<string, number>>({});
  const [loadingAction, setLoadingAction] = useState<string | null>(null);

  const selectedSttModelId = useVoiceStore((s) => s.selectedSttModelId);
  const selectedTtsModelId = useVoiceStore((s) => s.selectedTtsModelId);
  const { setSelectedSttModelId, setSelectedTtsModelId } = useSpeaker();

  const loadDownloaded = useCallback(async () => {
    try {
      const dl = await listDownloadedModels(tab);
      setDownloadedIds(new Set(dl.map((d: any) => d.id || d)));
    } catch (e) {
      console.warn('Failed to load downloaded models', e);
    }
  }, [tab]);

  useEffect(() => {
    if (!visible) return;
    listDownloadedModels(tab)
      .then((dl) => setDownloadedIds(new Set(dl.map((d: any) => d.id || d))))
      .catch((e) => console.warn('Failed to load downloaded models', e));
  }, [visible, tab]);

  useEffect(() => {
    const unsub = onProgress((_: any, modelId: string, progress: Progress) => {
      setProgresses((prev) => ({ ...prev, [modelId]: progress.percent }));
      if (progress.percent >= 100) {
        setTimeout(loadDownloaded, 500);
      }
    });
    return unsub;
  }, [loadDownloaded]);

  const handleDownload = async (modelId: string) => {
    setLoadingAction(modelId);
    try {
      await refreshModels(tab);
      await ensureModel(tab, modelId);
    } catch (e) {
      console.warn('Failed to download', e);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleDelete = async (modelId: string) => {
    try {
      await deleteModel(tab, modelId);
      loadDownloaded();
    } catch (e) {
      console.warn('Failed to delete', e);
    }
  };

  const handleSelect = async (modelId: string) => {
    assistantRuntime.stopSpeaking();

    if (tab === ModelCategory.Stt) {
      setSelectedSttModelId(modelId);
    } else {
      setSelectedTtsModelId(modelId);
    }
  };

  const currentModels =
    HARDCODED_MODELS[tab as keyof typeof HARDCODED_MODELS] || [];

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlayCenter}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <View style={styles.modalDialog}>
          <View style={styles.modalHeader}>
            <View style={{ flex: 1 }}>
              <Text style={styles.modalTitle}>Voice Models</Text>
              <Text style={styles.modalSubtitle}>
                Select and download models.
              </Text>
            </View>
            <TouchableOpacity
              onPress={onClose}
              style={styles.closeIconBtn}
              hitSlop={{
                top: Spacing.sm,
                bottom: Spacing.sm,
                left: Spacing.sm,
                right: Spacing.sm,
              }}
            >
              <X size={IconSizes.base} color={Colors.textMuted} />
            </TouchableOpacity>
          </View>

          <View style={styles.tabContainer}>
            <TouchableOpacity
              style={[
                styles.tabBtn,
                tab === ModelCategory.Stt && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ModelCategory.Stt)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ModelCategory.Stt && styles.tabTextActive,
                ]}
              >
                STT (Dictation)
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.tabBtn,
                tab === ModelCategory.Tts && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ModelCategory.Tts)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ModelCategory.Tts && styles.tabTextActive,
                ]}
              >
                TTS (Assistant)
              </Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.scrollArea}>
            {currentModels.map(
              (m: {
                id: string;
                name: string;
                size: string;
                langs: string;
              }) => {
                const isDl = downloadedIds.has(m.id);
                const isSelected =
                  (tab === ModelCategory.Stt
                    ? selectedSttModelId
                    : selectedTtsModelId) === m.id;
                const prog = progresses[m.id];
                const isDownloading =
                  (prog !== undefined && prog < 100 && !isDl) ||
                  loadingAction === m.id;

                return (
                  <View
                    key={m.id}
                    style={[
                      styles.optionCard,
                      isSelected && styles.optionCardSelected,
                    ]}
                  >
                    <View style={styles.optionHeader}>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.optionTitle}>{m.name}</Text>
                        <Text style={styles.optionSub}>
                          {m.size} • {m.langs}
                        </Text>
                      </View>

                      <View style={styles.actionsRow}>
                        {isDl ? (
                          <>
                            <TouchableOpacity
                              style={styles.iconBtnText}
                              onPress={() => handleSelect(m.id)}
                            >
                              <Text
                                style={{
                                  color: Colors.textOnAccent,
                                  fontWeight: 'bold',
                                }}
                              >
                                {isSelected ? 'Selected' : 'Select'}
                              </Text>
                            </TouchableOpacity>
                            {!isSelected && (
                              <TouchableOpacity
                                style={styles.iconBtn}
                                onPress={() => handleDelete(m.id)}
                              >
                                <Trash2
                                  size={IconSizes.sm}
                                  color={Colors.error}
                                />
                              </TouchableOpacity>
                            )}
                          </>
                        ) : isDownloading ? (
                          <Text style={{ color: Colors.textSecondary }}>
                            {prog !== undefined ? Math.round(prog) : 0}%
                          </Text>
                        ) : (
                          <TouchableOpacity
                            style={styles.iconBtn}
                            onPress={() => handleDownload(m.id)}
                          >
                            <Download
                              size={IconSizes.sm}
                              color={Colors.textOnAccent}
                            />
                          </TouchableOpacity>
                        )}
                      </View>
                    </View>
                    {isDownloading && prog !== undefined && (
                      <View style={styles.progressContainer}>
                        <View style={styles.downloadBarBg}>
                          <View
                            style={[
                              styles.downloadBarFill,
                              { width: `${prog}%` },
                            ]}
                          />
                        </View>
                      </View>
                    )}
                  </View>
                );
              },
            )}
          </ScrollView>

          <View style={styles.modalActions}>
            <TouchableOpacity
              onPress={onClose}
              style={[
                styles.modalBtn,
                { backgroundColor: Colors.borderStrong },
              ]}
            >
              <Text style={styles.modalBtnText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: Colors.bgScrim,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalDialog: {
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.base,
    padding: Spacing.xl,
    width: '90%',
    maxHeight: '80%',
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalTitle: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeLg,
    fontWeight: 'bold',
    marginBottom: Spacing.xs,
  },
  modalSubtitle: { color: Colors.textSecondary, fontSize: Typography.sizeSm },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: Spacing.lg,
  },
  closeIconBtn: { padding: Spacing.xs, marginLeft: Spacing.sm },
  tabContainer: {
    flexDirection: 'row',
    marginBottom: Spacing.lg,
    backgroundColor: Colors.borderSubtle,
    borderRadius: Radius.sm,
    padding: Spacing.xs,
  },
  tabBtn: {
    flex: 1,
    paddingVertical: 9,
    alignItems: 'center',
    borderRadius: Radius.xs,
  },
  tabBtnActive: { backgroundColor: Colors.bgCard },
  tabText: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeBase,
    fontWeight: '500',
  },
  tabTextActive: { color: Colors.textOnAccent, fontWeight: 'bold' },
  scrollArea: { maxHeight: 400 },
  optionCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.sm,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    marginBottom: Spacing.sm,
  },
  optionCardSelected: {
    borderColor: Colors.accentCyan,
    backgroundColor: 'rgba(0, 229, 255, 0.05)',
  },
  optionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  optionTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeBase,
    fontWeight: '600',
  },
  optionSub: {
    color: Colors.textDimmed,
    fontSize: Typography.sizeXs,
    marginTop: Spacing['2xs'],
  },
  actionsRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: Radius.lg,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconBtnText: {
    paddingHorizontal: Spacing.md,
    paddingVertical: 7,
    borderRadius: Radius.lg,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  progressContainer: { marginTop: Spacing.sm },
  downloadBarBg: {
    height: 4,
    backgroundColor: Colors.borderStrong,
    borderRadius: Radius.xs,
    overflow: 'hidden',
  },
  downloadBarFill: {
    height: '100%',
    backgroundColor: Colors.accentCyan,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: Spacing.lg,
  },
  modalBtn: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: Radius.sm,
  },
  modalBtnText: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: Typography.sizeBase,
  },
});
