import {
    getRuntimes,
    installRuntimes,
    RuntimeInfo,
    subscribeRuntimeInstallProgress,
} from '@/services/runtime.service';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
import { Download, X } from 'lucide-react-native';
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

enum ExtensionsTab {
  Extensions = 'extensions',
  Runtimes = 'runtimes',
}

export interface ExtensionsRuntimesModalProps {
  visible: boolean;
  onClose: () => void;
  initialTab?: ExtensionsTab;
}

const FALLBACK_RUNTIMES: RuntimeInfo[] = [
  {
    id: 'litert',
    module: 'feature-litert',
    installed: false,
    displayName: 'LiteRT',
    description: 'On-device LiteRT execution for speech and vision tasks.',
    capabilities: ['inference', 'tts', 'asr'],
  },
  {
    id: 'litert-lm',
    module: 'feature-litertlm',
    installed: false,
    displayName: 'LiteRT-LM',
    description: 'On-device local LLM execution via LiteRT-LM.',
    capabilities: ['llm'],
  },
  {
    id: 'onnx',
    module: 'feature-onnx',
    installed: false,
    displayName: 'ONNX Runtime',
    description:
      'On-device inference, speech, and local LLM execution via ONNX Runtime.',
    capabilities: ['inference', 'tts', 'asr', 'llm'],
  },
];

function statusLabel(status: string | undefined, installed: boolean): string {
  switch (status) {
    case 'CHECKING':
      return 'Checking…';
    case 'INSTALLING':
      return 'Installing…';
    case 'READY':
    case 'INSTALLED':
      return 'Ready';
    case 'FAILED':
      return 'Failed';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return installed ? 'Installed' : 'Not installed';
  }
}

export function ExtensionsRuntimesModal({
  visible,
  onClose,
  initialTab = ExtensionsTab.Extensions,
}: ExtensionsRuntimesModalProps) {
  const [tab, setTab] = useState<ExtensionsTab>(initialTab);
  const [runtimes, setRuntimes] = useState<RuntimeInfo[]>(FALLBACK_RUNTIMES);
  const [statuses, setStatuses] = useState<Record<string, string>>({});
  const [progresses, setProgresses] = useState<Record<string, number>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [installingId, setInstallingId] = useState<string | null>(null);

  useEffect(() => {
    if (visible) setTab(initialTab);
  }, [visible, initialTab]);

  const refresh = useCallback(async () => {
    try {
      const list = await getRuntimes();
      if (list.length > 0) setRuntimes(list);
    } catch (e) {
      console.warn('Failed to list runtimes', e);
    }
  }, []);

  useEffect(() => {
    if (!visible) return;
    refresh();
  }, [visible, refresh]);

  useEffect(() => {
    if (!visible) return;
    const unsubscribe = subscribeRuntimeInstallProgress((event) => {
      setStatuses((prev) => ({ ...prev, [event.runtimeId]: event.status }));
      if (typeof event.progress === 'number') {
        const progress = event.progress;
        setProgresses((prev) => ({ ...prev, [event.runtimeId]: progress }));
      }
      if (event.status === 'READY' || event.status === 'INSTALLED') {
        setErrors((prev) => {
          const next = { ...prev };
          delete next[event.runtimeId];
          return next;
        });
        setInstallingId((current) =>
          current === event.runtimeId ? null : current,
        );
        refresh();
      }
      if (event.status === 'FAILED' || event.status === 'CANCELLED') {
        setInstallingId((current) =>
          current === event.runtimeId ? null : current,
        );
      }
    });
    return () => {
      unsubscribe();
    };
  }, [visible, refresh]);

  const handleInstall = async (runtimeId: string) => {
    setInstallingId(runtimeId);
    setErrors((prev) => {
      const next = { ...prev };
      delete next[runtimeId];
      return next;
    });
    try {
      const results = await installRuntimes(runtimeId);
      const result = results.find((r) => r.id === runtimeId) ?? results[0];
      if (result) {
        if (result.error) {
          setErrors((prev) => ({
            ...prev,
            [runtimeId]: result.error as string,
          }));
        }
        if (result.installed) {
          setStatuses((prev) => ({ ...prev, [runtimeId]: 'READY' }));
        }
      }
      refresh();
    } catch (e) {
      setErrors((prev) => ({
        ...prev,
        [runtimeId]: e instanceof Error ? e.message : 'Install failed',
      }));
    } finally {
      setInstallingId((current) => (current === runtimeId ? null : current));
    }
  };

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
              <Text style={styles.modalTitle}>Extensions & Runtimes</Text>
              <Text style={styles.modalSubtitle}>
                Manage extensions and on-device runtimes.
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
                tab === ExtensionsTab.Extensions && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ExtensionsTab.Extensions)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ExtensionsTab.Extensions && styles.tabTextActive,
                ]}
              >
                Extensions
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.tabBtn,
                tab === ExtensionsTab.Runtimes && styles.tabBtnActive,
              ]}
              onPress={() => setTab(ExtensionsTab.Runtimes)}
            >
              <Text
                style={[
                  styles.tabText,
                  tab === ExtensionsTab.Runtimes && styles.tabTextActive,
                ]}
              >
                Runtimes
              </Text>
            </TouchableOpacity>
          </View>

          {tab === ExtensionsTab.Extensions ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyTitle}>No extensions available</Text>
              <Text style={styles.emptySub}>
                Extensions will appear here when they are supported.
              </Text>
            </View>
          ) : (
            <ScrollView style={styles.scrollArea}>
              {runtimes.map((runtime) => {
                const status = statuses[runtime.id];
                const progress = progresses[runtime.id];
                const error = errors[runtime.id];
                const isReady =
                  status === 'READY' ||
                  status === 'INSTALLED' ||
                  (status === undefined && runtime.installed);
                const isBusy =
                  installingId === runtime.id ||
                  status === 'CHECKING' ||
                  status === 'INSTALLING';

                return (
                  <View key={runtime.id} style={styles.optionCard}>
                    <View style={styles.optionHeader}>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.optionTitle}>
                          {runtime.displayName}
                        </Text>
                        <Text style={styles.optionSub}>
                          {runtime.description}
                        </Text>
                        <Text style={styles.optionMeta}>
                          {runtime.capabilities.join(' • ')} —{' '}
                          {statusLabel(status, runtime.installed)}
                          {isBusy && typeof progress === 'number'
                            ? ` ${Math.round(progress)}%`
                            : ''}
                        </Text>
                        {error ? (
                          <Text style={styles.optionError}>{error}</Text>
                        ) : null}
                      </View>

                      <View style={styles.actionsRow}>
                        {isReady ? (
                          <Text style={styles.readyBadge}>Ready</Text>
                        ) : isBusy ? (
                          <Text style={styles.progressText}>
                            {typeof progress === 'number'
                              ? `${Math.round(progress)}%`
                              : 'Working…'}
                          </Text>
                        ) : (
                          <TouchableOpacity
                            style={styles.iconBtn}
                            onPress={() => handleInstall(runtime.id)}
                          >
                            <Download
                              size={IconSizes.sm}
                              color={Colors.textOnAccent}
                            />
                          </TouchableOpacity>
                        )}
                      </View>
                    </View>
                    {isBusy && typeof progress === 'number' && (
                      <View style={styles.progressContainer}>
                        <View style={styles.downloadBarBg}>
                          <View
                            style={[
                              styles.downloadBarFill,
                              { width: `${progress}%` },
                            ]}
                          />
                        </View>
                      </View>
                    )}
                  </View>
                );
              })}
            </ScrollView>
          )}

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
  emptyState: {
    paddingVertical: 32,
    alignItems: 'center',
  },
  emptyTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeBase,
    fontWeight: '600',
    marginBottom: 6,
  },
  emptySub: {
    color: Colors.textDimmed,
    fontSize: Typography.sizeSm,
    textAlign: 'center',
  },
  scrollArea: { maxHeight: 400 },
  optionCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.sm,
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    marginBottom: 8,
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
  optionMeta: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeXs,
    marginTop: 6,
  },
  optionError: {
    color: Colors.error,
    fontSize: Typography.sizeXs,
    marginTop: 6,
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
  readyBadge: {
    color: Colors.success,
    fontWeight: '700',
    fontSize: Typography.sizeSm,
  },
  progressText: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeSm,
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
