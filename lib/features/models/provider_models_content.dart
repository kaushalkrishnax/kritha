import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../models/model_record.dart';
import '../../widgets/skeleton.dart';
import '../intelligence/providers/providers.dart';
import '../providers/providers_controller.dart';
import 'active/active_models.dart';
import 'catalogue/catalogue_providers.dart';
import 'domain/model_tags.dart';
import 'selection/model_display.dart';
import 'setup/model_artifact_storage.dart';
import 'setup/model_setup_wizard.dart';
import 'widgets/workspace_header.dart';

class ProviderModelsContent extends ConsumerStatefulWidget {
  const ProviderModelsContent({super.key});

  @override
  ConsumerState<ProviderModelsContent> createState() =>
      _ProviderModelsContentState();
}

class _ProviderModelsContentState extends ConsumerState<ProviderModelsContent> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(providersControllerProvider);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.s16,
            KrithaSpacing.s4,
            KrithaSpacing.s16,
            KrithaSpacing.s12,
          ),
          child: _ProviderSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
          ),
        ),
        Expanded(
          child: providers.when(
            data: (state) => _ProviderModelsBody(state: state, query: _query),
            loading: () => const _ProviderModelsSkeleton(),
            error: (error, stackTrace) => Padding(
              padding: EdgeInsets.all(KrithaSpacing.s16),
              child: _ProviderModelsError(
                message:
                    'Provider settings could not be loaded from local storage.',
                onRetry: () => ref.invalidate(providersControllerProvider),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderSearchField extends StatelessWidget {
  const _ProviderSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(width: KrithaSpacing.s14),
          KrithaIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: KrithaIcons.base,
            color: KrithaColors.textMuted,
          ),
          SizedBox(width: KrithaSpacing.s10),
          Expanded(
            child: TextField(
              key: const ValueKey('provider-models-search'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search provider models',
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: KrithaIcon(
                icon: HugeIcons.strokeRoundedX,
                size: KrithaIcons.sm,
                color: KrithaColors.textMuted,
              ),
            ),
          SizedBox(width: KrithaSpacing.s4),
        ],
      ),
    );
  }
}

class _ProviderModelsBody extends ConsumerWidget {
  const _ProviderModelsBody({required this.state, required this.query});

  final ProvidersState state;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelsProvider).value;
    final totalModels = active?.models.length ?? 0;

    if (totalModels == 0) {
      return Padding(
        padding: EdgeInsets.all(KrithaSpacing.s16),
        child: WorkspaceCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s24),
              child: Text(
                'No provider models available.',
                style: TextStyle(
                  fontSize: KrithaText.sizeSm,
                  color: KrithaColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final remoteProviders = [
      for (final configuration in state.configurations)
        if (configuration.id != localLitertlmProviderId) configuration,
    ];

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
          _LocalProviderModelGroup(query: query),
          for (final configuration in remoteProviders) ...[
            _ProviderModelGroup(configuration: configuration, query: query),
          ],
        ],
      ),
    );
  }
}

class _LocalProviderModelGroup extends ConsumerWidget {
  const _LocalProviderModelGroup({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelsProvider);

    return active.maybeWhen(
      data: (state) {
        final normalized = query.trim().toLowerCase();
        final entries = [
          for (final model in state.models.values)
            if (model.providerId == localLitertlmProviderId)
              (
                model: model,
                tags: state.tags[model.id],
                files: state.artifactFiles[model.id] ??
                    const <ResolvedModelArtifactFile>[],
              ),
        ]..sort(
            (left, right) => left.model.displayName
                .toLowerCase()
                .compareTo(right.model.displayName.toLowerCase()),
          );
        final filtered = normalized.isEmpty
            ? entries
            : [
                for (final entry in entries)
                  if (entry.model.displayName.toLowerCase().contains(
                        normalized,
                      ) ||
                      entry.model.externalModelId.toLowerCase().contains(
                        normalized,
                      ))
                    entry,
              ];
        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceSectionTitle('Local LiteRT-LM'),
            WorkspaceCard(
              child: Column(
                children: [
                  for (var index = 0; index < filtered.length; index++) ...[
                    _LocalModelRow(
                      model: filtered[index].model,
                      tags: filtered[index].tags,
                      files: filtered[index].files,
                    ),
                    if (index != filtered.length - 1)
                      Divider(height: 1, color: KrithaColors.borderFaint),
                  ],
                ],
              ),
            ),
            SizedBox(height: KrithaSpacing.s16),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LocalModelRow extends ConsumerWidget {
  const _LocalModelRow({
    required this.model,
    required this.tags,
    required this.files,
  });

  final ModelRecord model;
  final ModelTags? tags;
  final List<ResolvedModelArtifactFile> files;

  Future<void> _openManageSetup(BuildContext context, WidgetRef ref) async {
    final repositoryId =
        model.metadata['repositoryId'] as String? ?? model.externalModelId;
    try {
      final details = await ref
          .read(modelCatalogueProvider)
          .details(repositoryId);
      if (!context.mounted) return;
      await showModelSetupWizard(
        context,
        details: details,
        managedModel: model,
      );
      ref.invalidate(activeModelsProvider);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open model setup. Check the connection and retry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final present = files.where((file) => file.exists).length;
    final (label, color) = _status(present);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              icon: HugeIcons.strokeRoundedCpu,
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
                  displayModelName(model.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.sizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  files.isEmpty
                      ? 'No artifacts saved yet'
                      : '$present of ${files.length} file'
                        '${files.length == 1 ? '' : 's'} downloaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          _LocalStatusChip(label: label, color: color),
          SizedBox(width: KrithaSpacing.s4),
          Tooltip(
            message: 'Manage Setup',
            child: IconButton(
              key: ValueKey('manage-setup-${model.id}'),
              onPressed: () => _openManageSetup(context, ref),
              style: IconButton.styleFrom(
                foregroundColor: KrithaColors.textSecondary,
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: KrithaIcon(
                icon: HugeIcons.strokeRoundedBlockGame,
                size: 16,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _status(int present) {
    if (present == 0) return ('Not downloaded', KrithaColors.textMuted);
    if (present < files.length) {
      return ('Partially downloaded', KrithaColors.warning);
    }
    if (tags?.isExecutable ?? false) {
      return ('Ready', KrithaColors.success);
    }
    return ('Downloaded', KrithaColors.warning);
  }
}

class _LocalStatusChip extends StatelessWidget {
  const _LocalStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s8,
        vertical: KrithaSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: KrithaText.size2xs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProviderModelGroup extends ConsumerWidget {
  const _ProviderModelGroup({required this.configuration, required this.query});

  final ProviderConfiguration configuration;
  final String query;

  String get _providerName => providerDisplayName(configuration.alias);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelsProvider);
    return active.maybeWhen(
      data: (activeState) {
        final normalized = query.trim().toLowerCase();
        final entries = [
          for (final model in activeState.models.values)
            if (model.providerId == configuration.id) model,
        ]..sort(
            (left, right) => left.displayName
                .toLowerCase()
                .compareTo(right.displayName.toLowerCase()),
          );
        final filtered = normalized.isEmpty
            ? entries
            : [
                for (final model in entries)
                  if (model.displayName.toLowerCase().contains(normalized) ||
                      model.externalModelId.toLowerCase().contains(normalized))
                    model,
              ];
        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkspaceSectionTitle(_providerName),
            WorkspaceCard(
              child: Column(
                children: [
                  for (var index = 0; index < filtered.length; index++) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: KrithaSpacing.s8,
                      ),
                      child: Row(
                        children: [
                          KrithaIcon(
                            icon: HugeIcons.strokeRoundedCpu,
                            size: KrithaIcons.sm,
                            color: KrithaColors.textMuted,
                          ),
                          SizedBox(width: KrithaSpacing.s8),
                          Expanded(
                            child: Text(
                              displayModelName(filtered[index].displayName),
                              style: TextStyle(
                                fontSize: KrithaText.sizeSm,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index != filtered.length - 1)
                      Divider(height: 1, color: KrithaColors.borderFaint),
                  ],
                ],
              ),
            ),
            SizedBox(height: KrithaSpacing.s16),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ProviderModelsError extends StatelessWidget {
  const _ProviderModelsError({required this.message, required this.onRetry});

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

class _ProviderModelsSkeleton extends StatelessWidget {
  const _ProviderModelsSkeleton();

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < 3; index++) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 16),
                SizedBox(height: KrithaSpacing.s8),
                WorkspaceCard(child: const _ProviderGroupSkeleton()),
              ],
            ),
            SizedBox(height: KrithaSpacing.s16),
          ],
        ],
      ),
    );
  }
}

class _ProviderGroupSkeleton extends StatelessWidget {
  const _ProviderGroupSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s10),
            child: Row(
              children: [
                SkeletonBox(
                  width: 36,
                  height: 36,
                  radius: BorderRadius.circular(KrithaRadius.full),
                ),
                SizedBox(width: KrithaSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 12),
                      SizedBox(height: KrithaSpacing.s6),
                      SkeletonBox(width: 100, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != 2) Divider(height: 1, color: KrithaColors.borderFaint),
        ],
      ],
    );
  }
}
