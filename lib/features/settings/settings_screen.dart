import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/back_navigation.dart';
import '../../widgets/create_popup.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/chat_sidebar.dart';
import 'widgets/personalize_section.dart';
import 'widgets/runtime_probes_section.dart';
import 'widgets/settings_primitives.dart';
import 'widgets/theme_section.dart';
import 'widgets/voice_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchKrithaPalette(context);
    final runtime = ref.watch(runtimeStatusProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, -1.1),
            radius: 1.2,
            colors: [
              Color(0x1A22D3EE),
              KrithaColors.bgBase.withValues(alpha: 0),
            ],
            stops: [0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SettingsHeader(onBack: () => goBackOrExit(context)),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const SettingsSectionLabel('VOICE'),
                    const WakeWordControl(),
                    SizedBox(height: KrithaSpacing.s12),
                    const DefaultAssistantControl(),
                    SizedBox(height: KrithaSpacing.s12),
                    const TtsSettingsControl(),
                    SizedBox(height: 22),
                    const SettingsSectionLabel('PERSONALIZE'),
                    const PersonalizeControl(),
                    SizedBox(height: 22),
                    const SettingsSectionLabel('THEME'),
                    const ThemeControl(),
                    SizedBox(height: 22),
                    const SettingsSectionLabel('PRIVACY'),
                    SettingsCard(
                      child: Column(
                        children: [
                          SettingsActionRow(
                            icon: HugeIcons.strokeRoundedArchive,
                            label: 'Archived chats',
                            description:
                                'Restore or permanently delete archived conversations.',
                            onTap: () => createPopup<void>(
                              context: context,
                              builder: (_) => const ArchivedSessionsDialog(),
                            ),
                          ),
                          const SettingsRowDivider(),
                          SettingsActionRow(
                            icon: HugeIcons.strokeRoundedShieldCheck,
                            label: 'Permissions',
                            description:
                                'Microphone, notifications, and device access.',
                            onTap: () => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Permissions are not available yet.',
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 22),
                    RuntimeProbesSection(runtime: runtime),
                    SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => _confirmClearHistory(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KrithaColors.textSecondary,
                        side: BorderSide(color: KrithaColors.borderStrong),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KrithaRadius.base,
                          ),
                        ),
                      ),
                      icon: KrithaIcon(
                        icon: HugeIcons.strokeRoundedRotateCcw,
                        size: 16,
                      ),
                      label: const Text('Clear local history'),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Kritha',
                        style: TextStyle(
                          fontSize: KrithaText.size2xs,
                          color: KrithaColors.textDimmed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await createPopup<bool>(
      context: context,
      builder: (_) => CreatePopup(
        title: 'Clear local history?',
        actions: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PopupPrimaryButton(
            label: 'Clear history',
            destructive: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.all(KrithaSpacing.s20),
          child: const Text(
            'This permanently deletes every local conversation '
            'and message on this device. It cannot be undone.',
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(chatControllerProvider.notifier).clearHistory();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local history cleared')),
      );
    }
  }
}
