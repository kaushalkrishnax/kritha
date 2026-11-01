import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/skeleton.dart';
import '../providers/provider_connection_tester.dart';
import '../providers/providers_controller.dart';
import 'catalogue/catalogue_model.dart';
import 'models_workspace_scaffold.dart';
import 'selection/model_display.dart';
import 'widgets/catalogue_widgets.dart';
import 'widgets/workspace_header.dart';

class ProviderModelsScreen extends ConsumerStatefulWidget {
  const ProviderModelsScreen({super.key});

  @override
  ConsumerState<ProviderModelsScreen> createState() =>
      _ProviderModelsScreenState();
}

class _ProviderModelsScreenState extends ConsumerState<ProviderModelsScreen> {
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

    return ModelsWorkspaceScaffold(
      destination: ModelsWorkspaceDestination.providers,
      child: Column(
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
                  message: 'Provider settings could not be loaded from local storage.',
                  onRetry: () => ref.invalidate(providersControllerProvider),
                ),
              ),
            ),
          ),
        ],
      ),
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

class _ProviderModelsBody extends StatelessWidget {
  const _ProviderModelsBody({required this.state, required this.query});

  final ProvidersState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final configured = state.configurations.values
        .where(
          (configuration) => !configuration.isLocal && configuration.configured,
        )
        .toList();

    if (configured.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          KrithaSpacing.s16,
          KrithaSpacing.s4,
          KrithaSpacing.s16,
          KrithaSpacing.s32,
        ),
        child: Column(
          children: [
            CatalogueEmpty(
              title: 'No provider models',
              message:
                  'Connect a provider to list the models it makes available.',
            ),
            OutlinedButton(
              onPressed: () => context.push('/providers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KrithaColors.textSecondary,
                side: BorderSide(color: KrithaColors.borderStrong),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                ),
              ),
              child: const Text('Manage providers'),
            ),
          ],
        ),
      );
    }

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
            _ProviderModelGroup(configuration: configuration, query: query),
            SizedBox(height: KrithaSpacing.s16),
          ],
        ],
      ),
    );
  }
}

class _ProviderModelGroup extends ConsumerWidget {
  const _ProviderModelGroup({required this.configuration, required this.query});

  final ProviderConfiguration configuration;
  final String query;

  String get _providerName => configuration.isCustom
      ? configuration.alias
      : configuration.definition.name;

  bool _matchesProvider(String value) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return value.toLowerCase().contains(normalized);
  }

  bool _matchesModel(ProviderModelInfo model, bool providerMatches) {
    if (providerMatches) return true;
    final normalized = query.trim().toLowerCase();
    return model.name.toLowerCase().contains(normalized) ||
        model.id.toLowerCase().contains(normalized);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(providerModelsProvider(configuration.providerId));
    final providerMatches = _matchesProvider(_providerName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionTitle(_providerName),
        WorkspaceCard(
          child: models.when(
            data: (items) {
              final filtered = items
                  .where((model) => _matchesModel(model, providerMatches))
                  .toList();
              if (items.isEmpty) {
                return _GroupMessage(
                  message: 'This provider returned no models.',
                );
              }
              if (filtered.isEmpty) {
                return _GroupMessage(message: 'No models match this search.');
              }
              return Column(
                children: [
                  for (var index = 0; index < filtered.length; index++) ...[
                    _ProviderModelRow(model: filtered[index]),
                    if (index != filtered.length - 1)
                      Divider(height: 1, color: KrithaColors.borderFaint),
                  ],
                ],
              );
            },
            loading: () => const _ProviderGroupSkeleton(),
            error: (error, stackTrace) => _GroupError(
              providerName: _providerName,
              onRetry: () => ref.invalidate(
                providerModelsProvider(configuration.providerId),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderModelRow extends StatelessWidget {
  const _ProviderModelRow({required this.model});

  final ProviderModelInfo model;

  @override
  Widget build(BuildContext context) {
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
              icon: HugeIcons.strokeRoundedCloud,
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
                  displayModelName(model.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.sizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  model.id,
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
          if (model.parameterCount != null) ...[
            SizedBox(width: KrithaSpacing.s8),
            Text(
              formatParameterCount(model.parameterCount!),
              style: TextStyle(
                fontSize: KrithaText.size2xs,
                fontWeight: FontWeight.w600,
                color: KrithaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupMessage extends StatelessWidget {
  const _GroupMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s8),
      child: Text(
        message,
        style: TextStyle(
          fontSize: KrithaText.sizeXs,
          color: KrithaColors.textMuted,
        ),
      ),
    );
  }
}

class _GroupError extends StatelessWidget {
  const _GroupError({required this.providerName, required this.onRetry});

  final String providerName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Could not load models from $providerName.',
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(
              onPressed: () => context.push('/providers'),
              child: const Text('Manage providers'),
            ),
          ],
        ),
      ],
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
