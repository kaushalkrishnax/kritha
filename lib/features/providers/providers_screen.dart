import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../widgets/back_navigation.dart';
import '../../widgets/create_popup.dart';
import '../../widgets/skeleton.dart';
import '../intelligence/providers/providers.dart';
import '../models/widgets/workspace_header.dart';
import 'providers_controller.dart';

class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  Future<void> _openCustomProvider(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => const _CustomProviderDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchKrithaPalette(context);
    final providers = ref.watch(providersControllerProvider);

    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: 'Providers',
                  onBack: () => goBackOrExit(context),
                  actions: [
                    _CustomProviderAction(
                      onTap: () => _openCustomProvider(context),
                    ),
                  ],
                ),
                Expanded(
                  child: providers.when(
                    data: (state) => _ProvidersBody(state: state),
                    loading: () => const _ProvidersSkeleton(),
                    error: (error, stackTrace) => Padding(
                      padding: EdgeInsets.all(KrithaSpacing.s16),
                      child: _ErrorCard(
                        message:
                            'Provider settings could not be loaded from local storage.',
                        onRetry: () =>
                            ref.invalidate(providersControllerProvider),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvidersBody extends ConsumerWidget {
  const _ProvidersBody({required this.state});

  final ProvidersState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaults = state.defaultProviders;
    final customs = state.customProviders;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s4,
        KrithaSpacing.s16,
        KrithaSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final configuration in defaults) ...[
            _ProviderCard(
              configuration: configuration,
            ),
            SizedBox(height: KrithaSpacing.s10),
          ],
          if (customs.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(
                left: KrithaSpacing.s4,
                right: KrithaSpacing.s4,
                top: KrithaSpacing.s16,
                bottom: KrithaSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Providers',
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: FontWeight.w700,
                      color: KrithaColors.textPrimary,
                    ),
                  ),
                  Text(
                    'User-configured OpenAI-compatible endpoints.',
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            for (final configuration in customs) ...[
              _ProviderCard(
                configuration: configuration,
              ),
              SizedBox(height: KrithaSpacing.s10),
            ],
          ],
        ],
      ),
    );
  }
}

class _CustomProviderAction extends StatelessWidget {
  const _CustomProviderAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add a custom OpenAI-compatible provider',
      child: Material(
        color: KrithaColors.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.base),
          side: BorderSide(color: KrithaColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: KrithaColors.contextMenuPressed,
          focusColor: KrithaColors.contextMenuPressed,
          splashColor: KrithaColors.contextMenuPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: KrithaSpacing.s12,
              vertical: KrithaSpacing.s10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KrithaIcon(
                  icon: HugeIcons.strokeRoundedListPlus,
                  size: KrithaIcons.sm,
                  color: KrithaColors.textSecondary,
                ),
                SizedBox(width: KrithaSpacing.s6),
                Text(
                  'Custom provider',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    fontWeight: FontWeight.w600,
                    color: KrithaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvidersSkeleton extends StatelessWidget {
  const _ProvidersSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s4,
        KrithaSpacing.s16,
        KrithaSpacing.s32,
      ),
      child: Column(
        children: [
          for (var index = 0; index < 7; index++) ...[
            const _ProviderCardSkeleton(),
            SizedBox(height: KrithaSpacing.s10),
          ],
        ],
      ),
    );
  }
}

class _ProviderCardSkeleton extends StatelessWidget {
  const _ProviderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final buttonRadius = BorderRadius.circular(KrithaRadius.base);
    return WorkspaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s14,
        vertical: KrithaSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                width: 36,
                height: 36,
                radius: BorderRadius.circular(KrithaRadius.base),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 13),
                    SizedBox(height: KrithaSpacing.s6),
                    SkeletonBox(height: 11),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Row(
            children: [
              SkeletonBox(width: 72, height: 44, radius: buttonRadius),
              SizedBox(width: KrithaSpacing.s8),
              SkeletonBox(width: 82, height: 44, radius: buttonRadius),
              const Spacer(),
              SkeletonBox(width: 88, height: 44, radius: buttonRadius),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard({required this.configuration});

  final ProviderConfiguration configuration;

  Future<void> _configure(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => _ProviderConfigDialog(configuration: configuration),
    );
  }

  Future<void> _openUsage(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => _ProviderUsagePopup(
        providerId: configuration.id,
        providerName: configuration.alias,
      ),
    );
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    try {
      final engine = ref.read(intelligenceEngineProvider);
      final result = await engine.testProvider(configuration.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e')),
      );
    }
  }

  Future<void> _deleteProvider(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => _DeleteProviderDialog(configuration: configuration),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustom = !defaultProviderIds.contains(configuration.id);
    return WorkspaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s14,
        vertical: KrithaSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                  border: Border.all(color: KrithaColors.borderSubtle),
                ),
                child: KrithaIcon(
                  icon: _providerIcon(configuration),
                  size: KrithaIcons.base,
                  color: KrithaColors.textSecondary,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerDisplayName(configuration.alias),
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      configuration.baseUrl ?? 'Local runtime',
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (configuration.hasCredential && !configuration.isLocal) ...[
                SizedBox(width: KrithaSpacing.s6),
                Tooltip(
                  message: 'Configured',
                  child: KrithaIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    size: KrithaIcons.sm,
                    color: KrithaColors.success,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: KrithaSpacing.s10),
          Row(
            children: [
              WorkspaceOutlinedAction(
                label: 'Test',
                icon: HugeIcons.strokeRoundedActivity01,
                onPressed: (configuration.isLocal || configuration.hasCredential)
                    ? () => _test(context, ref)
                    : null,
              ),
              SizedBox(width: KrithaSpacing.s8),
              WorkspaceOutlinedAction(
                label: 'Usage',
                icon: HugeIcons.strokeRoundedAnalytics01,
                onPressed: configuration.hasCredential
                    ? () => _openUsage(context)
                    : null,
              ),
              const Spacer(),
              WorkspaceOutlinedAction(
                label: 'Configure',
                icon: HugeIcons.strokeRoundedSettings01,
                onPressed: configuration.isLocal ? null : () => _configure(context),
              ),
              if (isCustom) ...[
                SizedBox(width: KrithaSpacing.s8),
                WorkspaceOutlinedAction(
                  label: 'Delete',
                  icon: HugeIcons.strokeRoundedDelete01,
                  onPressed: () => _deleteProvider(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<List<dynamic>> _providerIcon(ProviderConfiguration configuration) {
    return switch (configuration.alias.toLowerCase()) {
      'local-litertlm' => HugeIcons.strokeRoundedCpu,
      'google-gemini' => HugeIcons.strokeRoundedGoogleGemini,
      'anthropic' => HugeIcons.strokeRoundedClaude,
      'xai' => HugeIcons.strokeRoundedGrok02,
      'mistral' => HugeIcons.strokeRoundedMistral,
      'openai' => HugeIcons.strokeRoundedChatGpt,
      _ => HugeIcons.strokeRoundedAiChip,
    };
  }
}

class _ProviderUsagePopup extends ConsumerWidget {
  const _ProviderUsagePopup({
    required this.providerId,
    required this.providerName,
  });

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreatePopup(
      title: '$providerName usage',
      subtitle: 'Tracked locally on this device',
      actions: [
        PopupSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KrithaSpacing.s20,
          0,
          KrithaSpacing.s20,
          KrithaSpacing.s20,
        ),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Usage tracking is not yet implemented for providers.',
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderConfigDialog extends ConsumerStatefulWidget {
  const _ProviderConfigDialog({required this.configuration});

  final ProviderConfiguration configuration;

  @override
  ConsumerState<_ProviderConfigDialog> createState() =>
      _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends ConsumerState<_ProviderConfigDialog> {
  late final TextEditingController _baseUrl;
  final _apiKey = TextEditingController();
  late final TextEditingController _alias;
  String? _error;
  String? _aliasError;
  bool _saving = false;

  bool get isCustom => !defaultProviderIds.contains(widget.configuration.id);

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.configuration.baseUrl ?? '');
    _alias =
        TextEditingController(text: widget.configuration.alias);
    _apiKey.text = widget.configuration.apiKey ?? '';
    _alias.addListener(_validateAlias);
  }

  @override
  void dispose() {
    _alias.removeListener(_validateAlias);
    _baseUrl.dispose();
    _alias.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _validateAlias() async {
    final conflict = await ref
        .read(providersControllerProvider.notifier)
        .aliasConflict(
          _alias.text,
          excludingProviderId: widget.configuration.id,
        );
    if (!mounted) return;
    setState(() => _aliasError = conflict);
  }

  Future<void> _save() async {
    if (_aliasError != null) return;
    final controller = ref.read(providersControllerProvider.notifier);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await controller.updateCustomProvider(
        widget.configuration.id,
        baseUrl: _baseUrl.text,
        alias: _alias.text,
        apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text,
      );
    } on ProviderConfigurationException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      return;
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The provider settings could not be saved.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Provider settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: widget.configuration.alias,
      actions: [
        PopupSecondaryButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        PopupPrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          onPressed: _saving ? null : _save,
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(KrithaSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              const _FieldLabel('API URL'),
              SizedBox(height: KrithaSpacing.s6),
              TextField(
                controller: _baseUrl,
                autocorrect: false,
                decoration: _customDecoration(
                  hintText: 'https://api.example.com/v1',
                ),
              ),
              SizedBox(height: KrithaSpacing.s14),
            ],
            const _FieldLabel('API key'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _apiKey,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _customDecoration(
                hintText: widget.configuration.hasCredential
                    ? 'Leave blank to keep the saved API key'
                    : 'Paste an API key',
              ),
            ),
            SizedBox(height: KrithaSpacing.s14),
            const _FieldLabel('Alias'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _alias,
              autocorrect: false,
              decoration: _aliasDecoration(),
            ),
            if (_aliasError != null) ...[
              SizedBox(height: KrithaSpacing.s4),
              Text(
                _aliasError!,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.error,
                ),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: KrithaSpacing.s8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _aliasDecoration() {
    final hasError = _aliasError != null;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KrithaRadius.base),
      borderSide: BorderSide(color: KrithaColors.error),
    );
    return InputDecoration(
      hintText: 'Unique provider alias',
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
      enabledBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(KrithaRadius.base),
              borderSide: BorderSide(color: KrithaColors.borderSubtle),
            ),
      focusedBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(KrithaRadius.base),
              borderSide: BorderSide(color: KrithaColors.borderAccent),
            ),
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
    );
  }

  InputDecoration _customDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
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
    );
  }
}

class _CustomProviderDialog extends ConsumerStatefulWidget {
  const _CustomProviderDialog();

  @override
  ConsumerState<_CustomProviderDialog> createState() =>
      _CustomProviderDialogState();
}

class _CustomProviderDialogState extends ConsumerState<_CustomProviderDialog> {
  late final TextEditingController _baseUrl = TextEditingController();
  late final TextEditingController _alias = TextEditingController();
  final _apiKey = TextEditingController();
  String? _error;
  String? _aliasError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _alias.addListener(_validateAlias);
  }

  @override
  void dispose() {
    _alias.removeListener(_validateAlias);
    _baseUrl.dispose();
    _alias.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _validateAlias() async {
    final conflict = await ref
        .read(providersControllerProvider.notifier)
        .aliasConflict(_alias.text);
    if (!mounted) return;
    setState(() => _aliasError = conflict);
  }

  Future<void> _save() async {
    if (_aliasError != null) return;
    final controller = ref.read(providersControllerProvider.notifier);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await controller.createCustomProvider(
        baseUrl: _baseUrl.text,
        alias: _alias.text,
        apiKey: _apiKey.text,
      );
    } on ProviderConfigurationException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      return;
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The provider settings could not be saved.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom provider created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'New custom provider',
      actions: [
        PopupSecondaryButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        PopupPrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          onPressed: _saving ? null : _save,
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(KrithaSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FieldLabel('API URL'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _baseUrl,
              autocorrect: false,
              decoration: _customDecoration(
                hintText: 'https://api.example.com/v1',
              ),
            ),
            SizedBox(height: KrithaSpacing.s14),
            const _FieldLabel('API key'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _apiKey,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _customDecoration(
                hintText: 'Paste an API key (optional)',
              ),
            ),
            SizedBox(height: KrithaSpacing.s14),
            const _FieldLabel('Alias'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _alias,
              autocorrect: false,
              decoration: _aliasDecoration(),
            ),
            if (_aliasError != null) ...[
              SizedBox(height: KrithaSpacing.s4),
              Text(
                _aliasError!,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.error,
                ),
              ),
            ],
            SizedBox(height: KrithaSpacing.s6),
            Text(
              'The alias identifies this provider in lists. Model IDs are '
              'kept exactly as the API returns them.',
              style: TextStyle(
                fontSize: KrithaText.size2xs,
                color: KrithaColors.textMuted,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: KrithaSpacing.s8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _aliasDecoration() {
    final hasError = _aliasError != null;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KrithaRadius.base),
      borderSide: BorderSide(color: KrithaColors.error),
    );
    return InputDecoration(
      hintText: 'Derived from the URL when left empty',
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
      enabledBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(KrithaRadius.base),
              borderSide: BorderSide(color: KrithaColors.borderSubtle),
            ),
      focusedBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(KrithaRadius.base),
              borderSide: BorderSide(color: KrithaColors.borderAccent),
            ),
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
    );
  }

  InputDecoration _customDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
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
    );
  }
}

class _DeleteProviderDialog extends ConsumerStatefulWidget {
  const _DeleteProviderDialog({required this.configuration});

  final ProviderConfiguration configuration;

  @override
  ConsumerState<_DeleteProviderDialog> createState() =>
      _DeleteProviderDialogState();
}

class _DeleteProviderDialogState extends ConsumerState<_DeleteProviderDialog> {
  bool _confirming = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await ref
          .read(providersControllerProvider.notifier)
          .deleteProvider(widget.configuration.id);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = error.toString();
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'Delete Provider',
      actions: [
        PopupSecondaryButton(
          label: 'Cancel',
          onPressed: _confirming ? null : () => Navigator.of(context).pop(),
        ),
        PopupPrimaryButton(
          label: _confirming ? 'Deleting…' : 'Delete Provider',
          onPressed: _confirming ? null : _delete,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Deleting "${widget.configuration.alias}" may leave its models '
            'unavailable. Any Active Models assignments referencing it may '
            'become unspecified and need to be reconfigured.',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textMuted,
              height: 1.4,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: KrithaSpacing.s8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: KrithaText.sizeXs,
        fontWeight: FontWeight.w600,
        color: KrithaColors.textSecondary,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
            ),
          ),
          SizedBox(height: KrithaSpacing.s12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: KrithaColors.textSecondary,
              side: BorderSide(color: KrithaColors.borderStrong),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KrithaRadius.base),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
