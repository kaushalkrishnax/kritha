import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/create_popup.dart';
import '../models/widgets/workspace_header.dart';
import '../intelligence/model_configuration.dart';
import 'provider_connection_tester.dart';
import 'provider_definition.dart';
import 'providers_controller.dart';

class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

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
                  onBack: () => context.go('/chat'),
                ),
                Expanded(
                  child: providers.when(
                    data: (state) => _ProvidersBody(state: state),
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: KrithaColors.accentLightBlue,
                      ),
                    ),
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
    Future<void> addProvider() async {
      final definition = await createPopup<InferenceProviderDefinition>(
        context: context,
        mobileFullScreen: true,
        builder: (_) => const _AddProviderPopup(),
      );
      if (definition == null || !context.mounted) return;
      await ref
          .read(providersControllerProvider.notifier)
          .addProvider(definition.id);
      final configuration = ref
          .read(providersControllerProvider)
          .value
          ?.configurationFor(definition.id);
      if (configuration == null || !context.mounted) return;
      await createPopup<void>(
        context: context,
        builder: (_) => _ProviderConfigDialog(
          definition: definition,
          configuration: configuration,
        ),
      );
    }

    final configured = supportedInferenceProviders
        .where((definition) => !definition.isLocal)
        .where(
          (definition) =>
              state.configurationFor(definition.id)?.configured == true,
        )
        .toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s4,
        KrithaSpacing.s16,
        KrithaSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LocalModelsCard(),
          SizedBox(height: KrithaSpacing.s20),
          WorkspaceSectionTitle(
            'Inference providers',
            trailing: TextButton.icon(
              onPressed: addProvider,
              icon: KrithaIcon(
                icon: HugeIcons.strokeRoundedPlusSign,
                size: KrithaIcons.sm,
                color: KrithaColors.textSecondary,
              ),
              label: const Text('Add provider'),
            ),
          ),
          if (configured.isEmpty)
            WorkspaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No inference providers added',
                    style: TextStyle(
                      fontSize: KrithaText.sizeMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: KrithaSpacing.s4),
                  Text(
                    'Add a provider only when you need one.',
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                  SizedBox(height: KrithaSpacing.s10),
                  WorkspaceOutlinedAction(
                    label: 'Add provider',
                    onPressed: addProvider,
                  ),
                ],
              ),
            ),
          for (final definition in configured) ...[
            _ProviderCard(
              definition: definition,
              configuration: state.configurationFor(definition.id)!,
              result: state.testResults[definition.id],
              testing: state.testing.contains(definition.id),
            ),
            SizedBox(height: KrithaSpacing.s12),
          ],
        ],
      ),
    );
  }
}

class _LocalModelsCard extends ConsumerWidget {
  const _LocalModelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(modelConfigurationProvider).value;
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KrithaIcon(
                icon: HugeIcons.strokeRoundedCpu,
                size: KrithaIcons.md,
                color: KrithaColors.textSecondary,
              ),
              SizedBox(width: KrithaSpacing.s8),
              Expanded(
                child: Text(
                  'Local models',
                  style: TextStyle(
                    fontSize: KrithaText.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                model?.isReady == true ? model!.fileName! : 'No model selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: model?.isReady == true
                      ? KrithaColors.success
                      : KrithaColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s8,
            children: [
              WorkspaceOutlinedAction(
                label: 'Explore local models',
                onPressed: () => context.go('/models'),
              ),
              WorkspaceOutlinedAction(
                label: 'Configure assignments',
                onPressed: () => context.go('/models/active'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddProviderPopup extends ConsumerStatefulWidget {
  const _AddProviderPopup();

  @override
  ConsumerState<_AddProviderPopup> createState() => _AddProviderPopupState();
}

class _AddProviderPopupState extends ConsumerState<_AddProviderPopup> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final providers = supportedInferenceProviders
        .where((item) => !item.isLocal)
        .where(
          (item) => '${item.name} ${item.description}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    final state = ref.watch(providersControllerProvider).value;
    return CreatePopup(
      title: 'Add inference provider',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(KrithaSpacing.s16),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search providers',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];
                final configured =
                    state?.configurationFor(provider.id)?.configured == true;
                return ListTile(
                  title: Text(provider.name),
                  subtitle: Text(provider.description),
                  trailing: configured
                      ? Text(
                          'Added',
                          style: TextStyle(color: KrithaColors.textMuted),
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: !configured,
                  onTap: configured
                      ? null
                      : () => Navigator.of(context).pop(provider),
                );
              },
            ),
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

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    await ref
        .read(providersControllerProvider.notifier)
        .testConnection(definition.id);
  }

  Future<void> _configure(BuildContext context, WidgetRef ref) async {
    await createPopup<void>(
      context: context,
      builder: (_) => _ProviderConfigDialog(
        definition: definition,
        configuration: configuration,
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await createPopup<bool>(
      context: context,
      builder: (_) => CreatePopup(
        title: 'Remove ${definition.name}?',
        actions: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PopupPrimaryButton(
            label: 'Remove provider',
            destructive: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.all(KrithaSpacing.s20),
          child: const Text(
            'The saved credential and provider settings will be removed from this device.',
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(providersControllerProvider.notifier)
        .removeProvider(definition.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialText = definition.isLocal
        ? 'No credential'
        : configuration.hasCredential
        ? '${definition.credentialLabel} saved'
        : definition.requiresCredential
        ? 'No ${definition.credentialLabel.toLowerCase()} saved'
        : 'Credential optional';
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                  border: Border.all(color: KrithaColors.borderSubtle),
                ),
                child: KrithaIcon(
                  icon: definition.isLocal
                      ? HugeIcons.strokeRoundedCpu
                      : definition.kind == ProviderKind.cloud
                      ? HugeIcons.strokeRoundedActivity01
                      : HugeIcons.strokeRoundedPlug02,
                  size: KrithaIcons.base,
                  color: KrithaColors.accentLightBlue,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.name,
                      style: TextStyle(
                        fontSize: KrithaText.sizeMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      definition.description,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: KrithaSpacing.s8),
              Switch(
                value: configuration.enabled,
                onChanged: (value) => ref
                    .read(providersControllerProvider.notifier)
                    .setEnabled(definition.id, value),
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s10),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s6,
            children: [
              _Pill(
                label: configuration.enabled ? 'Enabled' : 'Disabled',
                color: configuration.enabled
                    ? KrithaColors.success
                    : KrithaColors.textMuted,
              ),
              _Pill(label: credentialText, color: KrithaColors.textMuted),
              if (configuration.baseUrl.isNotEmpty)
                _Pill(
                  label: configuration.baseUrl,
                  color: KrithaColors.textMuted,
                ),
            ],
          ),
          if (result != null) ...[
            SizedBox(height: KrithaSpacing.s10),
            Text(
              result!.message,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: result!.ok ? KrithaColors.success : KrithaColors.error,
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s8,
            children: [
              if (!definition.isLocal)
                WorkspaceOutlinedAction(
                  label: 'Configure',
                  onPressed: () => _configure(context, ref),
                ),
              if (!definition.isLocal)
                WorkspaceOutlinedAction(
                  label: 'Available models',
                  onPressed: () => context.go('/models/active'),
                ),
              if (definition.isLocal || definition.canTest)
                WorkspaceOutlinedAction(
                  label: testing
                      ? 'Testing…'
                      : definition.isLocal
                      ? 'Check local model'
                      : 'Test connection',
                  onPressed: testing ? null : () => _test(context, ref),
                  busy: testing,
                ),
              if (!definition.isLocal)
                WorkspaceOutlinedAction(
                  label: 'Remove provider',
                  onPressed: () => _remove(context, ref),
                ),
            ],
          ),
        ],
      ),
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
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(providersControllerProvider.notifier);
    try {
      if (definition.supportsCustomEndpoint) {
        await controller.setBaseUrl(definition.id, baseUrl);
      }
      final credential = _credential.text.trim();
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
            if (!definition.isLocal) ...[
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s8,
        vertical: KrithaSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgTertiary,
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: KrithaText.size2xs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
