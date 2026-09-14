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
import { useEffect } from 'react';
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
import { Colors, IconSizes, Radius, Spacing, Typography } from '@/theme';

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
            <Icon size={IconSizes.base} color={desc.iconColor} />
          </View>
          <View style={styles.cardTitleArea}>
            <Text style={styles.cardTitle}>{desc.title}</Text>
            <Text style={styles.cardDesc}>{desc.description}</Text>
          </View>
          {isGranted ? (
            <CheckCircle2 size={IconSizes.md} color={Colors.success} />
          ) : (
            <AlertCircle size={IconSizes.md} color={Colors.textMuted} />
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
            <ChevronRight size={IconSizes.sm} color={Colors.textPrimary} />
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
                size={IconSizes.base}
                color={Colors.textPrimary}
                style={{ marginRight: Spacing.sm }}
              />
              <Text style={styles.title}>System Access</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <X size={IconSizes.base} color={Colors.textSecondary} />
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

            <Text style={[styles.sectionHeader, { marginTop: Spacing.lg }]}>
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
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    maxHeight: '82%',
    flexDirection: 'column',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.xl,
    paddingVertical: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSubtle,
  },
  headerTitleRow: { flexDirection: 'row', alignItems: 'center' },
  title: {
    fontSize: Typography.sizeLg,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  closeBtn: { padding: Spacing.sm },
  scrollArea: { flexShrink: 1 },
  scrollContent: {
    paddingHorizontal: Spacing.xl,
    paddingTop: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
  subtitle: {
    fontSize: Typography.sizeSm,
    color: Colors.textMuted,
    marginBottom: Spacing.md,
    lineHeight: 18,
  },
  sectionHeader: {
    fontSize: Typography.size2xs,
    fontWeight: '700',
    color: Colors.textDimmed,
    letterSpacing: 1,
    marginTop: Spacing.sm,
    marginBottom: Spacing.sm,
  },
  card: {
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.md,
    padding: Spacing.md,
    marginBottom: Spacing.md,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
  },
  cardGranted: { borderColor: 'rgba(16, 185, 129, 0.3)' },
  cardHeader: { flexDirection: 'row', alignItems: 'flex-start' },
  iconCircle: {
    width: 36,
    height: 36,
    borderRadius: Radius.lg,
    backgroundColor: Colors.borderFaint,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  cardTitleArea: { flex: 1, marginRight: Spacing.sm },
  cardTitle: {
    fontSize: Typography.sizeBase,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: Spacing['2xs'],
  },
  cardDesc: {
    fontSize: Typography.sizeSm,
    color: Colors.textMuted,
    lineHeight: 18,
  },
  actionBtnSecondary: {
    marginTop: Spacing.md,
    backgroundColor: Colors.borderFaint,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.md,
    borderRadius: Radius.sm,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    gap: Spacing.xs,
  },
  actionBtnSecondaryText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeSm,
    fontWeight: '600',
  },
  footer: {
    paddingHorizontal: Spacing.xl,
    paddingTop: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSubtle,
  },
  doneBtn: {
    backgroundColor: Colors.accentBlue,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    borderRadius: Radius.base,
  },
  doneBtnText: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeBase,
    fontWeight: '700',
  },
});
