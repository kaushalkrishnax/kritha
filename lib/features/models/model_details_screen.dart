import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/external_links.dart';
import '../../core/theme.dart';
import '../../widgets/back_navigation.dart';
import '../../widgets/context_menu.dart';
import '../chat/widgets/markdown_view.dart';
import 'catalogue/hugging_face_urls.dart';
import 'catalogue/model_metadata.dart';
import 'providers.dart';
import 'widgets/catalogue_widgets.dart';
import 'widgets/workspace_header.dart';

class ModelDetailsScreen extends ConsumerWidget {
  const ModelDetailsScreen({super.key, required this.modelId});

  final String modelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchKrithaPalette(context);
    final details = ref.watch(modelDetailsProvider(modelId));

    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: 'Model Details',
                  onBack: () => goBackOrExit(context),
                  actions: [
                    Builder(
                      builder: (buttonContext) => WorkspaceIconButton(
                        icon: HugeIcons.strokeRoundedEllipsisVertical,
                        tooltip: 'Model options',
                        onTap: () => _openMenu(context, buttonContext),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: details.when(
                    data: (data) => _DetailsBody(details: data),
                    loading: () => const CatalogueLoading(
                      label: 'Loading repository details…',
                    ),
                    error: (error, stackTrace) => SingleChildScrollView(
                      padding: EdgeInsets.all(KrithaSpacing.s16),
                      child: CatalogueErrorView(
                        failure: error is CatalogueFailure
                            ? error
                            : const CatalogueFailure(
                                kind: CatalogueFailureKind.unknown,
                                message: 'The repository details could not be loaded.',
                              ),
                        onRetry: () =>
                            ref.invalidate(modelDetailsProvider(modelId)),
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

  Future<void> _openMenu(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final repositoryUrl = HuggingFaceUrls.repository(modelId);
    final selected = await showKrithaContextMenu(
      context: context,
      anchor: ContextMenuAnchor.fromContext(buttonContext),
      align: ContextMenuAlign.right,
      items: [
        ContextMenuItem(
          id: 'hub',
          label: 'Open in HF Hub',
          icon: HugeIcons.strokeRoundedLink01,
          disabled: modelId.trim().isEmpty,
        ),
        ContextMenuItem(
          id: 'copy',
          label: 'Copy repository URL',
          icon: HugeIcons.strokeRoundedCopy01,
          disabled: modelId.trim().isEmpty,
        ),
      ],
    );
    if (!context.mounted || selected == null) return;
    if (selected == 'hub') {
      await openExternalUrl(context, repositoryUrl);
    } else if (selected == 'copy') {
      await copyTextToClipboard(
        context,
        repositoryUrl,
        message: 'Repository URL copied',
      );
    }
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.details});

  final ModelDetails details;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionTitle('Model Overview'),
          _ModelOverviewCard(details: details),
          SizedBox(height: KrithaSpacing.s20),
          const WorkspaceSectionTitle('Model Setup'),
          _ModelSetupCard(details: details),
          SizedBox(height: KrithaSpacing.s20),
          const WorkspaceSectionTitle('Model Card'),
          _ModelCardSection(details: details),
          SizedBox(height: KrithaSpacing.s20),
          const WorkspaceSectionTitle('Model Files'),
          _ModelFilesCard(details: details),
        ],
      ),
    );
  }
}

class _ModelOverviewCard extends StatelessWidget {
  const _ModelOverviewCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final model = details.model;
    final publisher = details.publisher;
    final publisherName = publisher?.displayName ?? model.publisherLabel;
    final tags = classifyModelMetadata(
      pipelineTag: model.pipelineTag,
      libraryName: model.libraryName,
      tags: model.tags,
    );
    final followers = publisher?.followers ?? 0;
    final following = publisher?.following ?? 0;

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PublisherAvatar(
                url: publisher?.avatarUrl ?? model.avatarUrl,
                label: publisherName,
              ),
              SizedBox(width: KrithaSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            publisherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KrithaText.sizeMd,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (publisher?.isVerified == true) ...[
                          SizedBox(width: KrithaSpacing.s6),
                          KrithaIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                            size: KrithaIcons.sm,
                            color: KrithaColors.accentLightBlue,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: KrithaSpacing.s4),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (model.namespace.isNotEmpty)
                                  TextSpan(
                                    text: '${model.namespace}/',
                                    style: TextStyle(
                                      color: KrithaColors.textMuted,
                                    ),
                                  ),
                                TextSpan(
                                  text: model.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KrithaText.sizeSm,
                              color: KrithaColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: KrithaSpacing.s4),
                        _CopyIconButton(
                          tooltip: 'Copy repository identifier',
                          onTap: () => copyTextToClipboard(
                            context,
                            model.id,
                            message: 'Repository identifier copied',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: KrithaSpacing.s8),
              _LikesPill(likes: model.likes),
            ],
          ),
          if (followers > 0 || following > 0) ...[
            SizedBox(height: KrithaSpacing.s12),
            _FollowerPill(
              publisherName: publisherName,
              followers: followers,
              following: following,
              followingPublisher: publisher?.isFollowing == true,
            ),
          ],
          if (model.gated || model.isPrivate) ...[
            SizedBox(height: KrithaSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KrithaIcon(
                  icon: HugeIcons.strokeRoundedShieldCheck,
                  size: KrithaIcons.sm,
                  color: KrithaColors.warning,
                ),
                SizedBox(width: KrithaSpacing.s8),
                Expanded(
                  child: Text(
                    model.isPrivate
                        ? 'This repository is private. Your Hub token must have access.'
                        : 'This repository is gated. Accept its terms on Hugging Face and use an authorized token.',
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: KrithaSpacing.s14),
          _MetadataBrowser(tags: tags),
        ],
      ),
    );
  }
}

class _PublisherAvatar extends StatelessWidget {
  const _PublisherAvatar({required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final source = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KrithaRadius.full),
      child: Container(
        width: 48,
        height: 48,
        color: KrithaColors.bgTertiary,
        child: source == null
            ? _fallback()
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => Center(
    child: Text(
      label.isEmpty ? '?' : label[0].toUpperCase(),
      style: TextStyle(
        fontSize: KrithaText.sizeMd,
        fontWeight: FontWeight.w700,
        color: KrithaColors.textSecondary,
      ),
    ),
  );
}

class _LikesPill extends StatelessWidget {
  const _LikesPill({required this.likes});

  final int likes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s10,
        vertical: KrithaSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgSecondary,
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedFavourite,
            size: KrithaIcons.sm,
            color: KrithaColors.error,
          ),
          SizedBox(width: KrithaSpacing.s6),
          Text(
            formatCount(likes),
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              fontWeight: FontWeight.w600,
              color: KrithaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowerPill extends StatelessWidget {
  const _FollowerPill({
    required this.publisherName,
    required this.followers,
    required this.following,
    required this.followingPublisher,
  });

  final String publisherName;
  final int followers;
  final int following;
  final bool followingPublisher;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (followers > 0) '${formatCount(followers)} followers',
      if (following > 0) '${formatCount(following)} following',
    ];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s10,
        vertical: KrithaSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgSecondary,
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: KrithaIcons.sm,
            color: KrithaColors.textMuted,
          ),
          SizedBox(width: KrithaSpacing.s6),
          Flexible(
            child: Text(
              '${followingPublisher ? 'Following $publisherName · ' : ''}'
              '${parts.join(' · ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyIconButton extends StatelessWidget {
  const _CopyIconButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KrithaRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: KrithaColors.contextMenuPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: KrithaIcon(
                icon: HugeIcons.strokeRoundedCopy01,
                size: 16,
                color: KrithaColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataBrowser extends StatefulWidget {
  const _MetadataBrowser({required this.tags});

  final List<ModelMetadataTag> tags;

  @override
  State<_MetadataBrowser> createState() => _MetadataBrowserState();
}

class _MetadataBrowserState extends State<_MetadataBrowser> {
  ModelMetadataCategory? _category;

  @override
  Widget build(BuildContext context) {
    final visible = metadataForCategory(widget.tags, _category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KrithaSpacing.s6,
          runSpacing: KrithaSpacing.s6,
          children: [
            _MetadataCategoryChip(
              label: 'Main',
              selected: _category == null,
              onTap: () => setState(() => _category = null),
            ),
            for (final category in ModelMetadataCategory.values)
              _MetadataCategoryChip(
                label: category.label,
                icon: category.icon,
                selected: _category == category,
                onTap: () => setState(() => _category = category),
              ),
          ],
        ),
        SizedBox(height: KrithaSpacing.s12),
        if (widget.tags.isEmpty)
          Text(
            'No metadata tags were returned for this repository.',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textMuted,
            ),
          )
        else if (visible.isEmpty)
          Text(
            'No ${_category!.label.toLowerCase()} metadata was returned.',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textMuted,
            ),
          )
        else
          Wrap(
            spacing: KrithaSpacing.s6,
            runSpacing: KrithaSpacing.s6,
            children: [for (final tag in visible) _MetadataTagChip(tag: tag)],
          ),
      ],
    );
  }
}

class _MetadataCategoryChip extends StatelessWidget {
  const _MetadataCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final List<List<dynamic>>? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? KrithaColors.textOnAccent
        : KrithaColors.textSecondary;
    return Material(
      color: selected ? KrithaColors.accentBlue : KrithaColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        side: BorderSide(
          color: selected
              ? KrithaColors.borderAccent
              : KrithaColors.borderSubtle,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: KrithaColors.contextMenuPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s10,
            vertical: KrithaSpacing.s6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                KrithaIcon(icon: icon!, size: 14, color: foreground),
                SizedBox(width: KrithaSpacing.s6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataTagChip extends StatelessWidget {
  const _MetadataTagChip({required this.tag});

  final ModelMetadataTag tag;

  @override
  Widget build(BuildContext context) {
    final isOther = tag.category == ModelMetadataCategory.other;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s10,
        vertical: KrithaSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgSecondary,
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOther) ...[
            KrithaIcon(
              icon: tag.category.icon,
              size: 14,
              color: KrithaColors.textMuted,
            ),
            SizedBox(width: KrithaSpacing.s6),
          ],
          Text(
            tag.label,
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSetupCard extends StatelessWidget {
  const _ModelSetupCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final facts = _facts();
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review the declared format and runtime details before setting this model up on your device.',
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: KrithaSpacing.s14),
          if (facts.isEmpty)
            Text(
              'No technical metadata was declared for this repository.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 4 : 2;
                final width =
                    (constraints.maxWidth - KrithaSpacing.s12 * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: KrithaSpacing.s12,
                  runSpacing: KrithaSpacing.s14,
                  children: [
                    for (final fact in facts)
                      SizedBox(
                        width: width,
                        child: _SetupFactTile(fact: fact),
                      ),
                  ],
                );
              },
            ),
          SizedBox(height: KrithaSpacing.s16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => context.push('/models/active'),
              style: FilledButton.styleFrom(
                backgroundColor: KrithaColors.accentBlue,
                foregroundColor: KrithaColors.textOnAccent,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                ),
              ),
              icon: KrithaIcon(
                icon: HugeIcons.strokeRoundedSettings02,
                size: 16,
                color: KrithaColors.textOnAccent,
              ),
              label: const Text('Setup Now'),
            ),
          ),
        ],
      ),
    );
  }

  List<_SetupFact> _facts() {
    final model = details.model;
    final facts = <_SetupFact>[];
    final architecture = details.architecture;
    if (architecture != null) {
      facts.add(_SetupFact('Architecture', architecture));
    }
    final parameters = details.parameterCount;
    if (parameters != null && parameters > 0) {
      facts.add(_SetupFact('Parameters', formatParameterCount(parameters)));
    }
    if (details.weightPrecisions.isNotEmpty) {
      facts.add(_SetupFact('Weights', details.weightPrecisions.join(', ')));
    }
    if (details.quantizations.isNotEmpty) {
      facts.add(_SetupFact('Quantization', details.quantizations.join(', ')));
    }
    if (details.formats.isNotEmpty) {
      facts.add(_SetupFact('Format', details.formats.join(', ')));
    }
    final library = details.libraryName;
    if (library != null) {
      facts.add(_SetupFact('Library', library));
    }
    final task = model.taskLabel;
    if (task != null) {
      facts.add(_SetupFact('Task', task));
    }
    final contextLength = details.contextLength;
    if (contextLength != null && contextLength > 0) {
      facts.add(_SetupFact('Context window', _formatInteger(contextLength)));
    }
    return facts;
  }
}

class _SetupFact {
  const _SetupFact(this.label, this.value);

  final String label;
  final String value;
}

class _SetupFactTile extends StatelessWidget {
  const _SetupFactTile({required this.fact});

  final _SetupFact fact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fact.label,
          style: TextStyle(
            fontSize: KrithaText.size2xs,
            color: KrithaColors.textMuted,
          ),
        ),
        SizedBox(height: KrithaSpacing.s2),
        Text(
          fact.value,
          style: TextStyle(
            fontSize: KrithaText.sizeXs,
            fontWeight: FontWeight.w600,
            color: KrithaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ModelCardSection extends StatefulWidget {
  const _ModelCardSection({required this.details});

  final ModelDetails details;

  @override
  State<_ModelCardSection> createState() => _ModelCardSectionState();
}

class _ModelCardSectionState extends State<_ModelCardSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final readme = widget.details.readme?.trim();
    if (readme == null || readme.isEmpty) {
      return const WorkspaceCard(
        child: _EmptySection(
          icon: HugeIcons.strokeRoundedFile01,
          title: 'No model card',
          message: 'This repository does not provide a model card.',
        ),
      );
    }
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: KrithaMotion.fast,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _expanded ? double.infinity : 360,
              ),
              child: ClipRect(
                child: MarkdownView(
                  data: readme,
                  onLinkTap: (url) => _openLink(context, url),
                ),
              ),
            ),
          ),
          SizedBox(height: KrithaSpacing.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: KrithaColors.accentLightBlue,
                padding: EdgeInsets.symmetric(
                  horizontal: KrithaSpacing.s8,
                  vertical: KrithaSpacing.s6,
                ),
              ),
              icon: KrithaIcon(
                icon: _expanded
                    ? HugeIcons.strokeRoundedArrowUp01
                    : HugeIcons.strokeRoundedArrowDown01,
                size: 16,
              ),
              label: Text(_expanded ? 'View less' : 'View more'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final raw = url.trim();
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      await openExternalUrl(context, parsed.toString());
      return;
    }
    if (raw.startsWith('#')) return;
    final base = Uri.parse('${widget.details.repositoryUrl}/');
    final resolved = base.resolve(raw);
    await openExternalUrl(context, resolved.toString());
  }
}

class _ModelFilesCard extends StatelessWidget {
  const _ModelFilesCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final entries = [...details.files]
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
    final size = details.repositorySize;

    return WorkspaceCard(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s12,
              KrithaSpacing.s8,
              KrithaSpacing.s12,
              KrithaSpacing.s10,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: KrithaSpacing.s10,
                    vertical: KrithaSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: KrithaColors.bgSecondary,
                    borderRadius: BorderRadius.circular(KrithaRadius.full),
                    border: Border.all(color: KrithaColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KrithaIcon(
                        icon: HugeIcons.strokeRoundedGitBranch,
                        size: 14,
                        color: KrithaColors.textMuted,
                      ),
                      SizedBox(width: KrithaSpacing.s6),
                      Text(
                        details.branch,
                        style: TextStyle(
                          fontSize: KrithaText.sizeXs,
                          fontWeight: FontWeight.w600,
                          color: KrithaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: KrithaSpacing.s10),
                Expanded(
                  child: Text(
                    details.model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (size > 0) ...[
                  SizedBox(width: KrithaSpacing.s8),
                  Text(
                    formatBytes(size),
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s12,
              0,
              KrithaSpacing.s12,
              KrithaSpacing.s10,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KrithaSpacing.s8,
              runSpacing: KrithaSpacing.s4,
              children: [
                Text(
                  'Latest commit',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textMuted,
                  ),
                ),
                if (details.commitUrl != null)
                  _InlineLink(
                    label: _shortSha(details.commitSha!),
                    onTap: () => openExternalUrl(context, details.commitUrl!),
                  )
                else
                  Text(
                    'Not available',
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          WorkspaceDivider(),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s16),
              child: _EmptySection(
                icon: HugeIcons.strokeRoundedFolderOpen,
                title: 'No files',
                message: 'No files were listed for this repository.',
                compact: true,
              ),
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) WorkspaceDivider(),
              _RepositoryEntryRow(details: details, file: entries[index]),
            ],
        ],
      ),
    );
  }

  static String _shortSha(String sha) =>
      sha.length <= 7 ? sha : sha.substring(0, 7);
}

class _RepositoryEntryRow extends StatelessWidget {
  const _RepositoryEntryRow({required this.details, required this.file});

  final ModelDetails details;
  final ModelFile file;

  @override
  Widget build(BuildContext context) {
    final url = file.isDirectory
        ? details.directoryUrl(file)
        : details.fileUrl(file);
    final labelStyle = TextStyle(
      fontSize: KrithaText.sizeXs,
      color: KrithaColors.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: KrithaColors.borderStrong,
    );
    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s12,
        vertical: KrithaSpacing.s10,
      ),
      child: Row(
        children: [
          KrithaIcon(
            icon: file.isDirectory
                ? HugeIcons.strokeRoundedFolder01
                : HugeIcons.strokeRoundedFile01,
            size: KrithaIcons.base,
            color: file.isDirectory
                ? KrithaColors.accentLightBlue
                : KrithaColors.textMuted,
          ),
          SizedBox(width: KrithaSpacing.s10),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (file.isLfs) ...[
            SizedBox(width: KrithaSpacing.s8),
            const CapabilityChip(label: 'LFS'),
          ],
          if (file.readableSize.isNotEmpty) ...[
            SizedBox(width: KrithaSpacing.s10),
            Text(
              file.readableSize,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
          ],
          SizedBox(width: KrithaSpacing.s8),
          KrithaIcon(
            icon: HugeIcons.strokeRoundedArrowUpRight01,
            size: 14,
            color: KrithaColors.textDimmed,
          ),
        ],
      ),
    );
    if (url == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExternalUrl(context, url),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: KrithaColors.contextMenuPressed,
        child: row,
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(KrithaRadius.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: KrithaColors.contextMenuPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s4,
            vertical: KrithaSpacing.s2,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              fontWeight: FontWeight.w600,
              color: KrithaColors.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: KrithaColors.borderStrong,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact ? EdgeInsets.zero : EdgeInsets.all(KrithaSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KrithaIcon(
            icon: icon,
            size: KrithaIcons.lg,
            color: KrithaColors.textMuted,
          ),
          SizedBox(width: KrithaSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: KrithaText.sizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: KrithaSpacing.s2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textMuted,
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

String _formatInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}
