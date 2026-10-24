import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme.dart';

/// Kritha-tuned Markdown: the package handles parsing, code highlighting and
/// LaTeX; this widget only maps the package's style surface onto the app's
/// palette and type scale.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data});

  final String data;

  /// Rebuilt per frame: the palette flips with the active theme, so caching the
  /// sheet would pin the first theme's colours for the rest of the session.
  GptMarkdownStyleSheet get _styleSheet => GptMarkdownStyleSheet(
    heading: HeadingStyle(
      showDivider: false,
      dividerColor: KrithaColors.borderSubtle,
      padding: EdgeInsets.only(top: 10, bottom: 4),
    ),
    link: LinkStyle(
      color: KrithaColors.accentSky,
      decoration: TextDecoration.underline,
    ),
    inlineCode: InlineCodeStyle(
      color: KrithaColors.accentSky,
      backgroundColor: KrithaColors.bgTertiary,
      borderColor: KrithaColors.borderSubtle,
      borderRadius: Radius.circular(KrithaRadius.xs),
    ),
    codeBlock: CodeBlockStyle(
      backgroundColor: KrithaColors.bgDeepest,
      borderColor: KrithaColors.draculaLine,
      borderWidth: 1,
      borderRadius: Radius.circular(KrithaRadius.base),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
      headerPadding: EdgeInsets.fromLTRB(10, 6, 6, 0),
      fontSize: 13,
      textColor: Color(0xFFF8F8F2),
      showCopyButton: true,
    ),
    blockQuote: BlockQuoteStyle(
      barColor: KrithaColors.accentBlue,
      barWidth: 3,
      backgroundColor: KrithaColors.bgSurface,
      padding: EdgeInsets.fromLTRB(14, 10, 12, 10),
      margin: EdgeInsets.symmetric(vertical: 6),
      textStyle: TextStyle(color: KrithaColors.textSecondary),
    ),
    list: ListStyle(
      bulletColor: KrithaColors.accentLightBlue,
      markerTextStyle: TextStyle(
        color: KrithaColors.accentLightBlue,
        fontWeight: FontWeight.w600,
      ),
    ),
    table: TableStyle(
      borderColor: KrithaColors.borderSubtle,
      borderRadius: Radius.circular(KrithaRadius.sm),
      headerBackground: KrithaColors.bgTertiary,
      headerTextStyle: TextStyle(fontWeight: FontWeight.w600),
      cellPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      rowStripeColor: KrithaColors.bgSurface,
      overflow: TableOverflow.scroll,
    ),
    latex: LatexStyle(
      backgroundColor: KrithaColors.bgSurface,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: Radius.circular(KrithaRadius.base),
      scrollBlockHorizontally: true,
    ),
    hr: HrStyle(
      color: KrithaColors.borderSubtle,
      thickness: 1,
      padding: EdgeInsets.symmetric(vertical: 12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      data,
      style: KrithaText.body,
      styleSheet: _styleSheet,
      useDollarSignsForLatex: true,
      isStreaming: false,
      onLinkTap: (url, title) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Links are disabled in this size demo: $url')),
        );
      },
    );
  }
}
