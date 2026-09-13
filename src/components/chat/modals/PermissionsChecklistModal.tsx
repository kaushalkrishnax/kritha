import {
  AlertCircle,
  Bell,
  BellRing,
  Calendar,
  CheckCircle2,
  ChevronRight,
  Mic,
  Phone,
  Settings,
  Sparkles,
  Users,
  X,
} from 'lucide-react-native';
import React, { useEffect } from 'react';
import {
  AppState,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { usePermissionsChecklist } from '@/hooks';
import { settingsService } from '@/services';
import Colors from '@/theme';

const ICON_MAP: Record<string, any> = {
  Sparkles,
  Mic,
  Bell,
  BellRing,
  Users,
  CalendarDays: Calendar, // Fallback to Calendar if CalendarDays is missing
  Phone,
};

interface PermissionsChecklistModalProps {
  visible: boolean;
  onClose: () => void;
}

export function PermissionsChecklistModal({
  visible,
  onClose,
}: PermissionsChecklistModalProps) {
  const insets = useSafeAreaInsets();
  const { status, refresh, request, descriptors } = usePermissionsChecklist();

  useEffect(() => {
    if (visible) refresh();
  }, [visible, refresh]);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active' && visible) refresh();
    });
    return () => sub.remove();
  }, [visible, refresh]);

  const handleDone = () => {
    settingsService.markPermissionsOnboardingSeen();
    onClose();
  };

  const requiredDescriptors = descriptors.filter((d) => d.required);
  const optionalDescriptors = descriptors.filter((d) => !d.required);

  const renderCard = (desc: (typeof descriptors)[0]) => {
    const isGranted = status[desc.id] || false;
    const Icon = ICON_MAP[desc.icon] || Settings;

    return (
      <View
        key={desc.id}
        style={[styles.card, isGranted && styles.cardGranted]}
      >
        <View style={styles.cardHeader}>
          <View style={styles.iconCircle}>
            <Icon size={20} color={desc.iconColor} />
          </View>
          <View style={styles.cardTitleArea}>
            <Text style={styles.cardTitle}>{desc.title}</Text>
            <Text style={styles.cardDesc}>{desc.description}</Text>
          </View>
          {isGranted ? (
            <CheckCircle2 size={22} color={Colors.success} />
          ) : (
            <AlertCircle size={22} color={Colors.textMuted} />
          )}
        </View>
        {!isGranted && (
          <TouchableOpacity
            style={styles.actionBtnSecondary}
            activeOpacity={0.8}
            onPress={() => request(desc.id)}
          >
            <Text style={styles.actionBtnSecondaryText}>
              Allow {desc.title}
            </Text>
            <ChevronRight size={16} color={Colors.textPrimary} />
          </TouchableOpacity>
        )}
      </View>
    );
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={styles.modalContainer}>
        <View style={styles.content}>
          <View style={styles.header}>
            <View style={styles.headerTitleRow}>
              <Settings
                size={20}
                color={Colors.textPrimary}
                style={{ marginRight: 8 }}
              />
              <Text style={styles.title}>System Access</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <X size={20} color={Colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView
            style={styles.scrollArea}
            contentContainerStyle={styles.scrollContent}
          >
            <Text style={styles.subtitle}>
              Kritha runs deeply integrated into your Android device. Review and
              grant the necessary permissions below.
            </Text>

            <Text style={styles.sectionHeader}>CORE REQUIREMENTS</Text>
            {requiredDescriptors.map(renderCard)}

            <Text style={[styles.sectionHeader, { marginTop: 16 }]}>
              OPTIONAL ENHANCEMENTS
            </Text>
            {optionalDescriptors.map(renderCard)}
          </ScrollView>

          <View
            style={[
              styles.footer,
              { paddingBottom: Math.max(insets.bottom, 16) },
            ]}
          >
            <TouchableOpacity
              style={styles.doneBtn}
              activeOpacity={0.85}
              onPress={handleDone}
            >
              <Text style={styles.doneBtnText}>Continue</Text>
            </TouchableOpacity>
          </View>
        </View>
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
  content: {
    backgroundColor: Colors.bgSurface,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '82%',
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
  headerTitleRow: { flexDirection: 'row', alignItems: 'center' },
  title: { fontSize: 18, fontWeight: '700', color: Colors.textPrimary },
  closeBtn: { padding: 6 },
  scrollArea: { flexShrink: 1 },
  scrollContent: { paddingHorizontal: 20, paddingTop: 16, paddingBottom: 16 },
  subtitle: {
    fontSize: 13,
    color: Colors.textMuted,
    marginBottom: 14,
    lineHeight: 18,
  },
  sectionHeader: {
    fontSize: 11,
    fontWeight: '700',
    color: Colors.textDimmed,
    letterSpacing: 1,
    marginTop: 8,
    marginBottom: 8,
  },
  card: {
    backgroundColor: Colors.bgElevated,
    borderRadius: 16,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
  },
  cardGranted: { borderColor: 'rgba(16, 185, 129, 0.3)' },
  cardHeader: { flexDirection: 'row', alignItems: 'flex-start' },
  iconCircle: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: Colors.borderFaint,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  cardTitleArea: { flex: 1, marginRight: 8 },
  cardTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 2,
  },
  cardDesc: { fontSize: 12, color: Colors.textMuted, lineHeight: 16 },
  actionBtnSecondary: {
    marginTop: 10,
    backgroundColor: Colors.borderFaint,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 9,
    paddingHorizontal: 14,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    gap: 4,
  },
  actionBtnSecondaryText: {
    color: Colors.textPrimary,
    fontSize: 13,
    fontWeight: '600',
  },
  footer: {
    paddingHorizontal: 20,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSubtle,
  },
  doneBtn: {
    backgroundColor: Colors.accentPrimary,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 13,
    borderRadius: 12,
  },
  doneBtnText: { color: Colors.textOnAccent, fontSize: 15, fontWeight: '700' },
});
