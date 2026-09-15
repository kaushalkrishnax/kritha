/* Core Palette */
export const BG_DEEPEST = '#000000';
export const BG_BASE = '#0B0D10';
export const BG_SURFACE = '#111419';
export const BG_PRIMARY = '#171A1F';
export const BG_SECONDARY = '#1E2228';
export const BG_TERTIARY = '#262B32';
export const BG_QUATERNARY = '#2E343C';
export const BG_CARD = '#1B1F24';
export const BG_SCRIM = 'rgba(0, 0, 0, 0.60)';

/* Text */
export const TEXT_PRIMARY = '#F4F7FA';
export const TEXT_SECONDARY = '#D7DDE5';
export const TEXT_MUTED = '#9299A3';
export const TEXT_DIMMED = '#68717D';
export const TEXT_ON_ACCENT = '#FFFFFF';

/* Brand / Accent */
export const ACCENT_BLUE = '#2563EB';
export const ACCENT_LIGHT_BLUE = '#60A5FA';
export const ACCENT_SKY = '#38BDF8';
export const ACCENT_CYAN = '#22D3EE';
export const ACCENT_CYAN_DIM = '#06B6D4';
export const ACCENT_CYAN_BG = '#164E63';

/* Semantic */
export const SUCCESS = '#34D399';
export const ERROR = '#F87171';
export const WARNING = '#FBBF24';

/* Border / Divider */
export const BORDER_STRONG = '#3A414A';
export const BORDER_SUBTLE = 'rgba(255, 255, 255, 0.10)';
export const BORDER_FAINT = 'rgba(255, 255, 255, 0.055)';
export const BORDER_ACCENT = '#3B82F6';

export const USER_BUBBLE_BG = '#21437D';
export const ASSISTANT_BUBBLE_BG = 'rgba(37, 99, 235, 0.08)';
export const ASSISTANT_BUBBLE_BORDER = 'rgba(37, 99, 235, 0.25)';

export const THINKING_BORDER = '#2563EB';
export const THINKING_BG = 'rgba(37, 99, 235, 0.08)';

export const ERROR_BUBBLE_BG = 'rgba(248, 113, 113, 0.15)';
export const TTS_ACTIVE_BG = 'rgba(96, 165, 250, 0.15)';

export const ICON_MUTED = '#9AA3AD';
export const ICON_SLATE = '#C5CBD3';

/* Dracula Theme */
export const DRACULA_CURRENT_LINE = '#44475A';
export const DRACULA_FOREGROUND = '#F8F8F2';

/* Syntax */
export const SYNTAX_KEYWORD = '#FF79C6';
export const SYNTAX_OPERATOR = '#FF79C6';
export const SYNTAX_PUNCTUATION = '#F8F8F2';
export const SYNTAX_STRING = '#F1FA8C';
export const SYNTAX_NUMBER = '#BD93F9';
export const SYNTAX_CONSTANT = '#BD93F9';
export const SYNTAX_COMMENT = '#6272A4';
export const SYNTAX_FUNCTION = '#50FA7B';
export const SYNTAX_TYPE = '#8BE9FD';
export const SYNTAX_VARIABLE = '#F8F8F2';
export const SYNTAX_PROPERTY = '#50FA7B';
export const SYNTAX_TAG = '#FF79C6';
export const SYNTAX_ATTRIBUTE = '#50FA7B';
export const SYNTAX_EMBEDDED = '#F8F8F2';

const SyntaxColors = {
  keyword: SYNTAX_KEYWORD,
  operator: SYNTAX_OPERATOR,
  punctuation: SYNTAX_PUNCTUATION,
  string: SYNTAX_STRING,
  number: SYNTAX_NUMBER,
  constant: SYNTAX_CONSTANT,
  comment: SYNTAX_COMMENT,
  function: SYNTAX_FUNCTION,
  type: SYNTAX_TYPE,
  variable: SYNTAX_VARIABLE,
  property: SYNTAX_PROPERTY,
  tag: SYNTAX_TAG,
  attribute: SYNTAX_ATTRIBUTE,
  embedded: SYNTAX_EMBEDDED,
} as const;

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
  bgDeepest: BG_DEEPEST,
  bgBase: BG_BASE,
  bgSurface: BG_SURFACE,
  bgPrimary: BG_PRIMARY,
  bgSecondary: BG_SECONDARY,
  bgTertiary: BG_TERTIARY,
  bgQuaternary: BG_QUATERNARY,
  bgCard: BG_CARD,
  bgScrim: BG_SCRIM,

  textPrimary: TEXT_PRIMARY,
  textSecondary: TEXT_SECONDARY,
  textMuted: TEXT_MUTED,
  textDimmed: TEXT_DIMMED,
  textOnAccent: TEXT_ON_ACCENT,

  accentBlue: ACCENT_BLUE,
  accentLightBlue: ACCENT_LIGHT_BLUE,
  accentSky: ACCENT_SKY,
  accentCyan: ACCENT_CYAN,
  accentCyanDim: ACCENT_CYAN_DIM,
  accentCyanBg: ACCENT_CYAN_BG,

  success: SUCCESS,
  error: ERROR,
  warning: WARNING,

  borderStrong: BORDER_STRONG,
  borderSubtle: BORDER_SUBTLE,
  borderFaint: BORDER_FAINT,
  borderAccent: BORDER_ACCENT,

  userBubbleBg: USER_BUBBLE_BG,
  assistantBubbleBg: ASSISTANT_BUBBLE_BG,
  assistantBubbleBorder: ASSISTANT_BUBBLE_BORDER,

  thinkingBorder: THINKING_BORDER,
  thinkingBg: THINKING_BG,

  errorBubbleBg: ERROR_BUBBLE_BG,
  ttsActiveBg: TTS_ACTIVE_BG,

  iconMuted: ICON_MUTED,
  iconSlate: ICON_SLATE,

  draculaCurrentLine: DRACULA_CURRENT_LINE,
  draculaForeground: DRACULA_FOREGROUND,

  syntaxColors: SyntaxColors,
} as const;

export const Theme = {
  colors: Colors,
  typography: Typography,
  iconSizes: IconSizes,
  radius: Radius
} as const;