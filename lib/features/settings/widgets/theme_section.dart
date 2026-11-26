import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import 'settings_primitives.dart';

class ThemeControl extends ConsumerWidget {
  const ThemeControl({super.key});

  static const _options = [
    (KrithaThemePreference.system, 'System Default', 'Follow the device theme'),
    (KrithaThemePreference.light, 'Light', 'Always use the light theme'),
    (KrithaThemePreference.dark, 'Dark', 'Always use the dark theme'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themePreferenceProvider);
    return SettingsCard(
      child: Column(
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
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
        ],
      ),
    );
  }
}
