import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

// Core Palette

abstract final class KrithaColors {
  static bool _lightMode = false;

  static void setLightMode(bool value) => _lightMode = value;

  // Backgrounds
  static const _darkBgDeepest = Color(0xFF000000);
  static Color get bgDeepest => _lightMode ? Color(0xFFF8FAFC) : _darkBgDeepest;
  static const _darkBgBase = Color(0xFF0B0D10);
  static Color get bgBase => _lightMode ? Color(0xFFF8FAFC) : _darkBgBase;
  static const _darkBgSurface = Color(0xFF111419);
  static Color get bgSurface => _lightMode ? Color(0xFFFFFFFF) : _darkBgSurface;
  static const _darkBgPrimary = Color(0xFF171A1F);
  static Color get bgPrimary => _lightMode ? Color(0xFFF1F5F9) : _darkBgPrimary;
  static const _darkBgSecondary = Color(0xFF1E2228);
  static Color get bgSecondary =>
      _lightMode ? Color(0xFFE2E8F0) : _darkBgSecondary;
  static const _darkBgTertiary = Color(0xFF262B32);
  static Color get bgTertiary =>
      _lightMode ? Color(0xFFCBD5E1) : _darkBgTertiary;
  static const _darkBgQuaternary = Color(0xFF2E343C);
  static Color get bgQuaternary =>
      _lightMode ? Color(0xFF94A3B8) : _darkBgQuaternary;
  static const _darkBgCard = Color(0xFF1B1F24);
  static Color get bgCard => _lightMode ? Color(0xFFFFFFFF) : _darkBgCard;
  static const _darkBgScrim = Color(0x99000000);
  static Color get bgScrim =>
      _lightMode ? Color(0x66000000) : _darkBgScrim; // rgba(0,0,0,0.60)

  /// Translucent composer surface used with a backdrop blur.
  static const _darkComposerGlass = Color(0xD11E2228);
  static Color get composerGlass => _lightMode
      ? Color(0xE6FFFFFF)
      : _darkComposerGlass; // bgSecondary at ~82%

  /// Colour the transcript dissolves into behind the floating composer. It has
  /// to match the chat surface, not be a shadow, or light mode gets a grey
  /// smudge and dark mode a lighter band.
  static Color get composerBackdrop => bgDeepest;

  /// Soft elevation around the glass composer. Light mode uses a tinted, wide
  /// shadow instead of a hard black ring.
  static Color get composerShadow =>
      _lightMode ? Color(0x140F172A) : Color(0x66000000);

  /// Semi-transparent puck behind the scroll-to-bottom arrow.
  static Color get scrollDownSurface =>
      _lightMode ? Color(0xCCFFFFFF) : Color(0x99262B32);

  /// Floating menu elevation; light mode needs a tinted shadow, not pure black.
  static Color get menuShadow =>
      _lightMode ? Color(0x1F0F172A) : Color(0x80000000);

  // Text
  static const _darkTextPrimary = Color(0xFFF4F7FA);
  static Color get textPrimary =>
      _lightMode ? Color(0xFF0F172A) : _darkTextPrimary;
  static const _darkTextSecondary = Color(0xFFD7DDE5);
  static Color get textSecondary =>
      _lightMode ? Color(0xFF334155) : _darkTextSecondary;
  static const _darkTextMuted = Color(0xFF9299A3);
  static Color get textMuted => _lightMode ? Color(0xFF64748B) : _darkTextMuted;
  static const _darkTextDimmed = Color(0xFF68717D);
  static Color get textDimmed =>
      _lightMode ? Color(0xFF94A3B8) : _darkTextDimmed;
  static const _darkTextOnAccent = Color(0xFFFFFFFF);
  static Color get textOnAccent =>
      _lightMode ? Color(0xFFFFFFFF) : _darkTextOnAccent;

  // Brand / Accent
  static const _darkAccentBlue = Color(0xFF3566F0);
  static Color get accentBlue =>
      _lightMode ? Color(0xFF3566F0) : _darkAccentBlue;
  static const _darkAccentLightBlue = Color(0xFF60A5FA);
  static Color get accentLightBlue =>
      _lightMode ? Color(0xFF60A5FA) : _darkAccentLightBlue;
  static const _darkAccentSky = Color(0xFF38BDF8);
  static Color get accentSky => _lightMode ? Color(0xFF38BDF8) : _darkAccentSky;
  static const _darkAccentCyan = Color(0xFF22D3EE);
  static Color get accentCyan =>
      _lightMode ? Color(0xFF22D3EE) : _darkAccentCyan;
  static const _darkAccentCyanDim = Color(0xFF06B6D4);
  static Color get accentCyanDim =>
      _lightMode ? Color(0xFF06B6D4) : _darkAccentCyanDim;
  static const _darkAccentCyanBg = Color(0xFF164E63);
  static Color get accentCyanBg =>
      _lightMode ? Color(0xFF164E63) : _darkAccentCyanBg;

  // Semantic
  static const _darkSuccess = Color(0xFF34D399);
  static Color get success => _lightMode ? Color(0xFF34D399) : _darkSuccess;
  static Color get error => _lightMode ? Color(0xFFDC2626) : Color(0xFFFF453A);
  static const _darkWarning = Color(0xFFFBBF24);
  static Color get warning => _lightMode ? Color(0xFFFBBF24) : _darkWarning;

  // Border / Divider
  static const _darkBorderStrong = Color(0xFF3A414A);
  static Color get borderStrong =>
      _lightMode ? Color(0xFF94A3B8) : _darkBorderStrong;
  static const _darkBorderSubtle = Color(0x1AFFFFFF);
  static Color get borderSubtle => _lightMode
      ? Color(0x260F172A)
      : _darkBorderSubtle; // rgba(255,255,255,0.10)
  static const _darkBorderFaint = Color(0x0EFFFFFF);
  static Color get borderFaint => _lightMode
      ? Color(0x140F172A)
      : _darkBorderFaint; // rgba(255,255,255,0.055)
  static const _darkBorderAccent = Color(0xFF3566F0);
  static Color get borderAccent =>
      _lightMode ? Color(0xFF3566F0) : _darkBorderAccent;

  // Context menu pressed overlay
  static const _darkContextMenuPressed = Color(0x17FFFFFF);
  static Color get contextMenuPressed =>
      _lightMode ? Color(0x140F172A) : _darkContextMenuPressed;

  // Message bubbles
  static const _darkUserBubble = Color(0xFF21437D);
  static Color get userBubble =>
      _lightMode ? Color(0xFFDBEAFE) : _darkUserBubble;
  static const _darkUserBubbleBg = Color(0xFF21437D);
  static Color get userBubbleBg =>
      _lightMode ? Color(0xFFDBEAFE) : _darkUserBubbleBg;
  static const _darkAssistantBubbleBg = Color(0x143B82F6);
  static Color get assistantBubbleBg => _lightMode
      ? Color(0x143B82F6)
      : _darkAssistantBubbleBg; // rgba(59,130,246,0.08)
  static const _darkAssistantBubbleBorder = Color(0x403B82F6);
  static Color get assistantBubbleBorder => _lightMode
      ? Color(0x403B82F6)
      : _darkAssistantBubbleBorder; // rgba(59,130,246,0.25)

  // Thinking block
  static const _darkThinkingBorder = Color(0xFF3B82F6);
  static Color get thinkingBorder =>
      _lightMode ? Color(0xFF3B82F6) : _darkThinkingBorder;
  static const _darkThinkingBg = Color(0x143B82F6);
  static Color get thinkingBg =>
      _lightMode ? Color(0x143B82F6) : _darkThinkingBg; // rgba(59,130,246,0.08)

  // Other semantic surfaces
  static const _darkErrorBubbleBg = Color(0x26F87171);
  static Color get errorBubbleBg => _lightMode
      ? Color(0x26DC2626)
      : _darkErrorBubbleBg; // rgba(248,113,113,0.15)
  static const _darkTtsActiveBg = Color(0x2660A5FA);
  static Color get ttsActiveBg => _lightMode
      ? Color(0x263B82F6)
      : _darkTtsActiveBg; // rgba(96,165,250,0.15)

  // Data visualisation
  static const _darkWaveformBar = Color(0xFFC5CBD3);
  static Color get waveformBar =>
      _lightMode ? Color(0xFF64748B) : _darkWaveformBar;

  // Icons
  static const _darkIconMuted = Color(0xFF9AA3AD);
  static Color get iconMuted => _lightMode ? Color(0xFF64748B) : _darkIconMuted;
  static const _darkIconSlate = Color(0xFFC5CBD3);
  static Color get iconSlate => _lightMode ? Color(0xFF475569) : _darkIconSlate;

  // Dracula theme (code blocks)
  static const _darkDraculaCurrentLine = Color(0xFF44475A);
  static Color get draculaCurrentLine =>
      _lightMode ? Color(0xFF44475A) : _darkDraculaCurrentLine;
  static Color get draculaLine => draculaCurrentLine;
  static const _darkDraculaForeground = Color(0xFFF8F8F2);
  static Color get draculaForeground =>
      _lightMode ? Color(0xFFF8F8F2) : _darkDraculaForeground;

  // Syntax highlighting (Dracula palette)
  static const _darkSyntaxKeyword = Color(0xFFFF79C6);
  static Color get syntaxKeyword =>
      _lightMode ? Color(0xFFFF79C6) : _darkSyntaxKeyword;
  static const _darkSyntaxOperator = Color(0xFFFF79C6);
  static Color get syntaxOperator =>
      _lightMode ? Color(0xFFFF79C6) : _darkSyntaxOperator;
  static const _darkSyntaxPunctuation = Color(0xFFF8F8F2);
  static Color get syntaxPunctuation =>
      _lightMode ? Color(0xFFF8F8F2) : _darkSyntaxPunctuation;
  static const _darkSyntaxString = Color(0xFFF1FA8C);
  static Color get syntaxString =>
      _lightMode ? Color(0xFFF1FA8C) : _darkSyntaxString;
  static const _darkSyntaxNumber = Color(0xFFBD93F9);
  static Color get syntaxNumber =>
      _lightMode ? Color(0xFFBD93F9) : _darkSyntaxNumber;
  static const _darkSyntaxConstant = Color(0xFFBD93F9);
  static Color get syntaxConstant =>
      _lightMode ? Color(0xFFBD93F9) : _darkSyntaxConstant;
  static const _darkSyntaxComment = Color(0xFF6272A4);
  static Color get syntaxComment =>
      _lightMode ? Color(0xFF6272A4) : _darkSyntaxComment;
  static const _darkSyntaxFunction = Color(0xFF50FA7B);
  static Color get syntaxFunction =>
      _lightMode ? Color(0xFF50FA7B) : _darkSyntaxFunction;
  static const _darkSyntaxType = Color(0xFF8BE9FD);
  static Color get syntaxType =>
      _lightMode ? Color(0xFF8BE9FD) : _darkSyntaxType;
  static const _darkSyntaxVariable = Color(0xFFF8F8F2);
  static Color get syntaxVariable =>
      _lightMode ? Color(0xFFF8F8F2) : _darkSyntaxVariable;
  static const _darkSyntaxProperty = Color(0xFF50FA7B);
  static Color get syntaxProperty =>
      _lightMode ? Color(0xFF50FA7B) : _darkSyntaxProperty;
  static const _darkSyntaxTag = Color(0xFFFF79C6);
  static Color get syntaxTag => _lightMode ? Color(0xFFFF79C6) : _darkSyntaxTag;
  static const _darkSyntaxAttribute = Color(0xFF50FA7B);
  static Color get syntaxAttribute =>
      _lightMode ? Color(0xFF50FA7B) : _darkSyntaxAttribute;
  static const _darkSyntaxEmbedded = Color(0xFFF8F8F2);
  static Color get syntaxEmbedded =>
      _lightMode ? Color(0xFFF8F8F2) : _darkSyntaxEmbedded;
}

// Border Radii

abstract final class KrithaRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const base = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xl2 = 28.0;
  static const full = 100.0;
}

// Typography

abstract final class KrithaText {
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

  static TextStyle get composerInput => TextStyle(
    fontSize: sizeComposer,
    height: 24 / sizeComposer,
    color: KrithaColors.textSecondary,
  );

  static TextStyle get label => TextStyle(
    fontSize: sizeXs,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: KrithaColors.textMuted,
  );
}

// Spacing scale

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

// Shared component dimensions

abstract final class KrithaDimensions {
  static const headerHeight = 60.0;

  static const composerLineHeight = 24.0;
  static const composerMaxLines = 8;
  static const composerCompactHeight = 58.0;
  static const composerExpandedMinHeight = 116.0;
  static const composerBottomRowHeight = 44.0;
  static const composerInputHeight = 44.0;
  static const composerMaxHeight =
      composerLineHeight * composerMaxLines + composerBottomRowHeight + 24.0;

  static const contextMenuWidth = 200.0;
  static const contextMenuItemHeight = 48.0;
  static const contextMenuEdgeInset = 8.0;
  static const contextMenuVerticalGap = 8.0;
  static const contextMenuHeaderHeight = 55.0;
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

  static const composerBlurSigma = 18.0;
  static const composerBackdropBlurSigma = 20.0;
  static const composerBackdropLift = 28.0;
  static const composerBackdropScrimOpacity = 0.55;

  static const headerFadeHeight = 100.0;
  static const headerBackdropBlurSigma = 14.0;
  static const headerContentTopPadding = 80.0;

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

// Icon Sizes

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
  static const dmSans = 'DMSans';
}

/// Keeps [KrithaColors] in sync with the active [Theme] and makes the caller
/// depend on it. The palette is static, so without an explicit [Theme]
/// dependency most subtrees keep their previously-built colours after a theme
/// switch. Screens call this once at the top of their build.
void watchKrithaPalette(BuildContext context) {
  KrithaColors.setLightMode(Theme.of(context).brightness == Brightness.light);
}

// ThemeData builder

ThemeData buildKrithaTheme() {
  final scheme = ColorScheme(
    brightness: KrithaColors._lightMode ? Brightness.light : Brightness.dark,
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
    onError: KrithaColors.textOnAccent,
    surfaceTint: KrithaColors.accentBlue,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: KrithaColors.bgBase,
    fontFamily: KrithaFonts.dmSans,
  );

  final baseTextTheme = base.textTheme.apply(
    bodyColor: KrithaColors.textPrimary,
    displayColor: KrithaColors.textPrimary,
  );

  return base.copyWith(
    canvasColor: KrithaColors.bgBase,
    dividerColor: KrithaColors.borderSubtle,
    splashFactory: InkSparkle.splashFactory,
    hoverColor: KrithaColors.contextMenuPressed,
    focusColor: KrithaColors.contextMenuPressed,
    highlightColor: KrithaColors.contextMenuPressed,
    splashColor: KrithaColors.contextMenuPressed,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: KrithaColors.accentLightBlue,
      selectionColor: KrithaColors.accentBlue.withValues(alpha: 0.30),
      selectionHandleColor: KrithaColors.accentLightBlue,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(3),
      radius: Radius.circular(KrithaRadius.full),
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: KrithaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: KrithaColors.bgDeepest,
      scrimColor: KrithaColors.bgScrim,
    ),
    bottomSheetTheme: BottomSheetThemeData(
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
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: KrithaColors.textDimmed),
      isDense: true,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: KrithaColors.bgTertiary,
        borderRadius: BorderRadius.circular(KrithaRadius.sm),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      textStyle: TextStyle(
        color: KrithaColors.textPrimary,
        fontFamily: KrithaFonts.dmSans,
        fontSize: KrithaText.sizeXs,
      ),
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}
