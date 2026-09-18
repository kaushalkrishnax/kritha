import { Download, Trash2, X } from 'lucide-react-native';
import { useState } from 'react';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { modelDownloadService } from '@/services';
import { useModelStore } from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
import { ModelRecord } from '@/types';

export interface LlmModelModalProps {
  visible: boolean;
  onClose: () => void;
}

enum ModelCategory {
  Local = 'local',
  Cloud = 'cloud',
}

export function LlmModelModal({ visible, onClose }: LlmModelModalProps) {
  const [tab, setTab] = useState<ModelCategory>(ModelCategory.Local);

  const models = useModelStore((s) => s.models);
  const selectedModelId = useModelStore((s) => s.selectedModelId);
  const downloadState = useModelStore((s) => s.downloadState);

  const handleDownload = async (modelId: string) => {
    try {
      await modelDownloadService.startDownload(modelId);
    } catch (e) {
      console.warn('Failed to download', e);
    }
  };

  const handleDelete = async (modelId: string) => {
    try {
      await modelDownloadService.cancelDownload(modelId);
      useModelStore.setState((state) => ({
        models: state.models.map((m) =>
          m.id === modelId ? { ...m, downloaded: false } : m,
        ),
      }));
    } catch (e) {
      console.warn('Failed to delete', e);
    }
  };

  const handleSelect = (modelId: string) => {
    modelDownloadService.setSelectedModelId(modelId);
  };

  const currentModels = models.filter((m) =>
    tab === ModelCategory.Cloud ? m.isCloud : !m.isCloud,
  );

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlayCenter}>
        <View style={styles.modalDialog}>
          <View style={styles.modalHeader}>
            <View style={{ flex: 1 }}>
              <Text style={styles.modalTitle}>Language Models</Text>
              <Text style={styles.modalSubtitle}>
                Select an LLM for text generation.
              </Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeIconBtn}>
              <X size={IconSizes.base} color={Colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <View style={styles.tabContainer}>
            <TouchableOpacity
              style={[
                styles.tabBtn,
                tab === ModelCategory.Local && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ModelCategory.Local)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ModelCategory.Local && styles.tabTextActive,
                ]}
              >
                Local Models
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.tabBtn,
                tab === ModelCategory.Cloud && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ModelCategory.Cloud)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ModelCategory.Cloud && styles.tabTextActive,
                ]}
              >
                Cloud Models
              </Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.scrollArea}>
            {currentModels.map((m: ModelRecord) => {
              const isDl = m.downloaded || m.isCloud;
              const isSelected = selectedModelId === m.id;
              const isDownloading =
                downloadState.active && downloadState.modelId === m.id;
              const prog = downloadState.progress * 100;

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
                        {m.provider}{' '}
                        {m.totalMb ? `• ${Math.round(m.totalMb)} MB` : ''}
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
                          {!isSelected && !m.isCloud && (
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
                          {Math.round(prog)}%
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
                  {isDownloading && (
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
            })}
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
