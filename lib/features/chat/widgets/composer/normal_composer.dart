import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/responsive.dart';
import '../../../../core/theme.dart';
import '../../../../widgets/glass_surface.dart';
import '../../chat_controller.dart';
import '../../dictation_controller.dart';
import '../attachment_view.dart';
import 'composer_controller.dart';
import 'composer_controls.dart';

/// The normal text composer. One TextField is kept across the compact and
/// expanded layouts, so focus and selection survive expansion.
class NormalComposer extends ConsumerStatefulWidget {
  const NormalComposer({super.key, required this.viewport});

  final KrithaViewport viewport;

  @override
  ConsumerState<NormalComposer> createState() => _NormalComposerState();
}

class _NormalComposerState extends ConsumerState<NormalComposer> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode(debugLabel: 'composer-input');

  double? _pendingWidth;
  int? _pendingLines;
  bool? _pendingExpanded;

  @override
  void initState() {
    super.initState();
    // The draft lives in the provider so it survives a trip through Live Talk.
    _textController = TextEditingController(
      text: ref.read(composerProvider).draftText,
    )..addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref.read(composerProvider.notifier).setDraftText(_textController.text);
  }

  Future<void> _send() async {
    final state = ref.read(composerProvider);
    final chat = ref.read(chatControllerProvider).value;
    if (chat?.sending ?? false) return;
    if (!state.hasContent) return;

    final text = _textController.text;
    final attachments = state.attachments;
    final editingMessageId = state.editingMessageId;
    _textController.clear();
    ref.read(composerProvider.notifier).clearDraft();
    await ref
        .read(chatControllerProvider.notifier)
        .send(
          text,
          attachments: attachments,
          editingMessageId: editingMessageId,
        );
  }

  Future<void> _startDictation() async {
    try {
      await ref.read(dictationProvider.notifier).start();
    } on DictationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _handleAction(bool isBusy, bool hasContent) {
    if (isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The current reply is still in flight.')),
      );
      return;
    }
    if (hasContent) {
      _send();
      return;
    }
    ref.read(composerProvider.notifier).setLiveTalkActive(true);
  }

  /// Counts wrapped lines for the exact width the field receives and updates
  /// the latched expansion state.
  ///
  /// Expansion is always decided from the *compact* width. If it were decided
  /// from the current width, expanding would widen the field, shorten the text
  /// back to one line, collapse it and repeat — the flicker users saw. The
  /// latched state makes both directions stable.
  void _scheduleMeasurement({
    required String text,
    required double compactWidth,
    required double expandedWidth,
    required bool effectiveExpanded,
  }) {
    final compactLines = _countLines(text, compactWidth);
    final wantsExpanded = compactLines > 1;
    final lines = effectiveExpanded
        ? _countLines(text, expandedWidth)
        : compactLines;

    final current = ref.read(composerProvider);
    if (current.isExpanded == wantsExpanded && current.measuredLines == lines) {
      return;
    }
    if (_pendingLines == lines &&
        _pendingExpanded == wantsExpanded &&
        _pendingWidth == expandedWidth) {
      return;
    }

    _pendingLines = lines;
    _pendingExpanded = wantsExpanded;
    _pendingWidth = expandedWidth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingLines = null;
      _pendingExpanded = null;
      _pendingWidth = null;
      ref
          .read(composerProvider.notifier)
          .setMeasurement(lines: lines, expanded: wantsExpanded);
    });
  }

  static int _countLines(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: KrithaText.composerInput),
      textDirection: TextDirection.ltr,
      maxLines: KrithaDimensions.composerMaxLines + 1,
    )..layout(maxWidth: math.max(40, maxWidth));
    final wrapped = painter.computeLineMetrics().length;
    // A trailing newline still occupies (and must grow) a line even when the
    // painter reports no glyphs for it.
    final explicit = '\n'.allMatches(text).length + 1;
    return math
        .max(wrapped, explicit)
        .clamp(1, KrithaDimensions.composerMaxLines + 1);
  }

  @override
  Widget build(BuildContext context) {
    // The draft can also change from outside the field (for example "Edit
    // message" in the message context menu). Mirror it once, then focus.
    ref.listen(composerProvider.select((state) => state.draftText), (
      previous,
      next,
    ) {
      if (next == _textController.text) return;
      _textController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _focusNode.requestFocus();
    });

    final state = ref.watch(composerProvider);
    final chat = ref.watch(chatControllerProvider).value;
    final isBusy = chat?.sending ?? false;
    final hasContent = state.hasContent;
    final hasAttachments = state.hasAttachments;
    final isExpanded = widget.viewport.isWide || state.expandsFromContent;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s12,
        KrithaSpacing.s6,
        KrithaSpacing.s12,
        KrithaSpacing.s12 + bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Compact: 8px padding each side, plus button, mic and action.
          // Expanded: 10px padding each side and 6px input padding each side.
          // Expansion is always judged at the compact width to avoid the
          // widen/collapse feedback loop (see _scheduleMeasurement).
          final compactTextWidth = width - 140;
          final expandedTextWidth = width - 32;
          _scheduleMeasurement(
            text: state.draftText,
            compactWidth: compactTextWidth,
            expandedWidth: expandedTextWidth,
            effectiveExpanded: isExpanded,
          );

          final attachmentHeight = hasAttachments
              ? KrithaDimensions.attachmentPreviewHeight + KrithaSpacing.s8
              : 0.0;
          final availableHeight = MediaQuery.sizeOf(context).height;
          final maxInputHeight = math.min(
            24.0 * KrithaDimensions.composerMaxLines,
            math.max(48.0, availableHeight * 0.55 - 68 - attachmentHeight),
          );
          final inputAreaHeight = isExpanded
              ? (state.measuredLines * KrithaDimensions.composerLineHeight)
                    .clamp(KrithaDimensions.composerLineHeight, maxInputHeight)
              : 46.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.isEditing) ...[
                _EditingWarning(
                  onClose: () =>
                      ref.read(composerProvider.notifier).clearDraft(),
                ),
                SizedBox(height: KrithaSpacing.s12),
              ],
              KrithaGlassSurface(
                borderRadius: isExpanded ? KrithaRadius.xl : KrithaRadius.xl2,
                padding: isExpanded
                    ? EdgeInsets.fromLTRB(
                        KrithaSpacing.s10,
                        KrithaSpacing.s12,
                        KrithaSpacing.s10,
                        KrithaSpacing.s8,
                      )
                    : EdgeInsets.symmetric(
                        horizontal: KrithaSpacing.s8,
                        vertical: KrithaSpacing.s6,
                      ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasAttachments) ...[
                      ComposerAttachmentStrip(
                        attachments: state.attachments,
                        onRemove: (attachment) => ref
                            .read(composerProvider.notifier)
                            .removeAttachment(attachment.id),
                      ),
                      SizedBox(height: KrithaSpacing.s8),
                    ],
                    SizedBox(
                      height: inputAreaHeight,
                      child: Row(
                        crossAxisAlignment: isExpanded
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          if (!isExpanded)
                            KeyedSubtree(
                              key: ValueKey('composer-plus'),
                              child: Builder(
                                builder: (buttonContext) => PlusButton(
                                  onTap: () =>
                                      showAttachmentMenu(buttonContext, ref),
                                ),
                              ),
                            ),
                          Expanded(
                            key: ValueKey('composer-input'),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isExpanded ? KrithaSpacing.s6 : 0,
                              ),
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                // Always multiline so Enter inserts a newline and
                                // pasted line breaks are preserved. The parent
                                // SizedBox controls the visible height and the
                                // field scrolls internally at the maximum.
                                minLines: 1,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textAlignVertical: isExpanded
                                    ? TextAlignVertical.top
                                    : TextAlignVertical.center,
                                style: KrithaText.composerInput,
                                cursorColor: KrithaColors.accentLightBlue,
                                decoration: InputDecoration(
                                  hintText: 'Ask Kritha...',
                                  hintStyle: TextStyle(
                                    color: KrithaColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          if (!isExpanded) ...[
                            VoiceModeButton(onTap: _startDictation),
                            SizedBox(width: KrithaSpacing.s8),
                            ComposerActionButton(
                              isBusy: isBusy,
                              hasContent: hasContent,
                              compact: true,
                              onTap: () => _handleAction(isBusy, hasContent),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isExpanded) ...[
                      SizedBox(height: KrithaSpacing.s4),
                      SizedBox(
                        key: ValueKey('composer-bottom-row'),
                        height: KrithaDimensions.composerBottomRowHeight,
                        child: Row(
                          children: [
                            Builder(
                              builder: (buttonContext) => PlusButton(
                                onTap: () =>
                                    showAttachmentMenu(buttonContext, ref),
                              ),
                            ),
                            Spacer(),
                            VoiceModeButton(onTap: _startDictation),
                            SizedBox(width: KrithaSpacing.s8),
                            ComposerActionButton(
                              isBusy: isBusy,
                              hasContent: hasContent,
                              compact: false,
                              onTap: () => _handleAction(isBusy, hasContent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditingWarning extends StatelessWidget {
  const _EditingWarning({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('editing-warning'),
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s16,
        vertical: KrithaSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgSecondary,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: KrithaColors.composerShadow,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedInfo,
            size: KrithaIcons.sm,
            color: KrithaColors.textPrimary,
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: Text(
              'Editing this message will restart the conversation from here.',
              style: TextStyle(
                fontSize: KrithaText.sizeSm,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          Tooltip(
            message: 'Cancel editing',
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(KrithaRadius.full),
              child: Padding(
                padding: EdgeInsets.all(KrithaSpacing.s4),
                child: KrithaIcon(
                  icon: HugeIcons.strokeRoundedX,
                  size: KrithaIcons.sm,
                  color: KrithaColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
