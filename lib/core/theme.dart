import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// Core Palette — ported from src/theme/index.ts
// ---------------------------------------------------------------------------

abstract final class KrithaColors {
  // Backgrounds
  static const bgDeepest = Color(0xFF000000);
  static const bgBase = Color(0xFF0B0D10);
  static const bgSurface = Color(0xFF111419);
  static const bgPrimary = Color(0xFF171A1F);
  static const bgSecondary = Color(0xFF1E2228);
  static const bgTertiary = Color(0xFF262B32);
  static const bgQuaternary = Color(0xFF2E343C);
  static const bgCard = Color(0xFF1B1F24);
  static const bgScrim = Color(0x99000000); // rgba(0,0,0,0.60)

  /// Translucent composer surface used with a backdrop blur.
  static const composerGlass = Color(0xD11E2228); // bgSecondary at ~82%

  // Text
  static const textPrimary = Color(0xFFF4F7FA);
  static const textSecondary = Color(0xFFD7DDE5);
  static const textMuted = Color(0xFF9299A3);
  static const textDimmed = Color(0xFF68717D);
  static const textOnAccent = Color(0xFFFFFFFF);

  // Brand / Accent
  static const accentBlue = Color(0xFF2563EB);
  static const accentLightBlue = Color(0xFF60A5FA);
  static const accentSky = Color(0xFF38BDF8);
  static const accentCyan = Color(0xFF22D3EE);
  static const accentCyanDim = Color(0xFF06B6D4);
  static const accentCyanBg = Color(0xFF164E63);

  // Semantic
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  // Border / Divider
  static const borderStrong = Color(0xFF3A414A);
  static const borderSubtle = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const borderFaint = Color(0x0EFFFFFF); // rgba(255,255,255,0.055)
  static const borderAccent = Color(0xFF3B82F6);

  // Context menu (RN ContextMenu.tsx: pressed 0.09 white)
  static const contextMenuPressed = Color(0x17FFFFFF);

  // Message bubbles
  static const userBubble = Color(0xFF21437D);
  static const userBubbleBg = Color(0xFF21437D);
  static const assistantBubbleBg = Color(0x142563EB); // rgba(37,99,235,0.08)
  static const assistantBubbleBorder = Color(
    0x402563EB,
  ); // rgba(37,99,235,0.25)

  // Thinking block
  static const thinkingBorder = Color(0xFF2563EB);
  static const thinkingBg = Color(0x142563EB); // rgba(37,99,235,0.08)

  // Other semantic surfaces
  static const errorBubbleBg = Color(0x26F87171); // rgba(248,113,113,0.15)
  static const ttsActiveBg = Color(0x2660A5FA); // rgba(96,165,250,0.15)

  // Data visualisation
  /// Dictation metering bars: a light grey, not pure white, so they sit calmly
  /// inside the frosted composer and match the reference recording strip.
  static const waveformBar = Color(0xFFC5CBD3);

  // Icons
  static const iconMuted = Color(0xFF9AA3AD);
  static const iconSlate = Color(0xFFC5CBD3);

  // Dracula theme (code blocks)
  static const draculaCurrentLine = Color(0xFF44475A);
  static const draculaLine = draculaCurrentLine;
  static const draculaForeground = Color(0xFFF8F8F2);

  // Syntax highlighting (Dracula palette)
  static const syntaxKeyword = Color(0xFFFF79C6);
  static const syntaxOperator = Color(0xFFFF79C6);
  static const syntaxPunctuation = Color(0xFFF8F8F2);
  static const syntaxString = Color(0xFFF1FA8C);
  static const syntaxNumber = Color(0xFFBD93F9);
  static const syntaxConstant = Color(0xFFBD93F9);
  static const syntaxComment = Color(0xFF6272A4);
  static const syntaxFunction = Color(0xFF50FA7B);
  static const syntaxType = Color(0xFF8BE9FD);
  static const syntaxVariable = Color(0xFFF8F8F2);
  static const syntaxProperty = Color(0xFF50FA7B);
  static const syntaxTag = Color(0xFFFF79C6);
  static const syntaxAttribute = Color(0xFF50FA7B);
  static const syntaxEmbedded = Color(0xFFF8F8F2);
}

// ---------------------------------------------------------------------------
// Border Radii
// ---------------------------------------------------------------------------

abstract final class KrithaRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const base = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xl2 = 28.0; // RADIUS_2XL in RN source
  static const full = 100.0;
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

abstract final class KrithaText {
  // Font sizes. The reference screenshot's body copy is noticeably larger than
  // the RN 15.5 px baseline, so the shared scale is raised once here and every
  // message, menu and sidebar style inherits it.
  static const size2xs = 12.0;
  static const sizeXs = 13.0;
  static const sizeSm = 15.0;
  static const sizeBase = 17.0;
  static const sizeMd = 18.0;
  static const sizeComposer = 17.0;
  static const sizeLg = 20.0;
  static const sizeXl = 22.0;
  static const size2xl = 26.0;
  static const size3xl = 30.0;

  /// Line height used by message text, composer input and Markdown.
  static const lineHeightBase = 26.0;
  static const lineHeightRatio = lineHeightBase / sizeBase;

  // Shared text styles
  static const body = TextStyle(
    fontSize: sizeBase,
    height: 1.55,
    letterSpacing: 0.05,
  );

  static const message = TextStyle(fontSize: sizeBase, height: lineHeightRatio);

  static const composerInput = TextStyle(
    fontSize: sizeComposer,
    height: 24 / sizeComposer,
    color: KrithaColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: sizeXs,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: KrithaColors.textMuted,
  );
}

// ---------------------------------------------------------------------------
// Spacing scale — values taken from the React Native screen styles
// ---------------------------------------------------------------------------

/// The spacing steps used across the React Native source. Components should
/// prefer these over raw numbers so padding stays consistent.
abstract final class KrithaSpacing {
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s18 = 18.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s28 = 28.0;
  static const s30 = 30.0;
  static const s32 = 32.0;

  // Semantic aliases used by more than one surface.
  static const screenPadding = s16;
  static const sidebarPadding = s24;
  static const messageGap = s8;
  static const composerPadding = s12;
}

// ---------------------------------------------------------------------------
// Shared component dimensions
// ---------------------------------------------------------------------------

abstract final class KrithaDimensions {
  static const headerHeight = 60.0;

  /// TextComposer values from the React Native source.
  static const composerLineHeight = 24.0;
  static const composerMaxLines = 8;
  static const composerCompactHeight = 58.0;
  static const composerExpandedMinHeight = 116.0;
  static const composerBottomRowHeight = 44.0;
  static const composerInputHeight = 44.0;
  static const composerMaxHeight =
      composerLineHeight * composerMaxLines + composerBottomRowHeight + 24.0;

  /// Shared context menu geometry from the RN `ContextMenu.tsx`, widened a
  /// little so the larger reference font size still fits long rows such as
  /// “Uploaded files”.
  static const contextMenuWidth = 200.0;
  static const contextMenuItemHeight = 48.0;

  /// Extra top/bottom breathing room owned by the first and last rows. The
  /// full inset stays inside each row's press surface, so there is still no
  /// menu-level gutter.
  static const contextMenuEdgeInset = 8.0;
  static const contextMenuVerticalGap = 8.0;

  /// The header is a 17px line (1.55 line-height, ~26.4px) plus 12/8 padding,
  /// rounded to 47. The 1px border allowance is added separately by the menu
  /// estimator; keeping these in sync prevents IME/safe-area clipping.
  static const contextMenuHeaderHeight = 47.0;
  static const contextMenuScreenMargin = 12.0;
  static const contextMenuSafeTop = 16.0;
  static const contextMenuIconSize = 18.0;
  static const contextMenuIconColumn = 24.0;
  static const contextMenuIconGap = 16.0;

  static const actionButtonSize = 40.0;
  static const sidebarActionRowHeight = 56.0;
  static const sidebarSessionRowHeight = 56.0;
  static const liveTalkCircleSize = 48.0;
  static const liveTalkPillHeight = 50.0;
  static const liveTalkPillMaxWidth = 120.0;

  /// Dictation meter geometry, taken from the RN recording row.
  static const waveformBarWidth = 3.0;
  static const waveformBarGap = 4.0;
  static const waveformBarHeight = 26.0;
  static const waveformMaxBars = 42;

  static const maxContentWidth = 760.0;
  static const sidebarWidth = 300.0;
  static const sidebarDrawerFraction = 0.78;
  static const sidebarDrawerMaxWidth = 340.0;

  static const attachmentPreviewHeight = 72.0;
  static const attachmentImageSize = 64.0;

  /// Composer frost: the floating composer blurs the transcript behind it.
  static const composerBlurSigma = 18.0;
  static const composerBackdropBlurSigma = 14.0;
  static const composerBackdropLift = 28.0;
  static const composerBackdropScrimOpacity = 0.35;

  /// Overlay header fade from the RN `ChatMessages.tsx` top gradient.
  static const headerFadeHeight = 100.0;
  static const headerBackdropBlurSigma = 14.0;
  static const headerContentTopPadding = 80.0;

  /// Scroll-to-bottom affordance from the RN `ChatMessages.tsx`.
  static const scrollDownButtonSize = 45.0;
  static const scrollDownBottomGap = 12.0;
  static const scrollDownButtonLift = 24.0;
  static const scrollDownAutoHide = Duration(milliseconds: 1500);
}

abstract final class KrithaMotion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
  static const composer = Duration(milliseconds: 180);
  static const contextMenu = Duration(milliseconds: 180);
}

// ---------------------------------------------------------------------------
// Icon Sizes
// ---------------------------------------------------------------------------

abstract final class KrithaIcons {
  static const xs = 14.0;
  static const sm = 18.0;
  static const base = 20.0;
  static const md = 22.0;
  static const lg = 24.0;
  static const xl = 28.0;

  /// Hugeicons ships its stroke-rounded set at 1.5 on a 24×24 viewBox, which
  /// reads noticeably lighter than the reference UI. 2.0 matches the medium
  /// weight used by ChatGPT-style navigation and toolbar glyphs.
  static const stroke = 2.0;

  /// Slightly lighter weight for 13–15 px inline glyphs so small counters
  /// (dots, ticks, arrows) stay open at small sizes.
  static const compactStroke = 1.7;
}

/// [HugeIcon] with Kritha's stroke weight applied by default.
///
/// Use this instead of [HugeIcon] everywhere in the app; pass [strokeWidth]
/// only when a specific glyph needs a different weight.
class KrithaIcon extends StatelessWidget {
  const KrithaIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.strokeWidth,
  });

  final List<List<dynamic>> icon;
  final double? size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? KrithaIcons.lg;
    return UnconstrainedBox(
      child: HugeIcon(
        icon: icon,
        size: effectiveSize,
        color: color,
        strokeWidth:
            strokeWidth ??
            (effectiveSize < 16
                ? KrithaIcons.compactStroke
                : KrithaIcons.stroke),
      ),
    );
  }
}

abstract final class KrithaFonts {
  /// Bundled DM Sans (Google Fonts), declared in `pubspec.yaml`.
  static const dmSans = 'DMSans';
}

// ---------------------------------------------------------------------------
// ThemeData builder
// ---------------------------------------------------------------------------

ThemeData buildKrithaTheme() {
  const scheme = ColorScheme.dark(
    primary: KrithaColors.accentBlue,
    onPrimary: Colors.white,
    secondary: KrithaColors.accentSky,
    onSecondary: KrithaColors.bgDeepest,
    surface: KrithaColors.bgSurface,
    onSurface: KrithaColors.textPrimary,
    surfaceContainerHighest: KrithaColors.bgTertiary,
    outline: KrithaColors.borderStrong,
    outlineVariant: KrithaColors.borderSubtle,
    error: KrithaColors.error,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KrithaColors.bgBase,
    fontFamily: KrithaFonts.dmSans,
  );
  // ThemeData owns the family; applying the primary colour here makes it the
  // default for every normal text style. Component styles intentionally carry
  // neither property so they inherit these values.
  final baseTextTheme = base.textTheme.apply(
    bodyColor: KrithaColors.textPrimary,
    displayColor: KrithaColors.textPrimary,
  );

  return base.copyWith(
    canvasColor: KrithaColors.bgBase,
    dividerColor: KrithaColors.borderSubtle,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: KrithaColors.accentLightBlue,
      selectionColor: Color(0x4D2563EB),
      selectionHandleColor: KrithaColors.accentLightBlue,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(3),
      radius: const Radius.circular(KrithaRadius.full),
      thumbColor: WidgetStateProperty.all(KrithaColors.bgQuaternary),
    ),
    textTheme: baseTextTheme.copyWith(
      bodyMedium: baseTextTheme.bodyMedium!.copyWith(
        fontSize: KrithaText.sizeBase,
        height: KrithaText.body.height,
        letterSpacing: KrithaText.body.letterSpacing,
      ),
      bodyLarge: baseTextTheme.bodyLarge!.copyWith(
        fontSize: KrithaText.sizeMd,
        height: KrithaText.body.height,
        letterSpacing: KrithaText.body.letterSpacing,
      ),
      titleMedium: baseTextTheme.titleMedium!.copyWith(
        fontSize: KrithaText.sizeMd,
        fontWeight: FontWeight.w600,
      ),
      // Supporting labels are one of the intentional colour exceptions.
      labelSmall: baseTextTheme.labelSmall!.copyWith(
        fontSize: KrithaText.sizeXs,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: KrithaColors.textMuted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: KrithaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: KrithaColors.bgDeepest,
      scrimColor: KrithaColors.bgScrim,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KrithaColors.bgSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KrithaRadius.xl),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KrithaColors.bgTertiary,
      contentTextStyle: baseTextTheme.bodyMedium!.copyWith(
        fontSize: KrithaText.sizeSm,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KrithaRadius.base),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: KrithaColors.textDimmed),
      isDense: true,
    ),
  );
}
