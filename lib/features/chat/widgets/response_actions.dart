import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';

/// Reply actions under an assistant response, matching the React Native
/// `ResponseActions` row: 20px icons, an 8px ink surface, 2px between items and
/// a 12px gap above the row. Each icon owns a transparent Material so focus,
/// hover and press feedback are visible on the dark transcript.
class ResponseActions extends StatefulWidget {
  const ResponseActions({super.key, required this.text, required this.onSpeak});

  final String text;
  final VoidCallback onSpeak;

  @override
  State<ResponseActions> createState() => _ResponseActionsState();
}

class _ResponseActionsState extends State<ResponseActions> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    if (widget.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share(BuildContext context) async {
    if (widget.text.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: widget.text,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the share sheet.")),
      );
    }
  }

  void _more(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('More response actions are not available in this build.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KrithaSpacing.s12),
      child: Row(
        children: [
          _ActionIcon(
            icon: _copied ? LucideIcons.check : LucideIcons.copy,
            color: _copied ? KrithaColors.success : KrithaColors.iconMuted,
            tooltip: _copied ? 'Copied' : 'Copy reply',
            onTap: _copy,
          ),
          const SizedBox(width: KrithaSpacing.s2),
          _ActionIcon(
            icon: LucideIcons.volume2,
            tooltip: 'Read aloud',
            onTap: widget.onSpeak,
          ),
          const SizedBox(width: KrithaSpacing.s2),
          _ActionIcon(
            icon: LucideIcons.share2,
            tooltip: 'Share reply',
            onTap: () => _share(context),
          ),
          const SizedBox(width: KrithaSpacing.s2),
          _ActionIcon(
            icon: LucideIcons.ellipsisVertical,
            tooltip: 'More actions',
            onTap: () => _more(context),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = KrithaColors.iconMuted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KrithaRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KrithaRadius.lg),
            splashColor: KrithaColors.contextMenuPressed,
            highlightColor: KrithaColors.contextMenuPressed,
            focusColor: KrithaColors.contextMenuPressed,
            hoverColor: KrithaColors.contextMenuPressed,
            child: Padding(
              padding: const EdgeInsets.all(KrithaSpacing.s8),
              child: Icon(icon, size: KrithaIcons.base, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
