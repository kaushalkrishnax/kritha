import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../widgets/create_popup.dart';
import '../../intelligence/model_configuration.dart';
import '../../providers/providers_controller.dart';
import '../../providers/provider_definition.dart';
import '../../providers/provider_connection_tester.dart';
import '../active/active_models.dart';
import '../catalogue/catalogue_model.dart';
import '../widgets/catalogue_widgets.dart';
import '../widgets/workspace_header.dart';

Future<ActiveModelAssignment?> showModelPicker(
  BuildContext context, {
  required ModelCapability capability,
}) {
  return createPopup<ActiveModelAssignment>(
    context: context,
    mobileFullScreen: true,
    builder: (_) => _ModelPicker(capability: capability),
  );
}

class _ModelPicker extends ConsumerStatefulWidget {
  const _ModelPicker({required this.capability});

  final ModelCapability capability;

  @override
  ConsumerState<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends ConsumerState<_ModelPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _key(ActiveModelAssignment item) => '${item.sourceId}:${item.modelId}';

  bool _matches(ActiveModelAssignment item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.displayName.toLowerCase().contains(query) ||
        item.modelId.toLowerCase().contains(query) ||
        item.sourceId.toLowerCase().contains(query);
  }

  Widget _section(String title, List<ActiveModelAssignment> models) {
    if (models.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionTitle(title),
        for (final model in models) _ModelChoiceRow(model: model),
        SizedBox(height: KrithaSpacing.s14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeValue = ref.watch(activeModelsProvider).value;
    final configValue = ref.watch(modelConfigurationProvider).value;
    final providersValue = ref.watch(providersControllerProvider).value;
    final recent = (activeValue?.recents ?? const <ActiveModelAssignment>[])
        .where(
          (model) => model.capability == widget.capability && _matches(model),
        )
        .toList();
    final recentKeys = recent.map(_key).toSet();

    final local = <ActiveModelAssignment>[];
    if (widget.capability == ModelCapability.text &&
        configValue?.descriptor != null) {
      final model = configValue!.descriptor!;
      final assignment = ActiveModelAssignment(
        capability: widget.capability,
        modelId: model.id,
        displayName: model.displayName,
        runtimeId: model.runtimeId,
        sourceId: 'local-litertlm',
        activatedAt: DateTime.now(),
      );
      if (_matches(assignment) && !recentKeys.contains(_key(assignment))) {
        local.add(assignment);
      }
    }

    final providerGroups =
        <
          (
            String,
            String,
            List<ActiveModelAssignment>,
            AsyncValue<List<ProviderModelInfo>>,
          )
        >[];
    if (widget.capability == ModelCapability.text && providersValue != null) {
      for (final definition in supportedInferenceProviders.where(
        (definition) => !definition.isLocal,
      )) {
        final configuration = providersValue.configurationFor(definition.id);
        if (configuration == null ||
            !configuration.configured ||
            !configuration.enabled) {
          continue;
        }
        final models = ref.watch(providerModelsProvider(definition.id));
        final choices = (models.asData?.value ?? const <ProviderModelInfo>[])
            .where((model) {
              if (!model.supports(widget.capability)) return false;
              final item = ActiveModelAssignment(
                capability: widget.capability,
                modelId: model.id,
                displayName: model.name,
                runtimeId: definition.id,
                sourceId: definition.id,
                activatedAt: DateTime.now(),
              );
              return _matches(item) && !recentKeys.contains(_key(item));
            })
            .map(
              (model) => ActiveModelAssignment(
                capability: widget.capability,
                modelId: model.id,
                displayName: model.name,
                runtimeId: definition.id,
                sourceId: definition.id,
                activatedAt: DateTime.now(),
              ),
            )
            .toList();
        providerGroups.add((definition.name, definition.id, choices, models));
      }
    }

    return CreatePopup(
      title: 'Choose ${widget.capability.label.toLowerCase()} model',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s16,
              KrithaSpacing.s14,
              KrithaSpacing.s16,
              KrithaSpacing.s12,
            ),
            child: Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s14),
              decoration: BoxDecoration(
                color: KrithaColors.bgPrimary,
                borderRadius: BorderRadius.circular(KrithaRadius.base),
                border: Border.all(color: KrithaColors.borderSubtle),
              ),
              child: Row(
                children: [
                  KrithaIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: KrithaIcons.base,
                    color: KrithaColors.textMuted,
                  ),
                  SizedBox(width: KrithaSpacing.s10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Search recent, local, and provider models',
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: KrithaIcon(
                        icon: HugeIcons.strokeRoundedX,
                        size: KrithaIcons.sm,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                KrithaSpacing.s16,
                KrithaSpacing.s4,
                KrithaSpacing.s16,
                KrithaSpacing.s24,
              ),
              children: [
                if (activeValue == null || providersValue == null)
                  const CatalogueLoading(label: 'Loading available models…'),
                _section('Recent models', recent),
                if (widget.capability == ModelCapability.text) ...[
                  _section('Local models', local),
                  for (final group in providerGroups) ...[
                    if (group.$3.isNotEmpty) _section(group.$1, group.$3),
                    if (group.$4.isLoading) ...[
                      WorkspaceSectionTitle(group.$1),
                      const CatalogueLoading(label: 'Loading provider models…'),
                    ],
                    if (group.$4.hasError) ...[
                      WorkspaceSectionTitle(group.$1),
                      Padding(
                        padding: EdgeInsets.only(bottom: KrithaSpacing.s12),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: KrithaSpacing.s8,
                          children: [
                            Text(
                              'Could not load models. Check the provider configuration.',
                              style: TextStyle(
                                fontSize: KrithaText.sizeXs,
                                color: KrithaColors.textMuted,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/providers'),
                              child: const Text('Manage provider'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
                if (activeValue != null &&
                    providersValue != null &&
                    recent.isEmpty &&
                    local.isEmpty &&
                    providerGroups.every(
                      (group) =>
                          group.$3.isEmpty &&
                          !group.$4.isLoading &&
                          !group.$4.hasError,
                    ))
                  Column(
                    children: [
                      CatalogueEmpty(
                        title: 'No available models',
                        message: widget.capability == ModelCapability.text
                            ? 'Choose a local model in Models or add an inference provider.'
                            : 'No execution path is available for this capability.',
                      ),
                      if (widget.capability == ModelCapability.text)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: KrithaSpacing.s8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.go('/models');
                              },
                              child: const Text('Explore local models'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.go('/providers');
                              },
                              child: const Text('Configure provider'),
                            ),
                          ],
                        ),
                    ],
                  ),
                if (providerGroups.any((group) => group.$3.isNotEmpty))
                  Padding(
                    padding: EdgeInsets.only(top: KrithaSpacing.s8),
                    child: Text(
                      'Provider models can be assigned, but provider chat routing is not available yet.',
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
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

class _ModelChoiceRow extends ConsumerWidget {
  const _ModelChoiceRow({required this.model});

  final ActiveModelAssignment model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocal = model.sourceId == 'local-litertlm';
    final localModel = ref.watch(modelConfigurationProvider).value?.descriptor;
    final providers = ref.watch(providersControllerProvider).value;
    final providerConfiguration = providers?.configurationFor(model.sourceId);
    final providerModels = isLocal
        ? null
        : ref.watch(providerModelsProvider(model.sourceId)).asData?.value;
    final available = isLocal
        ? localModel?.id == model.modelId
        : providerConfiguration?.configured == true &&
              providerConfiguration?.enabled == true &&
              providerModels?.any((item) => item.id == model.modelId) == true;
    final status = isLocal
        ? available
              ? 'Installed · validated'
              : 'No longer installed'
        : providerConfiguration?.configured != true
        ? 'Provider needs setup'
        : providerConfiguration?.enabled != true
        ? 'Provider disabled'
        : available
        ? 'Listed · chat routing unavailable'
        : 'Not currently listed';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop(available ? model : null);
          if (!available) {
            context.go(isLocal ? '/models' : '/providers');
          }
        },
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s10,
            vertical: KrithaSpacing.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.full),
                ),
                child: KrithaIcon(
                  icon: isLocal
                      ? HugeIcons.strokeRoundedCpu
                      : HugeIcons.strokeRoundedCloud,
                  size: KrithaIcons.base,
                  color: KrithaColors.textMuted,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isLocal ? 'Local LiteRT-LM' : model.sourceId,
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: KrithaSpacing.s8),
              Text(
                status,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: available
                      ? isLocal
                            ? KrithaColors.success
                            : KrithaColors.warning
                      : KrithaColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
