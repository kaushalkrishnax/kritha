import { AlertCircle, Download } from 'lucide-react-native';
import { useCallback, useEffect } from 'react';
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { updateService } from '@/services/update.service';
import { useUpdateStore } from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';

export interface UpdateModalProps {
  visible: boolean;
  onClose: () => void;
}

export function UpdateModal({ visible, onClose }: UpdateModalProps) {
  const { appUpdate, markAppUpdateSeen } = useUpdateStore();
  const { available, info } = appUpdate;

  useEffect(() => {
    if (visible && available && info) {
      markAppUpdateSeen(info.latestVersion);
    }
  }, [visible, available, info, markAppUpdateSeen]);

  const handleViewRelease = useCallback(() => {
    updateService.openReleaseUrl();
    onClose();
  }, [onClose]);

  const handleLater = useCallback(() => {
    onClose();
  }, [onClose]);

  if (!visible || !available || !info) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={handleLater}
    >
      <View style={styles.modalOverlayCenter}>
        <Pressable style={StyleSheet.absoluteFill} onPress={handleLater} />
        <View style={styles.modalDialog}>
          <View style={styles.modalHeader}>
            <View style={styles.iconContainer}>
              <AlertCircle size={IconSizes.xl} color={Colors.accentBlue} />
            </View>
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={styles.modalTitle}>Update Available</Text>
              <Text style={styles.modalSubtitle}>
                Version {info.latestVersion} is now available
              </Text>
            </View>
          </View>

          {info.releaseNotes && (
            <View style={styles.releaseNotesContainer}>
              <Text style={styles.releaseNotesTitle}>{`What's new`}</Text>
              <Text style={styles.releaseNotesText} numberOfLines={6}>
                {info.releaseNotes}
              </Text>
            </View>
          )}

          <View style={styles.modalActions}>
            <TouchableOpacity
              onPress={handleLater}
              style={[
                styles.modalBtn,
                { backgroundColor: Colors.bgCard },
              ]}
            >
              <Text style={styles.modalBtnTextSecondary}>Later</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={handleViewRelease}
              style={styles.modalBtnPrimary}
            >
              <Download size={IconSizes.sm} color={Colors.textOnAccent} />
              <Text style={styles.modalBtnTextPrimary}>View Release</Text>
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
    paddingHorizontal: 16,
  },
  modalDialog: {
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.base,
    padding: 20,
    width: '100%',
    maxWidth: 400,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  iconContainer: {
    width: 44,
    height: 44,
    borderRadius: Radius.full,
    backgroundColor: Colors.accentBlue + '20',
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeLg,
    fontWeight: 'bold',
  },
  modalSubtitle: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeSm,
    marginTop: 2,
  },
  releaseNotesContainer: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.sm,
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    marginBottom: 16,
  },
  releaseNotesTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeSm,
    fontWeight: '600',
    marginBottom: 8,
  },
  releaseNotesText: {
    color: Colors.textSecondary,
    fontSize: Typography.sizeXs,
    lineHeight: 20,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 10,
  },
  modalBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: Radius.sm,
  },
  modalBtnPrimary: {
    backgroundColor: Colors.accentBlue,
  },
  modalBtnTextPrimary: {
    color: Colors.textOnAccent,
    fontWeight: '600',
    fontSize: Typography.sizeBase,
  },
  modalBtnTextSecondary: {
    color: Colors.textPrimary,
    fontWeight: '600',
    fontSize: Typography.sizeBase,
  },
});

export default UpdateModal;