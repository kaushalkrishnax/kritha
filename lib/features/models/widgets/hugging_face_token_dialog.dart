import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../widgets/create_popup.dart';
import '../providers.dart';

Future<void> showHuggingFaceTokenDialog(BuildContext context) {
  return createPopup<void>(
    context: context,
    builder: (_) => const _HuggingFaceTokenDialog(),
  );
}

class _HuggingFaceTokenDialog extends ConsumerStatefulWidget {
  const _HuggingFaceTokenDialog();

  @override
  ConsumerState<_HuggingFaceTokenDialog> createState() =>
      _HuggingFaceTokenDialogState();
}

class _HuggingFaceTokenDialogState
    extends ConsumerState<_HuggingFaceTokenDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _controller.text.trim();
    if (token.isEmpty || _saving) return;
    setState(() => _saving = true);
    final saved = await ref.read(huggingFaceTokenProvider.notifier).save(token);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) _controller.clear();
  }

  Future<void> _remove() async {
    await ref.read(huggingFaceTokenProvider.notifier).remove();
    if (!mounted) return;
    _controller.clear();
  }

  Future<void> _validate() async {
    await ref.read(huggingFaceTokenProvider.notifier).validate();
  }

  @override
  Widget build(BuildContext context) {
    final tokenState = ref.watch(huggingFaceTokenProvider);
    final value = tokenState.value;
    final hasToken = value?.hasToken ?? false;
    final busy = _saving || (value?.validating ?? false);

    return CreatePopup(
      title: 'Hugging Face token',
      leading: KrithaIcon(
        icon: HugeIcons.strokeRoundedLockKeyhole,
        size: KrithaIcons.md,
        color: KrithaColors.textMuted,
      ),
      actions: [
        PopupSecondaryButton(
          label: 'Close',
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, text, _) => PopupPrimaryButton(
            label: busy
                ? 'Saving…'
                : hasToken
                ? 'Replace'
                : 'Save token',
            onPressed: busy || text.text.trim().isEmpty ? null : _save,
          ),
        ),
      ],
      child: SizedBox(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(KrithaSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Public model discovery works without a token. A token raises '
                'the authenticated rate limit and can unlock gated repositories '
                'and private models your account can access.',
                style: TextStyle(
                  fontSize: KrithaText.sizeSm,
                  color: KrithaColors.textMuted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: KrithaSpacing.s16),
              if (hasToken) ...[
                Container(
                  padding: EdgeInsets.all(KrithaSpacing.s12),
                  decoration: BoxDecoration(
                    color: KrithaColors.bgTertiary,
                    borderRadius: BorderRadius.circular(KrithaRadius.base),
                    border: Border.all(color: KrithaColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value?.accountName == null
                            ? 'A token is saved.'
                            : 'Signed in as ${value!.accountName}.',
                        style: TextStyle(
                          fontSize: KrithaText.sizeSm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: KrithaSpacing.s4),
                      Text(
                        'The token is never displayed after saving.',
                        style: TextStyle(
                          fontSize: KrithaText.sizeXs,
                          color: KrithaColors.textMuted,
                        ),
                      ),
                      SizedBox(height: KrithaSpacing.s8),
                      Wrap(
                        spacing: KrithaSpacing.s8,
                        runSpacing: KrithaSpacing.s8,
                        children: [
                          TextButton(
                            onPressed: busy ? null : _validate,
                            child: const Text('Validate'),
                          ),
                          TextButton(
                            onPressed: busy ? null : _remove,
                            style: TextButton.styleFrom(
                              foregroundColor: KrithaColors.error,
                            ),
                            child: const Text('Remove token'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: KrithaSpacing.s16),
              ],
              Text(
                hasToken ? 'Replace the saved token' : 'Add a token',
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: KrithaColors.textMuted,
                ),
              ),
              SizedBox(height: KrithaSpacing.s8),
              TextField(
                controller: _controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'hf_…',
                  filled: true,
                  fillColor: KrithaColors.bgPrimary,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: KrithaSpacing.s12,
                    vertical: KrithaSpacing.s12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KrithaRadius.base),
                    borderSide: BorderSide(color: KrithaColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KrithaRadius.base),
                    borderSide: BorderSide(color: KrithaColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KrithaRadius.base),
                    borderSide: BorderSide(color: KrithaColors.borderAccent),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              if (value?.error != null) ...[
                SizedBox(height: KrithaSpacing.s8),
                Text(
                  value!.error!,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.error,
                  ),
                ),
              ],
              if (value?.notice != null) ...[
                SizedBox(height: KrithaSpacing.s8),
                Text(
                  value!.notice!,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
