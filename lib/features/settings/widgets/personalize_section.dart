import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../services/personalization_settings.dart';
import '../../../widgets/create_popup.dart';
import 'settings_primitives.dart';

class PersonalizeControl extends ConsumerWidget {
  const PersonalizeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(personalizationProvider);
    final name = settings.userName.trim();
    final detailsSubtitle = name.isNotEmpty
        ? 'Name: $name${settings.hasPersonalDetails ? ' • Shared with Kritha' : ''}'
        : 'Optional name, interests, and extra context.';
    final instructionsSubtitle = settings.isDefaultPrompt
        ? 'Default Kritha assistant prompt.'
        : 'Custom system prompt active.';

    return SettingsCard(
      child: Column(
        children: [
          SettingsActionRow(
            icon: HugeIcons.strokeRoundedUserGroup,
            label: 'Personal Details',
            description: detailsSubtitle,
            onTap: () => createPopup<void>(
              context: context,
              builder: (_) => const _PersonalDetailsDialog(),
            ),
          ),
          const SettingsRowDivider(),
          SettingsActionRow(
            icon: HugeIcons.strokeRoundedEdit03,
            label: 'AI Instructions',
            description: instructionsSubtitle,
            onTap: () => createPopup<void>(
              context: context,
              builder: (_) => const _AiInstructionsDialog(),
            ),
          ),
          const SettingsRowDivider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Opacity(
              opacity: 0.55,
              child: Row(
                children: [
                  KrithaIcon(
                    icon: HugeIcons.strokeRoundedAiBrain03,
                    size: KrithaIcons.lg,
                    color: KrithaColors.textMuted,
                  ),
                  SizedBox(width: KrithaSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Memories'),
                        SizedBox(height: 2),
                        Text(
                          'Remember facts and preferences across chats.',
                          style: TextStyle(
                            color: KrithaColors.textMuted,
                            fontSize: KrithaText.sizeXs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: KrithaSpacing.s8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: KrithaSpacing.s8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: KrithaColors.bgPrimary,
                      borderRadius: BorderRadius.circular(KrithaRadius.full),
                      border: Border.all(color: KrithaColors.borderSubtle),
                    ),
                    child: Text(
                      'Coming soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsDialog extends ConsumerStatefulWidget {
  const _PersonalDetailsDialog();

  @override
  ConsumerState<_PersonalDetailsDialog> createState() =>
      _PersonalDetailsDialogState();
}

class _PersonalDetailsDialogState
    extends ConsumerState<_PersonalDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _interestsController;
  late final TextEditingController _extrasController;

  @override
  void initState() {
    super.initState();
    final current = ref.read(personalizationProvider);
    _nameController = TextEditingController(text: current.userName);
    _interestsController = TextEditingController(text: current.interests);
    _extrasController = TextEditingController(text: current.extras);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _interestsController.dispose();
    _extrasController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(personalizationProvider.notifier)
        .setPersonalDetails(
          userName: _nameController.text,
          interests: _interestsController.text,
          extras: _extrasController.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'Personal Details',
      subtitle: 'All fields are optional and included with your chat context.',
      actions: [
        PopupSecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PopupPrimaryButton(label: 'Save', onPressed: _save),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.sm),
                ),
              ),
            ),
            SizedBox(height: KrithaSpacing.s12),
            TextField(
              controller: _interestsController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Interests (optional)',
                hintText: 'e.g. Flutter, local AI, photography',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.sm),
                ),
              ),
            ),
            SizedBox(height: KrithaSpacing.s12),
            TextField(
              controller: _extrasController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Extras (optional)',
                hintText: 'Role, preferred style, or anything else helpful',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInstructionsDialog extends ConsumerStatefulWidget {
  const _AiInstructionsDialog();

  @override
  ConsumerState<_AiInstructionsDialog> createState() =>
      _AiInstructionsDialogState();
}

class _AiInstructionsDialogState extends ConsumerState<_AiInstructionsDialog> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: ref.read(personalizationProvider).systemPrompt,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(personalizationProvider.notifier)
        .setSystemPrompt(_promptController.text);
    if (mounted) Navigator.of(context).pop();
  }

  void _resetToDefault() {
    _promptController.text = PersonalizationSettings.defaultSystemPrompt;
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'AI Instructions',
      subtitle: 'Seeded as the system message at the top of every turn.',
      footer: Row(
        children: [
          PopupSecondaryButton(label: 'Reset', onPressed: _resetToDefault),
          const Spacer(),
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: KrithaSpacing.s8),
          PopupPrimaryButton(label: 'Save', onPressed: _save),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s20),
        child: TextField(
          controller: _promptController,
          minLines: 7,
          maxLines: 14,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter system instructions for Kritha…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KrithaRadius.sm),
            ),
          ),
        ),
      ),
    );
  }
}
