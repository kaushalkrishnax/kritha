/**
 * Kritha Design System — Theme Constants
 *
 * Single source of truth for all colors used across the app.
 * Import from '@/theme' in any component instead of hard-coding hex values.
 */

/* Core Palette */

// Deepest background — shell, app frame, status bar
export const BG_DEEPEST = '#000000';

// Base background — primary app background
export const BG_BASE = '#0B0C0E';

// Primary surface — chat panel, sidebar
export const BG_SURFACE = '#121316';

// Slightly lighter surface — inline cards, banners
export const BG_PRIMARY = '#17181B';

// More elevated surface — modals, popovers, dropdowns
export const BG_SECONDARY = '#1a1b1e';

// Elevated interactive surface — active buttons, selected items
export const BG_TERTIARY = '#26282c';

// Highest surface — hover, pressed, active states
export const BG_QUATERNARY = '#2c2f34';

// Card / message bubble background (Google Material dark)
export const BG_CARD = '#1c1d1f';

// Overlay / modal scrim
export const BG_SCRIM = 'rgba(0,0,0,0.55)';

/* Text */

// Primary text
export const TEXT_PRIMARY = '#F1F5F9';

// Secondary / body text
export const TEXT_SECONDARY = '#E2E8F0';

// Muted / placeholder text
export const TEXT_MUTED = '#8f959d';

// Dimmed text
export const TEXT_DIMMED = '#79828f';

// White — used on colored buttons
export const TEXT_ON_ACCENT = '#FFFFFF';

/* Brand / Accent */

// Primary brand blue
export const ACCENT_BLUE = '#1A5FE8';

// Google blue — used for links, thinking headers
export const ACCENT_LIGHT_BLUE = '#60A5FA';

// Sky blue — TTS active, like button
export const ACCENT_SKY = '#38BDF8';

// Cyan — live-talk / recording glow
export const ACCENT_CYAN = '#00E5FF';

// Cyan dim — recording active bg
export const ACCENT_CYAN_DIM = '#00B8FF';

// Deeper cyan bg for recording state
export const ACCENT_CYAN_BG = '#005D82';

/* Semantic Colors */

// Success / online indicator
export const SUCCESS = '#10B981';

// Error / stop
export const ERROR = '#F87171';

// Warning / destructive
export const WARNING = '#EF4444';

/* Border / Divider */

// Strong border
export const BORDER_STRONG = '#44494fff';

// Subtle border
export const BORDER_SUBTLE = 'rgba(255,255,255,0.12)';

// Very faint separator
export const BORDER_FAINT = 'rgba(255,255,255,0.06)';

// Accent border (blue tinted)
export const BORDER_ACCENT = '#3B82F6';

// User message bubble background (ChatGPT-style refined dark blue)
export const USER_BUBBLE_BG = '#21437D';

// Assistant message bubble background
export const ASSISTANT_BUBBLE_BG = `rgba(26,115,232,0.08)`;
export const ASSISTANT_BUBBLE_BORDER = `rgba(26,115,232,0.25)`;

// Thinking block accent
export const THINKING_BORDER = '#1A73E8';
export const THINKING_BG = `rgba(26,115,232,0.08)`;

// Error bubble
export const ERROR_BUBBLE_BG = 'rgba(239,68,68,0.15)';

// TTS active bubble
export const TTS_ACTIVE_BG = 'rgba(138,180,248,0.15)';

// Icon muted (Google Material)
export const ICON_MUTED = '#9AA0A6';

// Icon muted (Slate)
export const ICON_SLATE = '#C4C7C5';

/* Typography */
export const FONT_SIZE_2XS = 11;
export const FONT_SIZE_XS = 12;
export const FONT_SIZE_SM = 14;
export const FONT_SIZE_BASE = 15.5;
export const FONT_SIZE_MD = 16.5;
export const FONT_SIZE_LG = 18;
export const FONT_SIZE_XL = 20;
export const FONT_SIZE_2XL = 24;
export const FONT_SIZE_3XL = 28;

export const Typography = {
  size2xs: FONT_SIZE_2XS,
  sizeXs: FONT_SIZE_XS,
  sizeSm: FONT_SIZE_SM,
  sizeBase: FONT_SIZE_BASE,
  sizeMd: FONT_SIZE_MD,
  sizeLg: FONT_SIZE_LG,
  sizeXl: FONT_SIZE_XL,
  size2xl: FONT_SIZE_2XL,
  size3xl: FONT_SIZE_3XL,
} as const;

/* Icon Sizes */
export const ICON_SIZE_XS = 14;
export const ICON_SIZE_SM = 18;
export const ICON_SIZE_BASE = 20;
export const ICON_SIZE_MD = 22;
export const ICON_SIZE_LG = 24;
export const ICON_SIZE_XL = 28;

export const IconSizes = {
  xs: ICON_SIZE_XS,
  sm: ICON_SIZE_SM,
  base: ICON_SIZE_BASE,
  md: ICON_SIZE_MD,
  lg: ICON_SIZE_LG,
  xl: ICON_SIZE_XL,
} as const;

/* Border Radii */
export const RADIUS_XS = 4;
export const RADIUS_SM = 8;
export const RADIUS_BASE = 12;
export const RADIUS_MD = 16;
export const RADIUS_LG = 20;
export const RADIUS_XL = 24;
export const RADIUS_2XL = 28;
export const RADIUS_FULL = 100;

export const Radius = {
  xs: RADIUS_XS,
  sm: RADIUS_SM,
  base: RADIUS_BASE,
  md: RADIUS_MD,
  lg: RADIUS_LG,
  xl: RADIUS_XL,
  '2xl': RADIUS_2XL,
  full: RADIUS_FULL,
} as const;

export const Colors = {
  // Backgrounds
  bgDeepest: BG_DEEPEST,
  bgBase: BG_BASE,
  bgSurface: BG_SURFACE,
  bgPrimary: BG_PRIMARY,
  bgSecondary: BG_SECONDARY,
  bgTertiary: BG_TERTIARY,
  bgQuaternary: BG_QUATERNARY,
  bgCard: BG_CARD,
  bgScrim: BG_SCRIM,

  // Text
  textPrimary: TEXT_PRIMARY,
  textSecondary: TEXT_SECONDARY,
  textMuted: TEXT_MUTED,
  textDimmed: TEXT_DIMMED,
  textOnAccent: TEXT_ON_ACCENT,

  // Accent
  accentBlue: ACCENT_BLUE,
  accentLightBlue: ACCENT_LIGHT_BLUE,
  accentSky: ACCENT_SKY,
  accentCyan: ACCENT_CYAN,
  accentCyanDim: ACCENT_CYAN_DIM,
  accentCyanBg: ACCENT_CYAN_BG,

  // Semantic
  success: SUCCESS,
  error: ERROR,
  warning: WARNING,

  // Borders
  borderStrong: BORDER_STRONG,
  borderSubtle: BORDER_SUBTLE,
  borderFaint: BORDER_FAINT,
  borderAccent: BORDER_ACCENT,

  // Message bubbles
  userBubbleBg: USER_BUBBLE_BG,
  assistantBubbleBg: ASSISTANT_BUBBLE_BG,
  assistantBubbleBorder: ASSISTANT_BUBBLE_BORDER,
  thinkingBorder: THINKING_BORDER,
  thinkingBg: THINKING_BG,
  errorBubbleBg: ERROR_BUBBLE_BG,
  ttsActiveBg: TTS_ACTIVE_BG,

  // Icons
  iconMuted: ICON_MUTED,
  iconSlate: ICON_SLATE,
} as const;

export const Theme = {
  colors: Colors,
  typography: Typography,
  iconSizes: IconSizes,
  radius: Radius,
} as const;
