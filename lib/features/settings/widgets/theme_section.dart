import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../widgets/create_popup.dart';

String themePreferenceLabel(KrithaThemePreference pref) => switch (pref) {
  KrithaThemePreference.system => 'System Default',
  KrithaThemePreference.light => 'Light',
  KrithaThemePreference.dark => 'Dark',
};

Future<void> showThemeSelectorDialog(BuildContext context) {
  return createPopup<void>(
    context: context,
    builder: (_) => const _ThemeSelectorDialog(),
  );
}

class _ThemeSelectorDialog extends ConsumerWidget {
  const _ThemeSelectorDialog();

  static const _options = [
    (KrithaThemePreference.system, 'System Default', 'Follow the device theme'),
    (KrithaThemePreference.light, 'Light', 'Always use the light theme'),
    (KrithaThemePreference.dark, 'Dark', 'Always use the dark theme'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themePreferenceProvider);
    return CreatePopup(
      title: 'Theme',
      subtitle: 'Choose how Kritha appears on your device.',
      actions: [
        PopupSecondaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _options)
              Material(
                color: Colors.transparent,
                child: RadioListTile<KrithaThemePreference>(
                  value: option.$1,
                  // ignore: deprecated_member_use
                  groupValue: selected,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(themePreferenceProvider.notifier)
                          .setPreference(value);
                      Navigator.of(context).pop();
                    }
                  },
                  title: Text(option.$2),
                  subtitle: Text(
                    option.$3,
                    style: TextStyle(
                      color: KrithaColors.textMuted,
                      fontSize: KrithaText.sizeXs,
                    ),
                  ),
                  activeColor: KrithaColors.accentBlue,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: KrithaSpacing.s8,
                  ),
                  dense: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
