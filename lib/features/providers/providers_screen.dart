import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/back_navigation.dart';
import '../../widgets/create_popup.dart';
import '../../widgets/skeleton.dart';
import '../models/widgets/workspace_header.dart';
import 'provider_alias.dart';
import 'provider_connection_tester.dart';
import 'provider_definition.dart';
import 'provider_stores.dart';
import 'provider_usage.dart';
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
                        message: 'Provider settings could not be loaded from local storage.',
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
    final configurations = [
      for (final definition in builtInInferenceProviders)
        if (!definition.isLocal) ?state.configurationFor(definition.id),
      ...state.customConfigurations,
    ];
    final configured = configurations
        .where((c) => c.hasRequiredCredentials)
        .toList();
    final notConfigured = configurations
        .where((c) => !c.hasRequiredCredentials)
        .toList();

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
          for (final configuration in configured) ...[
            _ProviderCard(
              definition: configuration.definition,
              configuration: configuration,
              result: state.testResults[configuration.providerId],
              testing: state.testing.contains(configuration.providerId),
            ),
            SizedBox(height: KrithaSpacing.s10),
          ],
          if (notConfigured.isNotEmpty) ...[
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
                    'Not Configured',
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: FontWeight.w700,
                      color: KrithaColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Configure more providers',
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            for (final configuration in notConfigured) ...[
              _ProviderCard(
                definition: configuration.definition,
                configuration: configuration,
                result: state.testResults[configuration.providerId],
                testing: state.testing.contains(configuration.providerId),
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
                    SizedBox(height: KrithaSpacing.s4),
                    SkeletonBox(width: 210, height: 11),
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
  const _ProviderCard({
    required this.definition,
    required this.configuration,
    required this.result,
    required this.testing,
  });

  final InferenceProviderDefinition definition;
  final ProviderConfiguration configuration;
  final ProviderConnectionResult? result;
  final bool testing;

  Future<void> _configure(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => definition.isCustom
          ? _CustomProviderDialog(configuration: configuration)
          : _ProviderConfigDialog(
              definition: definition,
              configuration: configuration,
            ),
    );
  }

  Future<void> _openUsage(BuildContext context) async {
    await createPopup<void>(
      context: context,
      builder: (_) => _ProviderUsagePopup(
        providerId: configuration.providerId,
        providerName: definition.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = testing ? 'Testing connection…' : result?.message;
    final messageColor = testing
        ? KrithaColors.textMuted
        : result == null
        ? KrithaColors.textMuted
        : result!.ok
        ? KrithaColors.success
        : KrithaColors.error;
    final available = configuration.hasRequiredCredentials;
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
                  icon: _providerIcon(definition),
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
                      definition.isCustom
                          ? configuration.alias
                          : definition.name,
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      definition.isCustom
                          ? 'Alias ${configuration.alias} · ${configuration.baseUrl}'
                          : definition.description,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    if (message != null) ...[
                      SizedBox(height: KrithaSpacing.s4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: KrithaText.size2xs,
                          color: messageColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (configuration.configured) ...[
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
                busy: testing,
                onPressed: testing || !available
                    ? null
                    : () => ref
                          .read(providersControllerProvider.notifier)
                          .testConnection(configuration.providerId),
              ),
              SizedBox(width: KrithaSpacing.s8),
              WorkspaceOutlinedAction(
                label: 'Usage',
                icon: HugeIcons.strokeRoundedAnalytics01,
                onPressed: available ? () => _openUsage(context) : null,
              ),
              const Spacer(),
              if (available)
                WorkspaceOutlinedAction(
                  label: 'Configure',
                  icon: HugeIcons.strokeRoundedSettings01,
                  onPressed: () => _configure(context),
                )
              else
                _ProviderConnectAction(onPressed: () => _configure(context)),
            ],
          ),
        ],
      ),
    );
  }

  static List<List<dynamic>> _providerIcon(
    InferenceProviderDefinition definition,
  ) {
    return switch (definition.id) {
      'openai' => HugeIcons.strokeRoundedChatGpt,
      'anthropic' => HugeIcons.strokeRoundedClaude,
      'google' => HugeIcons.strokeRoundedGoogleGemini,
      'xai' => HugeIcons.strokeRoundedGrok02,
      'groq' => HugeIcons.strokeRoundedEnergy,
      'deepseek' => HugeIcons.strokeRoundedDeepseek,
      'perplexity' => HugeIcons.strokeRoundedPerplexityAi,
      'qwen' => HugeIcons.strokeRoundedQwen,
      'huggingface' => HugeIcons.strokeRoundedHappy01,
      'mistral' => HugeIcons.strokeRoundedMistral,
      _ => HugeIcons.strokeRoundedAiChip,
    };
  }
}

class _ProviderConnectAction extends StatelessWidget {
  const _ProviderConnectAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: KrithaColors.accentBlue,
        foregroundColor: KrithaColors.textOnAccent,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.base),
        ),
      ),
      icon: KrithaIcon(
        icon: HugeIcons.strokeRoundedPlus,
        size: 16,
        color: KrithaColors.textOnAccent,
      ),
      label: const Text(
        'Connect',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
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
    final usage =
        ref.watch(providerUsageProvider).value?[providerId] ??
        const ProviderUsage();
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
              Container(
                padding: EdgeInsets.all(KrithaSpacing.s14),
                decoration: BoxDecoration(
                  color: KrithaColors.bgPrimary,
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                  border: Border.all(color: KrithaColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    _UsageRow(
                      label: 'Total API requests',
                      value: usage.requests,
                    ),
                    SizedBox(height: KrithaSpacing.s10),
                    _UsageRow(
                      label: 'Successful responses',
                      value: usage.successes,
                      valueColor: KrithaColors.success,
                    ),
                    SizedBox(height: KrithaSpacing.s10),
                    _UsageRow(
                      label: 'Failed requests',
                      value: usage.failures,
                      valueColor: KrithaColors.error,
                    ),
                  ],
                ),
              ),
              if (usage.isEmpty) ...[
                SizedBox(height: KrithaSpacing.s12),
                Text(
                  'No usage has been recorded yet. Counts appear after this '
                  'provider completes an API request.',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textMuted,
                    height: 1.4,
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

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value, this.valueColor});

  final String label;
  final int value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: KrithaSpacing.s12),
        Text(
          '$value',
          style: TextStyle(
            fontSize: KrithaText.sizeSm,
            fontWeight: FontWeight.w700,
            color: valueColor ?? KrithaColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ProviderConfigDialog extends ConsumerStatefulWidget {
  const _ProviderConfigDialog({
    required this.definition,
    required this.configuration,
  });

  final InferenceProviderDefinition definition;
  final ProviderConfiguration configuration;

  @override
  ConsumerState<_ProviderConfigDialog> createState() =>
      _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends ConsumerState<_ProviderConfigDialog> {
  late final TextEditingController _baseUrl = TextEditingController(
    text: widget.configuration.baseUrl,
  );
  final _credential = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _credential.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final definition = widget.definition;
    final baseUrl = _baseUrl.text.trim();
    if (definition.supportsCustomEndpoint) {
      final uri = Uri.tryParse(baseUrl);
      if (baseUrl.isEmpty ||
          uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        setState(() {
          _error = 'Enter a full http:// or https:// endpoint URL.';
        });
        return;
      }
    }
    final credential = _credential.text.trim();
    final current = ref
        .watch(providersControllerProvider)
        .value
        ?.configurationFor(definition.id);
    final hasCredential =
        current?.hasCredential ?? widget.configuration.hasCredential;
    if (definition.requiresCredential && !hasCredential && credential.isEmpty) {
      setState(() {
        _error =
            'Enter a ${definition.credentialLabel.toLowerCase()} to connect.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(providersControllerProvider.notifier);
    try {
      if (definition.supportsCustomEndpoint) {
        await controller.setBaseUrl(definition.id, baseUrl);
      }
      if (credential.isNotEmpty) {
        await controller.saveCredential(definition.id, credential);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The provider settings could not be saved.';
      });
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Provider settings saved')),
    );
  }

  Future<void> _removeCredential() async {
    try {
      await ref
          .read(providersControllerProvider.notifier)
          .removeCredential(widget.definition.id);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The credential could not be removed')),
      );
      return;
    }
    if (!mounted) return;
    _credential.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Provider credential removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final configuration = ref
        .watch(providersControllerProvider)
        .value
        ?.configurationFor(definition.id);
    final hasCredential =
        configuration?.hasCredential ?? widget.configuration.hasCredential;
    return CreatePopup(
      title: definition.name,
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
            if (definition.supportsCustomEndpoint) ...[
              _FieldLabel('Endpoint URL'),
              SizedBox(height: KrithaSpacing.s6),
              TextField(
                controller: _baseUrl,
                autocorrect: false,
                decoration: _decoration(
                  hintText: definition.defaultBaseUrl.isEmpty
                      ? 'https://example.com/v1'
                      : definition.defaultBaseUrl,
                ),
              ),
              SizedBox(height: KrithaSpacing.s14),
            ] else ...[
              _FieldLabel('Endpoint'),
              SizedBox(height: KrithaSpacing.s6),
              Text(
                configuration?.baseUrl ?? definition.defaultBaseUrl,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textSecondary,
                ),
              ),
              SizedBox(height: KrithaSpacing.s14),
            ],
            _FieldLabel(definition.credentialLabel),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _credential,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration(
                hintText: hasCredential
                    ? 'Leave blank to keep the saved credential'
                    : 'Paste a new credential',
              ),
            ),
            if (hasCredential) ...[
              SizedBox(height: KrithaSpacing.s8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'A credential is saved and is never displayed.',
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _removeCredential,
                    style: TextButton.styleFrom(
                      foregroundColor: KrithaColors.error,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
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

  InputDecoration _decoration({required String hintText}) {
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
  const _CustomProviderDialog({this.configuration});

  final ProviderConfiguration? configuration;

  @override
  ConsumerState<_CustomProviderDialog> createState() =>
      _CustomProviderDialogState();
}

class _CustomProviderDialogState extends ConsumerState<_CustomProviderDialog> {
  late final TextEditingController _baseUrl = TextEditingController(
    text: widget.configuration?.baseUrl ?? '',
  );
  late final TextEditingController _alias = TextEditingController(
    text: widget.configuration?.alias ?? '',
  );
  final _credential = TextEditingController();
  final _urlFocus = FocusNode();
  String? _error;
  bool _saving = false;

  bool get _editing => widget.configuration != null;

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(_onUrlFocusChanged);
  }

  @override
  void dispose() {
    _urlFocus
      ..removeListener(_onUrlFocusChanged)
      ..dispose();
    _baseUrl.dispose();
    _alias.dispose();
    _credential.dispose();
    super.dispose();
  }

  void _onUrlFocusChanged() {
    if (_urlFocus.hasFocus) return;
    _deriveAliasFromUrl();
  }

  void _deriveAliasFromUrl() {
    if (_alias.text.trim().isNotEmpty) return;
    final derived = deriveProviderAlias(_baseUrl.text);
    if (derived == null || derived.isEmpty) return;
    _alias.value = TextEditingValue(
      text: derived,
      selection: TextSelection.collapsed(offset: derived.length),
    );
  }

  Future<void> _save() async {
    final controller = ref.read(providersControllerProvider.notifier);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await controller.updateCustomProvider(
          widget.configuration!.providerId,
          baseUrl: _baseUrl.text,
          alias: _alias.text,
          credential: _credential.text.trim().isEmpty ? null : _credential.text,
        );
      } else {
        await controller.createCustomProvider(
          baseUrl: _baseUrl.text,
          alias: _alias.text,
          credential: _credential.text,
        );
      }
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
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _editing ? 'Provider updated' : 'Custom provider created',
        ),
      ),
    );
  }

  Future<void> _removeCredential() async {
    try {
      await ref
          .read(providersControllerProvider.notifier)
          .removeCredential(widget.configuration!.providerId);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The API key could not be removed')),
      );
      return;
    }
    if (!mounted) return;
    _credential.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Provider API key removed')));
  }

  @override
  Widget build(BuildContext context) {
    final configuration = widget.configuration == null
        ? null
        : ref
              .watch(providersControllerProvider)
              .value
              ?.configurationFor(widget.configuration!.providerId);
    final hasCredential =
        configuration?.hasCredential ??
        widget.configuration?.hasCredential ??
        false;
    return CreatePopup(
      title: _editing ? 'Edit custom provider' : 'New custom provider',
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
              focusNode: _urlFocus,
              autocorrect: false,
              decoration: _customDecoration(
                hintText: 'https://api.example.com/v1',
              ),
            ),
            SizedBox(height: KrithaSpacing.s14),
            const _FieldLabel('API key'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _credential,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _customDecoration(
                hintText: hasCredential
                    ? 'Leave blank to keep the saved API key'
                    : 'Paste an API key (optional)',
              ),
            ),
            if (hasCredential) ...[
              SizedBox(height: KrithaSpacing.s8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'An API key is saved and is never displayed.',
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _removeCredential,
                    style: TextButton.styleFrom(
                      foregroundColor: KrithaColors.error,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ],
            SizedBox(height: KrithaSpacing.s14),
            const _FieldLabel('API Alias'),
            SizedBox(height: KrithaSpacing.s6),
            TextField(
              controller: _alias,
              autocorrect: false,
              decoration: _customDecoration(
                hintText: 'Derived from the URL when left empty',
              ),
            ),
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
