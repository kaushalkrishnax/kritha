import '@/global.css';

import { Platform } from 'react-native';

export const Colors = {
  light: {
    background: '#FFFFFF',
    surface: '#F7F7F8',
    surfaceElevated: '#FFFFFF',

    text: '#111111',
    textSecondary: '#666666',
    textTertiary: '#999999',

    primary: '#5B5CF0',
    primaryForeground: '#FFFFFF',

    success: '#22C55E',
    warning: '#F59E0B',
    error: '#EF4444',

    border: '#E5E7EB',
    borderStrong: '#D1D5DB',

    hover: '#F1F5F9',
    pressed: '#E2E8F0',
    selected: '#DBEAFE',

    assistantBubble: '#F3F4F6',
    assistantBubbleText: '#111111',

    userBubble: '#5B5CF0',
    userBubbleText: '#FFFFFF',

    inputBackground: '#FFFFFF',
    inputBorder: '#D1D5DB',

    card: '#FFFFFF',
    cardElevated: '#FFFFFF',
  },

  dark: {
    // Base
    background: '#000000',
    surface: '#171717',
    surfaceElevated: '#212225',

    // Text
    text: '#FFFFFF',
    textSecondary: '#B0B4BA',
    textTertiary: '#7A7F87',

    // Brand
    primary: '#7C7DFF',
    primaryForeground: '#FFFFFF',

    // States
    success: '#4ADE80',
    warning: '#FBBF24',
    error: '#F87171',

    // Borders
    border: '#2E3135',
    borderStrong: '#3F4348',

    // Interactive
    hover: '#2A2D31',
    pressed: '#35383D',
    selected: '#1E3A8A',

    // Assistant UI
    assistantBubble: '#212225',
    assistantBubbleText: '#FFFFFF',

    userBubble: '#7C7DFF',
    userBubbleText: '#FFFFFF',

    inputBackground: '#171717',
    inputBorder: '#2E3135',

    card: '#171717',
    cardElevated: '#212225',
  },
} as const;

export type ThemeColor = keyof typeof Colors.light & keyof typeof Colors.dark;

export const Fonts = Platform.select({
  ios: {
    sans: 'system-ui',
    serif: 'ui-serif',
    rounded: 'ui-rounded',
    mono: 'ui-monospace',
  },
  web: {
    sans: 'var(--font-display)',
    serif: 'var(--font-serif)',
    rounded: 'var(--font-rounded)',
    mono: 'var(--font-mono)',
  },
  default: {
    sans: 'normal',
    serif: 'serif',
    rounded: 'normal',
    mono: 'monospace',
  },
});

export const Radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 9999,
} as const;

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  '2xl': 32,
  '3xl': 48,
  '4xl': 64,
} as const;

export const BottomTabInset =
  Platform.select({
    ios: 50,
    android: 80,
  }) ?? 0;

export const MaxContentWidth = 800;
