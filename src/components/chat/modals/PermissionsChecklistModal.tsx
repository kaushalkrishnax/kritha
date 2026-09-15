import { usePermissionsChecklist } from '@/hooks';
import { settingsService } from '@/services';
import { PermissionDescriptor } from '@/types/permissions';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
import {
  Bell,
  BellRing,
  Calendar,
  Check,
  ChevronRight,
  Mic,
  Phone,
  Settings,
  Sparkles,
  Users,
  X,
} from 'lucide-react-native';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  AppState,
  Easing,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const ICON_MAP: Record<string, any> = {
  Sparkles,
  Mic,
  Bell,
  BellRing,
  Users,
  CalendarDays: Calendar,
  Phone,
};

const SETTINGS_PERMISSION_IDS = new Set([
  'default_assistant',
  'notification_listener',
]);

const AUTO_REQUEST_PERMISSION_IDS = new Set([
  'microphone',
  'post_notifications',
  'contacts',
  'calendar',
  'phone',
]);

function withAlpha(hex: string, alpha: number) {
  const clean = hex.replace('#', '');
  const r = parseInt(clean.substring(0, 2), 16);
  const g = parseInt(clean.substring(2, 4), 16);
  const b = parseInt(clean.substring(4, 6), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

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

  const [isProcessing, setIsProcessing] = useState(false);

  const [activePermissionId, setActivePermissionId] = useState<string | null>(
    null,
  );

  const [hasStartedRequests, setHasStartedRequests] = useState(false);

  const [progressAnim] = useState(() => new Animated.Value(0));

  useEffect(() => {
    if (visible) {
      refresh();
    }
  }, [visible, refresh]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active' && visible) {
        refresh();
      }
    });

    return () => subscription.remove();
  }, [visible, refresh]);

  const grantedCount = descriptors.filter((descriptor) =>
    Boolean(status[descriptor.id]),
  ).length;

  const totalCount = descriptors.length;

  useEffect(() => {
    Animated.timing(progressAnim, {
      toValue: totalCount ? grantedCount / totalCount : 0,
      duration: 450,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: false,
    }).start();
  }, [grantedCount, totalCount, progressAnim]);

  const handleContinue = useCallback(async () => {
    if (isProcessing) {
      return;
    }

    setIsProcessing(true);
    setHasStartedRequests(true);

    try {
      for (const descriptor of descriptors) {
        if (
          AUTO_REQUEST_PERMISSION_IDS.has(descriptor.id) &&
          !status[descriptor.id]
        ) {
          setActivePermissionId(descriptor.id);

          try {
            await request(descriptor.id);
          } catch (error) {
            console.warn(
              `Failed to request permission '${descriptor.id}':`,
              error,
            );
          }
        }
      }
    } finally {
      setActivePermissionId(null);
      setIsProcessing(false);

      settingsService.markPermissionsOnboardingSeen();
      onClose();
    }
  }, [descriptors, status, request, isProcessing, onClose]);

  const handleSettingsPermission = useCallback(
    async (id: string) => {
      if (isProcessing) {
        return;
      }

      setActivePermissionId(id);

      try {
        await request(id);
      } catch (error) {
        console.warn(`Failed to request permission '${id}':`, error);
      } finally {
        setActivePermissionId(null);
      }
    },
    [isProcessing, request],
  );

  const renderItem = (descriptor: PermissionDescriptor) => {
    const isGranted = Boolean(status[descriptor.id]);

    const isSpecial = SETTINGS_PERMISSION_IDS.has(descriptor.id);

    const isActive = activePermissionId === descriptor.id;

    const Icon = ICON_MAP[descriptor.icon] ?? Settings;

    return (
      <View
        key={descriptor.id}
        style={[
          styles.permissionCard,
          isGranted && styles.permissionCardGranted,
        ]}
      >
        <View
          style={[
            styles.permissionIconTile,
            { backgroundColor: withAlpha(descriptor.iconColor, 0.14) },
          ]}
        >
          <Icon
            size={IconSizes.base}
            color={isGranted ? Colors.accentLightBlue : descriptor.iconColor}
            strokeWidth={1.8}
          />
        </View>

        <View style={styles.permissionBody}>
          <Text style={styles.permissionTitle}>{descriptor.title}</Text>

          <Text style={styles.permissionDescription}>
            {descriptor.description}
          </Text>
        </View>

        <View style={styles.permissionAction}>
          {isGranted ? (
            <View style={styles.grantedIndicator}>
              <Check
                size={IconSizes.xs}
                color={Colors.accentLightBlue}
                strokeWidth={3}
              />
            </View>
          ) : isActive ? (
            <ActivityIndicator size="small" color={Colors.accentLightBlue} />
          ) : isSpecial ? (
            <TouchableOpacity
              activeOpacity={0.7}
              onPress={() => void handleSettingsPermission(descriptor.id)}
              style={styles.allowButton}
            >
              <Text style={styles.allowButtonText}>Allow</Text>

              <ChevronRight
                size={IconSizes.xs}
                color={Colors.accentLightBlue}
                strokeWidth={2.5}
              />
            </TouchableOpacity>
          ) : null}
        </View>
      </View>
    );
  };

  const requiredDescriptors = descriptors.filter((d) => d.required);

  const optionalDescriptors = descriptors.filter((d) => !d.required);

  const progressWidth = progressAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      onRequestClose={onClose}
    >
      <View style={styles.modalContainer}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <View style={styles.headerContent}>
              <Text style={styles.title}>Permissions</Text>

              <Text style={styles.subtitle}>
                {grantedCount} of {totalCount} enabled
              </Text>

              <View style={styles.progressTrack}>
                <Animated.View
                  style={[styles.progressFill, { width: progressWidth }]}
                />
              </View>
            </View>

            <TouchableOpacity
              activeOpacity={0.7}
              onPress={onClose}
              style={styles.closeButton}
            >
              <X size={IconSizes.md} color={Colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.scrollContent}
          >
            <Text style={styles.sectionLabel}>Core</Text>

            {requiredDescriptors.map(renderItem)}

            <Text style={[styles.sectionLabel, styles.sectionLabelSpaced]}>
              Optional
            </Text>

            {optionalDescriptors.map(renderItem)}

            {hasStartedRequests && !isProcessing && (
              <Text style={styles.note}>
                Permissions can also be changed later from Android settings.
              </Text>
            )}
          </ScrollView>

          <View
            style={[
              styles.footer,
              { paddingBottom: Math.max(insets.bottom, 16) },
            ]}
          >
            <TouchableOpacity
              activeOpacity={0.85}
              onPress={handleContinue}
              disabled={isProcessing}
              style={[
                styles.continueButton,
                isProcessing && styles.continueButtonDisabled,
              ]}
            >
              {isProcessing ? (
                <ActivityIndicator color={Colors.textOnAccent} />
              ) : (
                <Text style={styles.continueButtonText}>Continue</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

export default PermissionsChecklistModal;

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: Colors.bgScrim,
  },

  sheet: {
    width: '100%',
    maxHeight: '68%',
    backgroundColor: Colors.bgSecondary,
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    overflow: 'hidden',
  },

  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSubtle,
  },

  headerContent: {
    flex: 1,
    paddingRight: 12,
  },

  title: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeLg,
    fontWeight: '700',
    lineHeight: 22,
  },

  subtitle: {
    color: Colors.textMuted,
    fontSize: Typography.sizeSm,
    lineHeight: 18,
    marginTop: 3,
  },

  progressTrack: {
    height: 4,
    marginTop: 12,
    borderRadius: Radius.xs,
    backgroundColor: Colors.borderStrong,
    overflow: 'hidden',
  },

  progressFill: {
    height: '100%',
    borderRadius: Radius.xs,
    backgroundColor: Colors.accentLightBlue,
  },

  closeButton: {
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: Radius.full,
    backgroundColor: Colors.borderFaint,
  },

  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 16,
  },

  sectionLabel: {
    color: Colors.textDimmed,
    fontSize: Typography.sizeXs,
    fontWeight: '600',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
    marginBottom: 10,
  },

  sectionLabelSpaced: {
    marginTop: 20,
  },

  permissionCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.sm,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    paddingVertical: 13,
    paddingHorizontal: 14,
    marginBottom: 10,
  },

  permissionCardGranted: {
    borderColor: Colors.accentLightBlue,
    backgroundColor: 'rgba(0, 229, 255, 0.05)',
  },

  permissionIconTile: {
    width: 40,
    height: 40,
    borderRadius: Radius.sm,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 13,
  },

  permissionBody: {
    flex: 1,
    paddingRight: 8,
  },

  permissionTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeBase,
    fontWeight: '600',
    lineHeight: 20,
  },

  permissionDescription: {
    color: Colors.textMuted,
    fontSize: Typography.sizeSm,
    lineHeight: 18,
    marginTop: 2,
  },

  permissionAction: {
    minWidth: 28,
    minHeight: 28,
    alignItems: 'flex-end',
    justifyContent: 'center',
    marginLeft: 4,
  },

  grantedIndicator: {
    width: 26,
    height: 26,
    borderRadius: Radius.full,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0, 229, 255, 0.12)',
  },

  allowButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: Radius.full,
    backgroundColor: 'rgba(96, 165, 250, 0.12)',
  },

  allowButtonText: {
    color: Colors.accentLightBlue,
    fontSize: Typography.sizeXs,
    fontWeight: '600',
  },

  note: {
    color: Colors.textDimmed,
    fontSize: Typography.sizeXs,
    lineHeight: 17,
    paddingTop: 6,
    paddingBottom: 4,
  },

  footer: {
    paddingHorizontal: 20,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSubtle,
  },

  continueButton: {
    minHeight: 48,
    borderRadius: Radius.base,
    backgroundColor: Colors.accentBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },

  continueButtonDisabled: {
    opacity: 0.65,
  },

  continueButtonText: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeMd,
    fontWeight: '700',
  },
});
