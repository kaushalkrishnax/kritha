import { Colors } from '@/theme';
import { PermissionDescriptor } from '@/types/permissions';
import { PermissionsAndroid } from 'react-native';
import { AssistantBridge } from './app.service';

export const PERMISSION_DESCRIPTORS: PermissionDescriptor[] = [
  {
    id: 'default_assistant',
    title: 'Default Assistant',
    description:
      'Required to launch Kritha with the long-press home button shortcut.',
    icon: 'Sparkles',
    iconColor: Colors.borderAccent,
    required: true,
    check: async () => AssistantBridge.isDefaultAssistant(),
    request: async () => {
      AssistantBridge.openAssistantSettings();
      return false;
    }, // manual check
  },
  {
    id: 'microphone',
    title: 'Microphone',
    description: 'Required to use STT (Speech-to-Text) capabilities.',
    icon: 'Mic',
    iconColor: Colors.success,
    required: true,
    check: async () =>
      await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      ),
    request: async () => {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    },
  },
  {
    id: 'post_notifications',
    title: 'Post Notifications',
    description:
      'Required to let Kritha post notifications while running in the background.',
    icon: 'Bell',
    iconColor: '#F59E0B',
    required: true,
    check: async () =>
      await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
      ),
    request: async () => {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    },
  },
  {
    id: 'notification_listener',
    title: 'Notification Listener',
    description:
      'Required to allow Kritha to read incoming notifications (like messages or alerts) and act on them contextually.',
    icon: 'BellRing',
    iconColor: '#8B5CF6',
    required: false,
    check: async () => AssistantBridge.isNotificationListenerEnabled(),
    request: async () => {
      AssistantBridge.requestNotificationListenerPermission();
      return false;
    },
  },
  {
    id: 'contacts',
    title: 'Contacts',
    description:
      'Allows Kritha to read your contacts to assist with calls and messages.',
    icon: 'Users',
    iconColor: '#EC4899',
    required: false,
    check: async () =>
      await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
      ),
    request: async () => {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    },
  },
  {
    id: 'calendar',
    title: 'Calendar',
    description:
      'Required to let Kritha check your schedule and create new calendar events.',
    icon: 'CalendarDays',
    iconColor: '#06B6D4',
    required: false,
    check: async () =>
      await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.READ_CALENDAR,
      ),
    request: async () => {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.READ_CALENDAR,
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    },
  },
  {
    id: 'phone',
    title: 'Phone',
    description: 'Required to let Kritha place phone calls on your behalf.',
    icon: 'Phone',
    iconColor: '#F43F5E',
    required: false,
    check: async () =>
      await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.CALL_PHONE),
    request: async () => {
      const res = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.CALL_PHONE,
      );
      return res === PermissionsAndroid.RESULTS.GRANTED;
    },
  },
];
