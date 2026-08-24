import React, { useEffect, useState } from 'react';
import {
  Modal,
  View,
  Text,
  TouchableOpacity,
  Pressable,
  StyleSheet,
  ScrollView,
  Platform,
  PermissionsAndroid,
  Permission,
} from 'react-native';
import {
  ShieldCheck,
  CheckCircle2,
  AlertCircle,
  X,
  ChevronRight,
  Mic,
  Bell,
  Bot,
  BellRing,
  UserCheck,
  Calendar,
  Phone,
} from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as SecureStore from 'expo-secure-store';
import {
  isDefaultAssistant,
  openAssistantSettings,
  isNotificationListenerEnabled,
  requestNotificationListenerPermission,
} from '@modules/kritha/src';
import Colors from '@/theme';

export const PERMISSIONS_ONBOARDING_KEY = 'KRITHA_HAS_SEEN_PERMISSIONS_V1';

type PermissionsChecklistModalProps = {
  visible: boolean;
  onClose: () => void;
};

export function PermissionsChecklistModal({
  visible,
  onClose,
}: PermissionsChecklistModalProps) {
  const insets = useSafeAreaInsets();

  // Required permissions
  const [defaultAssistantStatus, setDefaultAssistantStatus] =
    useState<boolean>(false);
  const [micStatus, setMicStatus] = useState<boolean>(false);
  const [postNotificationsStatus, setPostNotificationsStatus] =
    useState<boolean>(false);

  // Optional permissions
  const [notificationListenerStatus, setNotificationListenerStatus] =
    useState<boolean>(false);
  const [contactsStatus, setContactsStatus] = useState<boolean>(false);
  const [calendarStatus, setCalendarStatus] = useState<boolean>(false);
  const [phoneStatus, setPhoneStatus] = useState<boolean>(false);

  useEffect(() => {
    if (visible) {
      checkAllPermissions();
    }
  }, [visible]);

  const checkAllPermissions = async () => {
    try {
      if (Platform.OS === 'android') {
        const isDefault = isDefaultAssistant();
        setDefaultAssistantStatus(isDefault);

        const isNotif = isNotificationListenerEnabled();
        setNotificationListenerStatus(isNotif);

        if (PermissionsAndroid.PERMISSIONS.RECORD_AUDIO) {
          setMicStatus(
            await PermissionsAndroid.check(
              PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
            ),
          );
        }
        if (PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS) {
          setPostNotificationsStatus(
            await PermissionsAndroid.check(
              PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
            ),
          );
        }
        if (PermissionsAndroid.PERMISSIONS.READ_CONTACTS) {
          setContactsStatus(
            await PermissionsAndroid.check(
              PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
            ),
          );
        }
        if (PermissionsAndroid.PERMISSIONS.READ_CALENDAR) {
          setCalendarStatus(
            await PermissionsAndroid.check(
              PermissionsAndroid.PERMISSIONS.READ_CALENDAR,
            ),
          );
        }
        if (PermissionsAndroid.PERMISSIONS.CALL_PHONE) {
          setPhoneStatus(
            await PermissionsAndroid.check(
              PermissionsAndroid.PERMISSIONS.CALL_PHONE,
            ),
          );
        }
      } else {
        setDefaultAssistantStatus(true);
        setMicStatus(true);
        setNotificationListenerStatus(true);
        setPostNotificationsStatus(true);
        setContactsStatus(true);
        setCalendarStatus(true);
        setPhoneStatus(true);
      }
    } catch (e) {
      console.error('Error checking permissions:', e);
    }
  };

  const handleRequestDefaultAssistant = () => {
    openAssistantSettings();
    setTimeout(checkAllPermissions, 1500);
  };

  const handleRequestNotificationListener = () => {
    requestNotificationListenerPermission();
    setTimeout(checkAllPermissions, 1500);
  };

  const handleRequestGenericPermission = async (
    permission: Permission | string,
    title: string,
    message: string,
    setStatus: (granted: boolean) => void,
  ) => {
    if (Platform.OS !== 'android') return;
    try {
      const result = await PermissionsAndroid.request(
        permission as Permission,
        {
          title,
          message,
          buttonPositive: 'Allow',
          buttonNegative: 'Cancel',
        },
      );
      const granted = result === PermissionsAndroid.RESULTS.GRANTED;
      setStatus(granted);
    } catch (e) {
      console.error(`Error requesting permission ${permission}:`, e);
    }
  };

  const allRequiredGranted =
    defaultAssistantStatus && micStatus && postNotificationsStatus;

  const handleDone = async () => {
    if (Platform.OS === 'android') {
      if (!defaultAssistantStatus) {
        handleRequestDefaultAssistant();
        return;
      }
      if (!micStatus) {
        await handleRequestGenericPermission(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          'Microphone Access',
          'Kritha requires microphone access for voice commands.',
          setMicStatus,
        );
        return;
      }
      if (!postNotificationsStatus) {
        await handleRequestGenericPermission(
          PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
          'Notification Permission',
          'Kritha needs permission to display notifications.',
          setPostNotificationsStatus,
        );
        return;
      }
    }
    try {
      await SecureStore.setItemAsync(PERMISSIONS_ONBOARDING_KEY, 'true');
    } catch (e) {
      console.error('Error saving permissions onboarding key:', e);
    }
    onClose();
  };

  const handleBackdropPress = () => {
    if (allRequiredGranted) {
      onClose();
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={() => {
        if (allRequiredGranted) onClose();
      }}
    >
      <View style={styles.modalContainer}>
        <Pressable
          style={StyleSheet.absoluteFill}
          onPress={handleBackdropPress}
        />

        <View style={styles.content}>
          <View style={styles.header}>
            <View style={styles.headerTitleRow}>
              <ShieldCheck
                size={24}
                color={Colors.accentPrimary}
                style={{ marginRight: 10 }}
              />
              <Text style={styles.title}>System Permissions</Text>
            </View>
            {allRequiredGranted ? (
              <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
                <X size={20} color={Colors.textMuted} />
              </TouchableOpacity>
            ) : null}
          </View>

          <ScrollView
            style={styles.scrollArea}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={true}
            bounces={true}
          >
            <Text style={styles.subtitle}>
              Configure system permissions for Kritha. Required permissions must
              be granted to continue.
            </Text>

            <Text style={styles.sectionHeader}>REQUIRED SETUP</Text>

            {/* Required 1: Default Digital Assistant */}
            <View
              style={[
                styles.card,
                defaultAssistantStatus && styles.cardGranted,
              ]}
            >
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <Bot size={20} color={Colors.accentPrimary} />
                </View>
                <View style={styles.cardTitleArea}>
                  <View
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Text style={styles.cardTitle}>
                      Default Digital Assistant
                    </Text>
                    <Text style={styles.requiredBadge}>REQUIRED</Text>
                  </View>
                  <Text style={styles.cardDesc}>
                    Triggers wake word and native overlay assistant across your
                    device.
                  </Text>
                </View>
                {defaultAssistantStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.warning} />
                )}
              </View>

              {!defaultAssistantStatus && (
                <TouchableOpacity
                  style={styles.actionBtn}
                  activeOpacity={0.8}
                  onPress={handleRequestDefaultAssistant}
                >
                  <Text style={styles.actionBtnText}>
                    Set as Default Assistant
                  </Text>
                  <ChevronRight size={16} color={Colors.textOnAccent} />
                </TouchableOpacity>
              )}
            </View>

            {/* Required 2: Microphone Access */}
            <View style={[styles.card, micStatus && styles.cardGranted]}>
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <Mic size={20} color={Colors.accentCyan} />
                </View>
                <View style={styles.cardTitleArea}>
                  <View
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Text style={styles.cardTitle}>Microphone Access</Text>
                    <Text style={styles.requiredBadge}>REQUIRED</Text>
                  </View>
                  <Text style={styles.cardDesc}>
                    Enables voice commands, wake word, and LiveTalk mode.
                  </Text>
                </View>
                {micStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.warning} />
                )}
              </View>
              {!micStatus && (
                <TouchableOpacity
                  style={styles.actionBtn}
                  activeOpacity={0.8}
                  onPress={() =>
                    handleRequestGenericPermission(
                      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
                      'Microphone Access',
                      'Kritha requires microphone access for voice input.',
                      setMicStatus,
                    )
                  }
                >
                  <Text style={styles.actionBtnText}>Allow Microphone</Text>
                  <ChevronRight size={16} color={Colors.textOnAccent} />
                </TouchableOpacity>
              )}
            </View>

            {/* Required 3: Post Notifications */}
            <View
              style={[
                styles.card,
                postNotificationsStatus && styles.cardGranted,
              ]}
            >
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <BellRing size={20} color={Colors.accentSky} />
                </View>
                <View style={styles.cardTitleArea}>
                  <View
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Text style={styles.cardTitle}>Post Notifications</Text>
                    <Text style={styles.requiredBadge}>REQUIRED</Text>
                  </View>
                  <Text style={styles.cardDesc}>
                    Displays status and alert notifications.
                  </Text>
                </View>
                {postNotificationsStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.warning} />
                )}
              </View>
              {!postNotificationsStatus && (
                <TouchableOpacity
                  style={styles.actionBtn}
                  activeOpacity={0.8}
                  onPress={() =>
                    handleRequestGenericPermission(
                      PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
                      'Notification Permission',
                      'Kritha needs permission to send status notifications.',
                      setPostNotificationsStatus,
                    )
                  }
                >
                  <Text style={styles.actionBtnText}>Allow Notifications</Text>
                  <ChevronRight size={16} color={Colors.textOnAccent} />
                </TouchableOpacity>
              )}
            </View>

            <Text style={styles.sectionHeader}>OPTIONAL PERMISSIONS</Text>

            {/* Optional 1: Notification Listener */}
            <View
              style={[
                styles.card,
                notificationListenerStatus && styles.cardGranted,
              ]}
            >
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <Bell size={20} color={Colors.accentSky} />
                </View>
                <View style={styles.cardTitleArea}>
                  <Text style={styles.cardTitle}>Notification Listener</Text>
                  <Text style={styles.cardDesc}>
                    Reads notifications to provide instant AI summaries.
                  </Text>
                </View>
                {notificationListenerStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.textMuted} />
                )}
              </View>
              {!notificationListenerStatus && (
                <TouchableOpacity
                  style={styles.actionBtnSecondary}
                  activeOpacity={0.8}
                  onPress={handleRequestNotificationListener}
                >
                  <Text style={styles.actionBtnSecondaryText}>
                    Enable Notification Listener
                  </Text>
                  <ChevronRight size={16} color={Colors.textPrimary} />
                </TouchableOpacity>
              )}
            </View>

            {/* Optional 2: Contacts Access */}
            <View style={[styles.card, contactsStatus && styles.cardGranted]}>
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <UserCheck size={20} color={Colors.accentPrimary} />
                </View>
                <View style={styles.cardTitleArea}>
                  <Text style={styles.cardTitle}>Contacts Access</Text>
                  <Text style={styles.cardDesc}>
                    Resolves contact names for voice calls and messages.
                  </Text>
                </View>
                {contactsStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.textMuted} />
                )}
              </View>
              {!contactsStatus && (
                <TouchableOpacity
                  style={styles.actionBtnSecondary}
                  activeOpacity={0.8}
                  onPress={() =>
                    handleRequestGenericPermission(
                      PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
                      'Contacts Access',
                      'Kritha needs access to contacts for voice resolution.',
                      setContactsStatus,
                    )
                  }
                >
                  <Text style={styles.actionBtnSecondaryText}>
                    Allow Contacts
                  </Text>
                  <ChevronRight size={16} color={Colors.textPrimary} />
                </TouchableOpacity>
              )}
            </View>

            {/* Optional 3: Calendar Access */}
            <View style={[styles.card, calendarStatus && styles.cardGranted]}>
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <Calendar size={20} color={Colors.accentCyan} />
                </View>
                <View style={styles.cardTitleArea}>
                  <Text style={styles.cardTitle}>Calendar Access</Text>
                  <Text style={styles.cardDesc}>
                    Reads upcoming events and schedules reminders.
                  </Text>
                </View>
                {calendarStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.textMuted} />
                )}
              </View>
              {!calendarStatus && (
                <TouchableOpacity
                  style={styles.actionBtnSecondary}
                  activeOpacity={0.8}
                  onPress={() =>
                    handleRequestGenericPermission(
                      PermissionsAndroid.PERMISSIONS.READ_CALENDAR,
                      'Calendar Access',
                      'Kritha needs access to calendar for event management.',
                      setCalendarStatus,
                    )
                  }
                >
                  <Text style={styles.actionBtnSecondaryText}>
                    Allow Calendar
                  </Text>
                  <ChevronRight size={16} color={Colors.textPrimary} />
                </TouchableOpacity>
              )}
            </View>

            {/* Optional 4: Direct Phone Calls */}
            <View style={[styles.card, phoneStatus && styles.cardGranted]}>
              <View style={styles.cardHeader}>
                <View style={styles.iconCircle}>
                  <Phone size={20} color={Colors.accentPrimary} />
                </View>
                <View style={styles.cardTitleArea}>
                  <Text style={styles.cardTitle}>Direct Phone Calls</Text>
                  <Text style={styles.cardDesc}>
                    Initiates phone calls directly via voice.
                  </Text>
                </View>
                {phoneStatus ? (
                  <CheckCircle2 size={22} color={Colors.success} />
                ) : (
                  <AlertCircle size={22} color={Colors.textMuted} />
                )}
              </View>
              {!phoneStatus && (
                <TouchableOpacity
                  style={styles.actionBtnSecondary}
                  activeOpacity={0.8}
                  onPress={() =>
                    handleRequestGenericPermission(
                      PermissionsAndroid.PERMISSIONS.CALL_PHONE,
                      'Phone Call Permission',
                      'Kritha needs permission to place phone calls.',
                      setPhoneStatus,
                    )
                  }
                >
                  <Text style={styles.actionBtnSecondaryText}>
                    Allow Direct Calling
                  </Text>
                  <ChevronRight size={16} color={Colors.textPrimary} />
                </TouchableOpacity>
              )}
            </View>
          </ScrollView>

          <View
            style={[
              styles.footer,
              { paddingBottom: Math.max(insets.bottom, 16) },
            ]}
          >
            <TouchableOpacity
              style={[
                styles.doneBtn,
                !allRequiredGranted && styles.doneBtnDisabled,
              ]}
              activeOpacity={0.85}
              onPress={handleDone}
            >
              <Text style={styles.doneBtnText}>
                {allRequiredGranted
                  ? 'Continue'
                  : !defaultAssistantStatus
                    ? 'Set Default Assistant'
                    : 'Grant Required Permissions'}
              </Text>
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
    display: 'flex',
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
  headerTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  closeBtn: {
    padding: 6,
  },
  scrollArea: {
    flexShrink: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 16,
  },
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
  cardGranted: {
    borderColor: 'rgba(16, 185, 129, 0.3)',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  iconCircle: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: Colors.borderFaint,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  cardTitleArea: {
    flex: 1,
    marginRight: 8,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 2,
  },
  requiredBadge: {
    fontSize: 9,
    fontWeight: '700',
    color: Colors.warning,
    backgroundColor: 'rgba(245, 158, 11, 0.15)',
    paddingHorizontal: 5,
    paddingVertical: 1,
    borderRadius: 4,
    marginBottom: 2,
  },
  cardDesc: {
    fontSize: 12,
    color: Colors.textMuted,
    lineHeight: 16,
  },
  actionBtn: {
    marginTop: 10,
    backgroundColor: Colors.accentPrimary,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 9,
    paddingHorizontal: 14,
    borderRadius: 10,
    gap: 4,
  },
  actionBtnText: {
    color: Colors.textOnAccent,
    fontSize: 13,
    fontWeight: '600',
  },
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
  doneBtnDisabled: {
    backgroundColor: Colors.warning,
  },
  doneBtnText: {
    color: Colors.textOnAccent,
    fontSize: 15,
    fontWeight: '700',
  },
});
