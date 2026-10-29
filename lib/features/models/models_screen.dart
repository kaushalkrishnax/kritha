import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/context_menu.dart';
import '../../widgets/create_popup.dart';
import 'providers.dart';
import 'widgets/catalogue_widgets.dart';
import 'widgets/hugging_face_token_dialog.dart';
import 'widgets/workspace_header.dart';
import '../intelligence/model_configuration.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  CatalogueController get _catalogue => ref.read(catalogueProvider.notifier);

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = value.trim();
      final current = ref.read(catalogueProvider);
      if (query.isEmpty &&
          current.capability == null &&
          current.sort == CatalogueSort.downloads) {
        _catalogue.reset();
        return;
      }
      _catalogue.search(query: query);
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    final current = ref.read(catalogueProvider);
    if (current.capability == null && current.sort == CatalogueSort.downloads) {
      _catalogue.reset();
    } else {
      _catalogue.search(query: '');
    }
  }

  void _selectCapability(ModelCapability? capability) {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    final sort = ref.read(catalogueProvider).sort;
    if (capability == null &&
        query.isEmpty &&
        sort == CatalogueSort.downloads) {
      _catalogue.reset();
      return;
    }
    _catalogue.search(
      query: query,
      capability: capability,
      clearCapability: capability == null,
    );
  }

  void _selectSort(CatalogueSort sort) {
    _debounce?.cancel();
    _catalogue.search(query: _searchController.text.trim(), sort: sort);
  }

  Future<void> _refresh(CatalogueState catalogue) async {
    if (catalogue.isIdle) {
      ref.invalidate(featuredCatalogueProvider);
      try {
        await ref.read(featuredCatalogueProvider.future);
      } on Object {
        // The error state is rendered by the section.
      }
      return;
    }
    await _catalogue.retry();
  }

  Future<void> _openCatalogueMenu(BuildContext buttonContext) async {
    final selected = await showKrithaContextMenu(
      context: context,
      anchor: ContextMenuAnchor.fromContext(buttonContext),
      items: [
        ContextMenuItem(
          id: 'token',
          label: 'Hugging Face token',
          icon: HugeIcons.strokeRoundedLockKeyhole,
        ),
        ContextMenuItem(
          id: 'custom',
          label: 'Custom catalogue (Pro)',
          icon: HugeIcons.strokeRoundedSparkles,
          disabled: true,
        ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected == 'token') {
      await showHuggingFaceTokenDialog(context);
    } else if (selected == 'custom') {
      await context.push('/models/custom');
    }
  }

  void _openModel(CatalogueModel model) {
    context.push('/models/details?id=${Uri.encodeComponent(model.id)}');
  }

  @override
  Widget build(BuildContext context) {
    watchKrithaPalette(context);
    final catalogue = ref.watch(catalogueProvider);
    final featured = ref.watch(featuredCatalogueProvider);

    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: 'Models',
                  onBack: () => context.go('/chat'),
                  actions: [
                    WorkspaceIconButton(
                      icon: HugeIcons.strokeRoundedMenuTwoLine,
                      tooltip: 'Active models',
                      onTap: () => context.push('/models/active'),
                    ),
                    SizedBox(width: KrithaSpacing.s8),
                    Builder(
                      builder: (buttonContext) => WorkspaceIconButton(
                        icon: HugeIcons.strokeRoundedEllipsisVertical,
                        tooltip: 'Catalogue options',
                        onTap: () => _openCatalogueMenu(buttonContext),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: KrithaColors.accentLightBlue,
                    backgroundColor: KrithaColors.bgSurface,
                    onRefresh: () => _refresh(catalogue),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              KrithaSpacing.s16,
                              KrithaSpacing.s4,
                              KrithaSpacing.s16,
                              KrithaSpacing.s12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SearchRow(
                                  controller: _searchController,
                                  onChanged: _onQueryChanged,
                                  onClear: _clearQuery,
                                ),
                                SizedBox(height: KrithaSpacing.s12),
                                CapabilityFilterChips(
                                  selected: catalogue.capability,
                                  onSelected: _selectCapability,
                                ),
                                SizedBox(height: KrithaSpacing.s8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _SortButton(
                                    sort: catalogue.sort,
                                    onSelected: _selectSort,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              KrithaSpacing.s16,
                              0,
                              KrithaSpacing.s16,
                              KrithaSpacing.s12,
                            ),
                            child: const _LocalModelSection(),
                          ),
                        ),
                        ..._contentSlivers(catalogue, featured),
                        SliverToBoxAdapter(
                          child: SizedBox(height: KrithaSpacing.s32),
                        ),
                      ],
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

  List<Widget> _contentSlivers(
    CatalogueState catalogue,
    AsyncValue<FeaturedCatalogueState> featured,
  ) {
    if (catalogue.loading) {
      return const [SliverToBoxAdapter(child: CatalogueLoading())];
    }
    if (catalogue.failure != null) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s16),
          sliver: SliverToBoxAdapter(
            child: CatalogueErrorView(
              failure: catalogue.failure!,
              onRetry: _catalogue.retry,
            ),
          ),
        ),
      ];
    }
    if (!catalogue.isIdle && catalogue.hasLoaded) {
      return _resultSlivers(catalogue);
    }
    return _featuredSlivers(featured);
  }

  List<Widget> _resultSlivers(CatalogueState catalogue) {
    if (catalogue.models.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              CatalogueEmpty(
                title: catalogue.hasMore
                    ? 'More results available'
                    : 'No models found',
                message: catalogue.hasMore
                    ? 'Continue to load matching repositories.'
                    : 'Try a different search term or capability.',
              ),
              if (catalogue.hasMore)
                OutlinedButton(
                  onPressed: catalogue.loadingMore ? null : _catalogue.loadMore,
                  child: Text(catalogue.loadingMore ? 'Loading…' : 'Load more'),
                ),
            ],
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s16),
        sliver: SliverToBoxAdapter(
          child: _ModelGrid(models: catalogue.models, onTap: _openModel),
        ),
      ),
      if (catalogue.loadMoreFailure != null)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.s16,
            KrithaSpacing.s12,
            KrithaSpacing.s16,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: CatalogueErrorView(
              failure: catalogue.loadMoreFailure!,
              onRetry: _catalogue.loadMore,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.s16,
            KrithaSpacing.s16,
            KrithaSpacing.s16,
            0,
          ),
          child: Center(
            child: catalogue.loadingMore
                ? const CatalogueLoading(label: 'Loading more models…')
                : catalogue.hasMore
                ? OutlinedButton(
                    onPressed: _catalogue.loadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KrithaColors.textSecondary,
                      side: BorderSide(color: KrithaColors.borderStrong),
                      minimumSize: const Size(160, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KrithaRadius.base),
                      ),
                    ),
                    child: const Text('Load more'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  List<Widget> _featuredSlivers(AsyncValue<FeaturedCatalogueState> featured) {
    return [
      SliverToBoxAdapter(
        child: featured.when(
          data: (state) {
            if (state.popular.isEmpty && state.recommended.isEmpty) {
              return const CatalogueEmpty(
                title: 'No models available',
                message: 'The Hub returned no repositories right now.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeaturedSection(
                  title: 'Popular on the Hub',
                  caption: 'Most downloaded repositories',
                  models: state.popular,
                  onTap: _openModel,
                ),
                SizedBox(height: KrithaSpacing.s20),
                _FeaturedSection(
                  title: 'Recommended',
                  caption: 'Most liked repositories',
                  models: state.recommended,
                  onTap: _openModel,
                ),
              ],
            );
          },
          loading: () => const CatalogueLoading(),
          error: (error, stackTrace) => Padding(
            padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s16),
            child: CatalogueErrorView(
              failure: error is CatalogueFailure
                  ? error
                  : const CatalogueFailure(
                      kind: CatalogueFailureKind.unknown,
                      message: 'The featured models could not be loaded.',
                    ),
              onRetry: () => ref.invalidate(featuredCatalogueProvider),
            ),
          ),
        ),
      ),
    ];
  }
}

class _LocalModelSection extends ConsumerWidget {
  const _LocalModelSection();

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['litertlm'],
      );
      if (files.isEmpty || files.first.path == null) return;
      await ref
          .read(modelConfigurationProvider.notifier)
          .setPath(files.first.path!);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The local model could not be selected.')),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(modelConfigurationProvider.notifier).clear();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The local model could not be removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configuration = ref.watch(modelConfigurationProvider);
    return configuration.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stackTrace) => WorkspaceCard(
        padding: EdgeInsets.all(KrithaSpacing.s12),
        child: const Text('Local model configuration is unavailable.'),
      ),
      data: (value) => WorkspaceCard(
        padding: EdgeInsets.symmetric(
          horizontal: KrithaSpacing.s12,
          vertical: KrithaSpacing.s10,
        ),
        child: Row(
          children: [
            KrithaIcon(
              icon: HugeIcons.strokeRoundedCpu,
              size: KrithaIcons.md,
              color: KrithaColors.textMuted,
            ),
            SizedBox(width: KrithaSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.fileName ?? 'No local model selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value.isReady ? 'LiteRT-LM · validated' : value.statusLabel,
                    style: TextStyle(
                      fontSize: KrithaText.size2xs,
                      color: value.isReady
                          ? KrithaColors.success
                          : KrithaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _choose(context, ref),
              child: Text(value.isReady ? 'Change' : 'Choose file'),
            ),
            if (value.path != null)
              IconButton(
                tooltip: 'Remove local model',
                onPressed: () => _remove(context, ref),
                icon: KrithaIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  size: KrithaIcons.sm,
                  color: KrithaColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
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
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search Hugging Face models',
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSelected});

  final CatalogueSort sort;
  final ValueChanged<CatalogueSort> onSelected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Sort models',
    child: InkWell(
      borderRadius: BorderRadius.circular(KrithaRadius.base),
      onTap: () async {
        final selected = await createPopup<CatalogueSort>(
          context: context,
          builder: (_) => CreatePopup(
            title: 'Sort models',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in CatalogueSort.values)
                  ListTile(
                    title: Text(item.label),
                    trailing: item == sort
                        ? KrithaIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            size: KrithaIcons.sm,
                            color: KrithaColors.textSecondary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(item),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) onSelected(selected);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KrithaIcon(
              icon: HugeIcons.strokeRoundedArrowDown02,
              size: KrithaIcons.sm,
              color: KrithaColors.textMuted,
            ),
            SizedBox(width: KrithaSpacing.s6),
            Text(
              'Sort: ${sort.label}',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModelGrid extends StatelessWidget {
  const _ModelGrid({required this.models, required this.onTap});

  final List<CatalogueModel> models;
  final ValueChanged<CatalogueModel> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final model in models) ...[
          ModelCard(model: model, onTap: () => onTap(model)),
          SizedBox(height: KrithaSpacing.s8),
        ],
      ],
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({
    required this.title,
    required this.caption,
    required this.models,
    required this.onTap,
  });

  final String title;
  final String caption;
  final List<CatalogueModel> models;
  final ValueChanged<CatalogueModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: KrithaSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: KrithaSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkspaceSectionTitle(title),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: KrithaSpacing.s10),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: KrithaSpacing.s16),
              itemCount: models.length,
              separatorBuilder: (_, _) => SizedBox(width: KrithaSpacing.s12),
              itemBuilder: (context, index) {
                final model = models[index];
                return ModelCard(
                  model: model,
                  width: 300,
                  onTap: () => onTap(model),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
