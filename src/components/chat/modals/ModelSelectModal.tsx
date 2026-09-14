import { CheckCircle2, Download } from 'lucide-react-native';
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { Colors, IconSizes, Radius, Spacing, Typography } from '@/theme';
import { DownloadState, ModelRecord } from '@/types';

export interface ModelSelectModalProps {
  isDropdownOpen: boolean;
  onCloseDropdown: () => void;
  models: ModelRecord[];
  selectedModelId: string;
  onSelectModel: (id: string) => void;
  downloadModalModel: ModelRecord | null;
  onCloseDownloadModal: () => void;
  onStartDownload: (model: ModelRecord) => void;
  downloadState: DownloadState;
}

export function ModelSelectModal({
  isDropdownOpen,
  onCloseDropdown,
  models,
  selectedModelId,
  onSelectModel,
  downloadModalModel,
  onCloseDownloadModal,
  onStartDownload,
  downloadState,
}: ModelSelectModalProps) {
  return (
    <>
      <Modal
        visible={isDropdownOpen}
        transparent
        animationType="fade"
        onRequestClose={onCloseDropdown}
      >
        <Pressable style={styles.dropdownOverlay} onPress={onCloseDropdown}>
          <View style={styles.dropdownMenu}>
            {models.map((m) => (
              <TouchableOpacity
                key={m.id}
                style={styles.dropdownItem}
                onPress={() => onSelectModel(m.id)}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.dropdownItemText}>{m.name}</Text>
                  <Text style={styles.dropdownItemSub}>
                    {m.downloaded ? 'Downloaded' : 'Not downloaded'}
                    {m.totalMb ? ` • ${Math.round(m.totalMb)} MB` : ''}
                  </Text>
                </View>
                {m.id === selectedModelId && (
                  <CheckCircle2
                    size={IconSizes.lg}
                    color={Colors.bgPrimary}
                    fill={Colors.borderAccent}
                  />
                )}
              </TouchableOpacity>
            ))}
          </View>
        </Pressable>
      </Modal>

      <Modal
        visible={downloadModalModel !== null}
        transparent
        animationType="fade"
        onRequestClose={onCloseDownloadModal}
      >
        <View style={styles.modalOverlayCenter}>
          <View style={styles.modalDialog}>
            <Text style={styles.modalTitle}>{downloadModalModel?.name}</Text>
            {downloadModalModel?.totalMb ? (
              <Text style={styles.modalText}>
                Size: {Math.round(downloadModalModel.totalMb)} MB
              </Text>
            ) : null}
            <Text style={styles.modalText}>
              Download is required to run this model on-device.
            </Text>

            {downloadState.active && (
              <View style={styles.downloadProgressWrap}>
                <Text style={styles.modalText}>
                  Downloading... {Math.round(downloadState.progress * 100)}%
                </Text>
                <View style={styles.downloadBarBg}>
                  <View
                    style={[
                      styles.downloadBarFill,
                      { width: `${Math.round(downloadState.progress * 100)}%` },
                    ]}
                  />
                </View>
              </View>
            )}

            <View style={styles.modalActions}>
              <TouchableOpacity
                onPress={onCloseDownloadModal}
                style={[
                  styles.modalBtn,
                  { backgroundColor: Colors.borderStrong },
                ]}
              >
                <Text style={styles.modalBtnText}>Cancel</Text>
              </TouchableOpacity>
              {!downloadState.active && downloadModalModel && (
                <TouchableOpacity
                  onPress={() => onStartDownload(downloadModalModel)}
                  style={styles.modalBtn}
                >
                  <Download
                    size={IconSizes.sm}
                    color={Colors.textOnAccent}
                    style={{ marginRight: Spacing.sm }}
                  />
                  <Text style={styles.modalBtnText}>Download</Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  dropdownOverlay: {
    flex: 1,
    backgroundColor: Colors.bgScrim,
  },
  dropdownMenu: {
    position: 'absolute',
    top: 100,
    left: 60,
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.base,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    width: 260,
    padding: Spacing.sm,
    elevation: 5,
  },
  dropdownItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: Radius.sm,
  },
  dropdownItemText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeBase,
    fontWeight: '500',
  },
  dropdownItemSub: {
    color: Colors.textDimmed,
    fontSize: Typography.sizeXs,
    marginTop: Spacing['2xs'],
  },
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalDialog: {
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.base,
    padding: Spacing.xl,
    width: 310,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalTitle: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeLg,
    fontWeight: 'bold',
    marginBottom: Spacing.lg,
  },
  modalText: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeBase,
    marginBottom: Spacing.sm,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: Spacing.md,
    marginTop: Spacing.xl,
  },
  modalBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.borderAccent,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: Radius.sm,
  },
  modalBtnText: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: Typography.sizeBase,
  },
  downloadProgressWrap: {
    marginTop: Spacing.lg,
  },
  downloadBarBg: {
    height: 6,
    backgroundColor: Colors.borderStrong,
    borderRadius: Radius.xs,
    overflow: 'hidden',
    marginVertical: Spacing.sm,
  },
  downloadBarFill: {
    height: '100%',
    backgroundColor: Colors.borderAccent,
  },
});
