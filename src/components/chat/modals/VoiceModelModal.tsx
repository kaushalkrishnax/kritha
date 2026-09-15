import { useSpeaker } from '@/hooks';
import * as assistantRuntime from '@/services/assistantRuntime.service';
import {
  deleteVoiceModel,
  downloadVoiceModel,
  listVoiceModels,
  subscribeVoiceModelProgress,
} from '@/services/soniqoRuntime.service';
import { SPEECH_MODELS } from '@/constants';
import { useVoiceStore } from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
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

enum ModelCategory {
  Tts = 'tts',
  Stt = 'stt',
}

export interface VoiceModelModalProps {
  visible: boolean;
  onClose: () => void;
}

const CATALOG_MODELS = SPEECH_MODELS.map((m) => ({
  id: m.id,
  name: m.displayName,
  size: m.id.includes('fp16')
    ? '500 MB'
    : m.type === 'stt'
      ? '250 MB'
      : '140 MB',
  langs: m.capabilities.languages.join(', '),
  category: m.type,
}));

export function VoiceModelModal({ visible, onClose }: VoiceModelModalProps) {
  const [tab, setTab] = useState<ModelCategory>(ModelCategory.Stt);
  const [downloadedIds, setDownloadedIds] = useState<Set<string>>(new Set());
  const [availableModels, setAvailableModels] = useState<
    {
      id: string;
      name: string;
      size: string;
      langs: string;
      category: string;
    }[]
  >([]);
  const [progresses, setProgresses] = useState<Record<string, number>>({});
  const [loadingAction, setLoadingAction] = useState<string | null>(null);

  const selectedSttModelId = useVoiceStore((s) => s.selectedSttModelId);
  const selectedTtsModelId = useVoiceStore((s) => s.selectedTtsModelId);
  const { setSelectedSttModelId, setSelectedTtsModelId } = useSpeaker();

  const refreshDownloaded = useCallback(async () => {
    try {
      const models = await listVoiceModels();
      setAvailableModels(models);
      const downloaded = models
        .filter((m) => m.isDownloaded && m.category === tab)
        .map((m) => m.id);
      setDownloadedIds(new Set(downloaded));
    } catch (e) {
      console.warn('Failed to load downloaded models', e);
    }
  }, [tab]);

  useEffect(() => {
    if (!visible) return;
    let isMounted = true;
    listVoiceModels()
      .then((models) => {
        if (!isMounted) return;
        setAvailableModels(models);
        const downloaded = models
          .filter((m) => m.isDownloaded && m.category === tab)
          .map((m) => m.id);
        setDownloadedIds(new Set(downloaded));
      })
      .catch((e) => {
        console.warn('Failed to load downloaded models', e);
      });

    return () => {
      isMounted = false;
    };
  }, [visible, tab]);

  useEffect(() => {
    const unsubscribe = subscribeVoiceModelProgress((event) => {
      setProgresses((prev) => ({ ...prev, [event.modelId]: event.progress }));
      if (event.progress >= 100) {
        setTimeout(refreshDownloaded, 500);
      }
    });
    return () => {
      unsubscribe();
    };
  }, [refreshDownloaded]);

  const handleDownload = async (modelId: string) => {
    setLoadingAction(modelId);
    try {
      await downloadVoiceModel(modelId);
    } catch (e) {
      console.warn('Failed to download', e);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleDelete = async (modelId: string) => {
    try {
      await deleteVoiceModel(modelId);
      refreshDownloaded();
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
    availableModels.length > 0
      ? availableModels.filter((m) => m.category === tab)
      : CATALOG_MODELS.filter((m) => m.category === tab);

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
              hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
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
    padding: 20,
    width: '90%',
    maxHeight: '80%',
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalTitle: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeLg,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  modalSubtitle: { color: Colors.textSecondary, fontSize: Typography.sizeSm },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  closeIconBtn: { padding: 4, marginLeft: 8 },
  tabContainer: {
    flexDirection: 'row',
    marginBottom: 16,
    backgroundColor: Colors.borderSubtle,
    borderRadius: Radius.sm,
    padding: 4,
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
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    marginBottom: 8,
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
    marginTop: 2,
  },
  actionsRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: Radius.lg,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconBtnText: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: Radius.lg,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  progressContainer: { marginTop: 8 },
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
    marginTop: 18,
  },
  modalBtn: {
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: Radius.sm,
  },
  modalBtnText: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: Typography.sizeBase,
  },
});
