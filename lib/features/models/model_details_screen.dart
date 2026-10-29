import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../chat/widgets/markdown_view.dart';
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
    final slash = modelId.indexOf('/');
    final name = slash < 0 ? modelId : modelId.substring(slash + 1);

    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: name,
                  onBack: () => context.go('/models'),
                  actions: [
                    WorkspaceIconButton(
                      icon: HugeIcons.strokeRoundedFilterHorizontal,
                      tooltip: 'Active models',
                      onTap: () => context.push('/models/active'),
                    ),
                  ],
                ),
                Expanded(
                  child: details.when(
                    data: (data) =>
                        _DetailsBody(modelId: modelId, details: data),
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
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.modelId, required this.details});

  final String modelId;
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
          _OverviewCard(details: details),
          SizedBox(height: KrithaSpacing.s16),
          _CompatibilityCard(details: details),
          SizedBox(height: KrithaSpacing.s16),
          _RequirementsCard(details: details),
          SizedBox(height: KrithaSpacing.s20),
          WorkspaceSectionTitle('Files'),
          _FilesCard(files: details.files),
          SizedBox(height: KrithaSpacing.s20),
          WorkspaceSectionTitle('Model card'),
          WorkspaceCard(
            child: details.readme == null
                ? Text(
                    'No README was found in this repository.',
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      color: KrithaColors.textMuted,
                    ),
                  )
                : MarkdownView(data: _readme(details.readme!)),
          ),
          SizedBox(height: KrithaSpacing.s20),
          _Actions(modelId: modelId, hasLitertLmFile: details.hasLitertLmFile),
        ],
      ),
    );
  }

  static String _readme(String value) {
    const limit = 60000;
    if (value.length <= limit) return value;
    return '${value.substring(0, limit)}\n\n---\n\n'
        '_The model card was truncated for display._';
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final model = details.model;
    final capabilities = model.capabilities
        .where(ModelCapability.discoverable.contains)
        .toList();
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                  border: Border.all(color: KrithaColors.borderSubtle),
                ),
                child: KrithaIcon(
                  icon: capabilities.isEmpty
                      ? HugeIcons.strokeRoundedCpu
                      : capabilityIcon(capabilities.first),
                  size: KrithaIcons.lg,
                  color: KrithaColors.accentLightBlue,
                ),
              ),
              SizedBox(width: KrithaSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: TextStyle(
                        fontSize: KrithaText.sizeLg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: KrithaSpacing.s4),
                    Text(
                      model.publisherLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                    SizedBox(height: KrithaSpacing.s4),
                    Text(
                      '${formatCount(model.downloads)} downloads · '
                      '${formatCount(model.likes)} likes',
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
          if (capabilities.isNotEmpty) ...[
            SizedBox(height: KrithaSpacing.s12),
            Wrap(
              spacing: KrithaSpacing.s6,
              runSpacing: KrithaSpacing.s6,
              children: [
                for (final capability in capabilities)
                  CapabilityChip(label: capability.label),
              ],
            ),
          ],
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s16,
            runSpacing: KrithaSpacing.s8,
            children: [
              _Meta(
                label: 'Pipeline',
                value: model.pipelineTag ?? 'Not declared',
              ),
              _Meta(
                label: 'Library',
                value: model.libraryName ?? 'Not declared',
              ),
              _Meta(label: 'License', value: model.license ?? 'Not declared'),
              _Meta(label: 'Last modified', value: _date(model.lastModified)),
            ],
          ),
          if (model.gated || model.isPrivate) ...[
            SizedBox(height: KrithaSpacing.s12),
            Text(
              model.isPrivate
                  ? 'This repository is private. Your Hub token must have access.'
                  : 'This repository is gated. Accept its terms on Hugging Face and use an authorized token.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'Not declared';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: KrithaText.size2xs,
            color: KrithaColors.textMuted,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: KrithaText.sizeXs,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final hasLite = details.hasLitertLmFile;
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KrithaIcon(
                icon: HugeIcons.strokeRoundedShieldCheck,
                size: KrithaIcons.lg,
                color: KrithaColors.warning,
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Text(
                  'Runtime compatibility is not verified',
                  style: TextStyle(
                    fontSize: KrithaText.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s8),
          Text(
            'A Hub repository is catalogue discovery, not a download, an '
            'installed model or a working runtime. Kritha can only assign a '
            'model after it is present locally and passes validation.',
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: KrithaSpacing.s8),
          Text(
            hasLite
                ? 'The repository lists a .litertlm artifact. It must be present '
                      'on this device and pass local validation. Hub downloads '
                      'are not available yet.'
                : 'No .litertlm artifact was found in this repository.',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: hasLite
                  ? KrithaColors.textSecondary
                  : KrithaColors.warning,
            ),
          ),
          SizedBox(height: KrithaSpacing.s12),
          OutlinedButton.icon(
            onPressed: () => context.go('/models'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KrithaColors.textSecondary,
              side: BorderSide(color: KrithaColors.borderStrong),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KrithaRadius.base),
              ),
            ),
            icon: KrithaIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 16),
            label: const Text('Choose a local model'),
          ),
        ],
      ),
    );
  }
}

class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard({required this.details});

  final ModelDetails details;

  @override
  Widget build(BuildContext context) {
    final formats = details.formats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionTitle('Requirements'),
        WorkspaceCard(
          child: Column(
            children: [
              _RequirementRow(
                label: 'Local artifact',
                value: details.hasLitertLmFile
                    ? 'LiteRT-LM listed; runtime compatibility not verified'
                    : 'Not listed',
              ),
              WorkspaceDivider(),
              _RequirementRow(
                label: 'Repository formats',
                value: formats.isEmpty ? 'Not declared' : formats.join(', '),
              ),
              WorkspaceDivider(),
              _RequirementRow(
                label: 'Architecture',
                value: details.architecture ?? 'Not declared',
              ),
              WorkspaceDivider(),
              _RequirementRow(
                label: 'Files listed',
                value: '${details.files.length}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilesCard extends StatelessWidget {
  const _FilesCard({required this.files});

  final List<ModelFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return WorkspaceCard(
        child: Text(
          'No files were listed for this repository.',
          style: TextStyle(
            fontSize: KrithaText.sizeSm,
            color: KrithaColors.textMuted,
          ),
        ),
      );
    }
    const limit = 60;
    final visible = files.take(limit).toList();
    return WorkspaceCard(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s4),
      child: Column(
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            if (index > 0) WorkspaceDivider(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: KrithaSpacing.s12,
                vertical: KrithaSpacing.s8,
              ),
              child: Row(
                children: [
                  KrithaIcon(
                    icon: HugeIcons.strokeRoundedAttachment,
                    size: KrithaIcons.sm,
                    color: KrithaColors.textMuted,
                  ),
                  SizedBox(width: KrithaSpacing.s8),
                  Expanded(
                    child: Text(
                      visible[index].path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: KrithaSpacing.s8),
                  Text(
                    visible[index].readableSize,
                    style: TextStyle(
                      fontSize: KrithaText.size2xs,
                      color: KrithaColors.textMuted,
                    ),
                  ),
                  if (visible[index].isLfs) ...[
                    SizedBox(width: KrithaSpacing.s6),
                    CapabilityChip(label: 'LFS'),
                  ],
                ],
              ),
            ),
          ],
          if (files.length > limit)
            Padding(
              padding: EdgeInsets.all(KrithaSpacing.s12),
              child: Text(
                'Showing the first $limit of ${files.length} files.',
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.modelId, required this.hasLitertLmFile});

  final String modelId;
  final bool hasLitertLmFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KrithaSpacing.s8,
          runSpacing: KrithaSpacing.s8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: modelId));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Repository id copied')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: KrithaColors.textSecondary,
                side: BorderSide(color: KrithaColors.borderStrong),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                ),
              ),
              icon: KrithaIcon(icon: HugeIcons.strokeRoundedCopy01, size: 16),
              label: const Text('Copy repository id'),
            ),
            FilledButton.icon(
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
                icon: HugeIcons.strokeRoundedFilterHorizontal,
                size: 16,
                color: KrithaColors.textOnAccent,
              ),
              label: const Text('Active models'),
            ),
          ],
        ),
        SizedBox(height: KrithaSpacing.s8),
        Text(
          hasLitertLmFile
              ? 'Assignment is available only after this file is downloaded '
                    'and validated locally.'
              : 'This repository cannot be assigned to a capability in this '
                    'build.',
          style: TextStyle(
            fontSize: KrithaText.sizeXs,
            color: KrithaColors.textMuted,
          ),
        ),
      ],
    );
  }
}
