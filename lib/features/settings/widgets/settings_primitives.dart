import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Tooltip(
            message: 'Back',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkResponse(
                onTap: onBack,
                customBorder: const CircleBorder(),
                containedInkWell: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: KrithaIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft02,
                    size: 22,
                    color: KrithaColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: KrithaText.sizeLg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: KrithaText.label),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class SettingsRowDivider extends StatelessWidget {
  const SettingsRowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: KrithaColors.borderFaint);
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KrithaRadius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _IconBadge(icon: icon),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: KrithaColors.textSecondary,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              KrithaIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: KrithaColors.textDimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _IconBadge(icon: icon),
          SizedBox(width: KrithaSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: KrithaColors.textSecondary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: KrithaColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class SettingsStatusRow extends StatelessWidget {
  const SettingsStatusRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.mono = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final bool? ok;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final color = switch (ok) {
      true => KrithaColors.success,
      false => KrithaColors.warning,
      null => KrithaColors.textDimmed,
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _IconBadge(icon: icon),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: mono ? 10.5 : 11.5,
                      fontFamily: mono ? 'monospace' : null,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: KrithaColors.bgPrimary,
        borderRadius: BorderRadius.circular(KrithaRadius.sm),
        border: Border.all(color: KrithaColors.borderFaint),
      ),
      child: KrithaIcon(
        icon: icon,
        size: 15,
        color: KrithaColors.textMuted,
      ),
    );
  }
}
