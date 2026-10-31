import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';

Future<T?> createPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool mobileFullScreen = false,
  bool barrierDismissible = true,
  double maxWidth = 560,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss popup',
    barrierColor: KrithaColors.bgBase.withValues(alpha: 0.72),
    transitionDuration: KrithaMotion.contextMenu,
    pageBuilder: (context, animation, secondaryAnimation) {
      final fullScreen =
          mobileFullScreen &&
          MediaQuery.sizeOf(context).width < KrithaBreakpoints.compact;
      return SafeArea(
        minimum: fullScreen ? EdgeInsets.zero : const EdgeInsets.all(20),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: fullScreen ? double.infinity : maxWidth,
                  maxHeight: fullScreen
                      ? double.infinity
                      : MediaQuery.sizeOf(context).height * 0.86,
                ),
                child: Material(
                  color: KrithaColors.bgSurface,
                  elevation: fullScreen ? 0 : 16,
                  shadowColor: Colors.black.withValues(alpha: 0.28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      fullScreen ? 0 : KrithaRadius.lg,
                    ),
                    side: fullScreen
                        ? BorderSide.none
                        : BorderSide(color: KrithaColors.borderSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: builder(context),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class CreatePopup extends StatelessWidget {
  const CreatePopup({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  /// Replaces [actions] with a full-width footer, so callers can balance
  /// leading and trailing action groups.
  final Widget? footer;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.s20,
            KrithaSpacing.s18,
            KrithaSpacing.s20,
            KrithaSpacing.s14,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: KrithaSpacing.s10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: KrithaText.sizeLg,
                        fontWeight: FontWeight.w700,
                        color: KrithaColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: KrithaSpacing.s4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: KrithaText.sizeXs,
                          color: KrithaColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(child: child),
        if (footer != null) ...[
          Padding(padding: EdgeInsets.all(KrithaSpacing.s16), child: footer!),
        ] else if (actions.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.all(KrithaSpacing.s16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: KrithaSpacing.s8,
              runSpacing: KrithaSpacing.s8,
              children: actions,
            ),
          ),
        ],
      ],
    );
  }
}

class PopupSecondaryButton extends StatelessWidget {
  const PopupSecondaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: KrithaColors.textSecondary),
    child: Text(label),
  );
}

class PopupPrimaryButton extends StatelessWidget {
  const PopupPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: destructive
          ? KrithaColors.error
          : KrithaColors.accentBlue,
      foregroundColor: destructive ? Colors.white : KrithaColors.textOnAccent,
      side: destructive
          ? BorderSide(color: KrithaColors.borderSubtle)
          : BorderSide.none,
    ),
    child: Text(label),
  );
}
