import { Download, Trash2, X } from 'lucide-react-native';
import { useEffect, useState } from 'react';
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
import { SttEngine, TtsEngine } from '@/services';
import { useVoiceStore } from '@/store';
import Colors from '@/theme';
import { stubAction } from '@/utils';

type Progress = any;
enum ModelCategory {
  Tts = 'tts',
  Stt = 'stt',
}
const deleteModel = async (...args: any[]) => stubAction('deleteModel');
const ensureModel = async (...args: any[]) => stubAction('ensureModel');
const listDownloadedModels = async (...args: any[]) => { stubAction('listDownloadedModels'); return []; };
const onProgress = (...args: any[]) => stubAction('onProgress');
const refreshModels = async (...args: any[]) => stubAction('refreshModels');

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
  

  useEffect(() => {
    if (visible) {
      loadDownloaded();
    }
  }, [visible, tab]);

  useEffect(() => {
    const unsub = onProgress((_: any, modelId: string, progress: Progress) => {
      setProgresses((prev) => ({ ...prev, [modelId]: progress.percent }));
      if (progress.percent >= 100) {
        setTimeout(loadDownloaded, 500);
      }
    });
    return unsub;
  }, []);

  const loadDownloaded = async () => {
    try {
      const dl = await listDownloadedModels(tab);
      setDownloadedIds(new Set(dl.map((d: any) => d.id || d)));
    } catch (e) {
      console.warn('Failed to load downloaded models', e);
    }
  };

  const handleDownload = async (modelId: string) => {
    setLoadingAction(modelId);
    try {
      // Warm up the cache so the SDK can find the model metadata internally
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
    if (tab === ModelCategory.Stt) {
      setSelectedSttModelId(modelId);
      await TtsEngine.destroy();
    } else {
      setSelectedTtsModelId(modelId);
      await TtsEngine.destroy();
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
              hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            >
              <X size={20} color={Colors.textMuted} />
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
                                <Trash2 size={16} color={'#FF5252'} />
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
                            <Download size={18} color={Colors.textOnAccent} />
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
    backgroundColor: 'rgba(0,0,0,0.65)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalDialog: {
    backgroundColor: Colors.bgElevated,
    borderRadius: 14,
    padding: 20,
    width: '90%',
    maxHeight: '80%',
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalTitle: {
    color: Colors.textOnAccent,
    fontSize: 19,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  modalSubtitle: { color: Colors.textSecondary, fontSize: 13 },
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
    borderRadius: 8,
    padding: 4,
  },
  tabBtn: {
    flex: 1,
    paddingVertical: 8,
    alignItems: 'center',
    borderRadius: 6,
  },
  tabBtnActive: { backgroundColor: Colors.bgCard },
  tabText: { color: Colors.textSecondary, fontSize: 14, fontWeight: '500' },
  tabTextActive: { color: Colors.textOnAccent, fontWeight: 'bold' },
  scrollArea: { maxHeight: 400 },
  optionCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: 10,
    padding: 12,
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
  optionTitle: { color: Colors.textPrimary, fontSize: 15, fontWeight: '600' },
  optionSub: { color: Colors.textDimmed, fontSize: 12, marginTop: 2 },
  actionsRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  iconBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconBtnText: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    backgroundColor: Colors.borderAccent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  progressContainer: { marginTop: 8 },
  downloadBarBg: {
    height: 4,
    backgroundColor: Colors.borderStrong,
    borderRadius: 2,
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
  modalBtn: { paddingHorizontal: 18, paddingVertical: 9, borderRadius: 8 },
  modalBtnText: { color: Colors.textOnAccent, fontWeight: '600', fontSize: 14 },
});
