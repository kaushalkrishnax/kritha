import Colors from '@/theme';
import { CheckCircle2, Download } from 'lucide-react-native';
import {
    Modal,
    Pressable,
    StyleSheet,
    Text,
    TouchableOpacity,
    View,
} from 'react-native';

import { DownloadState, ModelRecord } from '@/components/chat/types';

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
                    size={24}
                    color={Colors.bgElevated}
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
                    size={16}
                    color={Colors.textOnAccent}
                    style={{ marginRight: 6 }}
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
    backgroundColor: Colors.bgElevated,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    width: 250,
    padding: 8,
    elevation: 5,
  },
  dropdownItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    borderRadius: 6,
  },
  dropdownItemText: {
    color: Colors.textPrimary,
    fontSize: 14,
  },
  dropdownItemSub: {
    color: Colors.textDimmed,
    fontSize: 11,
  },
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalDialog: {
    backgroundColor: Colors.bgElevated,
    borderRadius: 12,
    padding: 20,
    width: 300,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalTitle: {
    color: Colors.textOnAccent,
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  modalText: {
    color: Colors.textSecondary,
    fontSize: 14,
    marginBottom: 8,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 20,
  },
  modalBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.borderAccent,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  modalBtnText: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: 14,
  },
  downloadProgressWrap: {
    marginTop: 16,
  },
  downloadBarBg: {
    height: 6,
    backgroundColor: Colors.borderStrong,
    borderRadius: 3,
    overflow: 'hidden',
    marginVertical: 8,
  },
  downloadBarFill: {
    height: '100%',
    backgroundColor: Colors.borderAccent,
  },
});
