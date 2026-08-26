/**
 * Kritha Design System — Theme Constants
 *
 * Single source of truth for all colors used across the app.
 * Import from '@/theme' in any component instead of hard-coding hex values.
*/

/* Core Palette */

// Deepest background — used for shell, app frame, status bar bg
export const BG_DEEPEST = '#0f0f10ff';

// Primary surface — chat panel, sidebar
export const BG_SURFACE = '#141518';

// Slightly lighter surface — used for inline cards, banners
export const BG_ELEVATED = '#17181b';

// Input / search box backgrounds
export const BG_INPUT = '#1c1e21';

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

// Primary brand blue (alias for clarity)
export const ACCENT_PRIMARY = ACCENT_BLUE;

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

/* Transparent Helpers */

// User message bubble background
export const USER_BUBBLE_BG = ACCENT_BLUE;

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

const Colors = {
  // Backgrounds
  bgDeepest: BG_DEEPEST,
  bgSurface: BG_SURFACE,
  bgElevated: BG_ELEVATED,
  bgInput: BG_INPUT,
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
  accentPrimary: ACCENT_PRIMARY,
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

export default Colors;
