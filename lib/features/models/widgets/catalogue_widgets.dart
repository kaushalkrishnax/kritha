import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../catalogue/catalogue_failure.dart';
import '../catalogue/catalogue_model.dart';
import 'workspace_header.dart';

List<List<dynamic>> capabilityIcon(ModelCapability capability) {
  return switch (capability) {
    ModelCapability.text => HugeIcons.strokeRoundedMessageCircle,
    ModelCapability.vision => HugeIcons.strokeRoundedImage01,
    ModelCapability.imageGeneration => HugeIcons.strokeRoundedSparkles,
    ModelCapability.speechRecognition => HugeIcons.strokeRoundedMic01,
    ModelCapability.textToSpeech => HugeIcons.strokeRoundedVolume02,
    ModelCapability.audio => HugeIcons.strokeRoundedAudioLines,
    ModelCapability.video => HugeIcons.strokeRoundedVideo01,
    ModelCapability.embeddings => HugeIcons.strokeRoundedDatabase,
  };
}

class CatalogueErrorView extends StatelessWidget {
  const CatalogueErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final CatalogueFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(KrithaSpacing.s20),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KrithaIcon(
                icon: failure.kind == CatalogueFailureKind.offline
                    ? HugeIcons.strokeRoundedAlert02
                    : HugeIcons.strokeRoundedInfo,
                size: KrithaIcons.lg,
                color: KrithaColors.warning,
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Text(
                  failure.title,
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
            failure.message,
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
            ),
          ),
          if (failure.kind == CatalogueFailureKind.rateLimited) ...[
            SizedBox(height: KrithaSpacing.s8),
            Text(
              'A Hugging Face token raises the authenticated rate limit. '
              'Add one from the catalogue menu.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
          ],
          if (failure.kind == CatalogueFailureKind.unauthorized) ...[
            SizedBox(height: KrithaSpacing.s8),
            Text(
              'Open the catalogue menu to add, replace or remove the token.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
          ],
          if (failure.canRetry) ...[
            SizedBox(height: KrithaSpacing.s16),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: KrithaColors.textSecondary,
                side: BorderSide(color: KrithaColors.borderStrong),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                ),
              ),
              icon: KrithaIcon(
                icon: HugeIcons.strokeRoundedRotateCcw,
                size: 16,
              ),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class CatalogueLoading extends StatelessWidget {
  const CatalogueLoading({super.key, this.label = 'Loading models…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s32),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KrithaColors.accentLightBlue,
            ),
          ),
          SizedBox(height: KrithaSpacing.s12),
          Text(
            label,
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogueEmpty extends StatelessWidget {
  const CatalogueEmpty({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s32),
      child: Column(
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: KrithaIcons.xl,
            color: KrithaColors.textMuted,
          ),
          SizedBox(height: KrithaSpacing.s12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: KrithaText.sizeMd,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: KrithaSpacing.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class ModelCard extends StatelessWidget {
  const ModelCard({
    super.key,
    required this.model,
    required this.onTap,
    this.width,
  });

  final CatalogueModel model;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: KrithaColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.md),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _PublisherAvatar(model: model),
                    SizedBox(width: KrithaSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KrithaText.sizeSm,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (model.publisherLabel.isNotEmpty)
                            Text(
                              model.publisherLabel,
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
                    if (model.gated || model.isPrivate)
                      Padding(
                        padding: EdgeInsets.only(left: KrithaSpacing.s6),
                        child: CapabilityChip(
                          label: model.isPrivate ? 'Private' : 'Gated',
                          selected: true,
                        ),
                      ),
                    SizedBox(width: KrithaSpacing.s6),
                    Transform.rotate(
                      angle: math.pi,
                      child: KrithaIcon(
                        icon: HugeIcons.strokeRoundedChevronLeft,
                        size: KrithaIcons.sm,
                        color: KrithaColors.textDimmed,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: KrithaSpacing.s8),
                Wrap(
                  spacing: KrithaSpacing.s10,
                  runSpacing: KrithaSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (model.taskLabel != null)
                      _ModelMetadata(
                        icon: HugeIcons.strokeRoundedTask01,
                        label: model.taskLabel!,
                      ),
                    if (model.parameterCount != null)
                      _ModelMetadata(
                        icon: HugeIcons.strokeRoundedCirclePile,
                        label: formatParameterCount(model.parameterCount!),
                      ),
                    if (model.lastModified != null)
                      _ModelMetadata(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        label: _updatedLabel(model.lastModified!),
                      ),
                    _ModelMetadata(
                      icon: HugeIcons.strokeRoundedDownload04,
                      label: formatCount(model.downloads),
                    ),
                    _ModelMetadata(
                      icon: HugeIcons.strokeRoundedFavourite,
                      label: formatCount(model.likes),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _updatedLabel(DateTime date) {
    final days = DateTime.now().difference(date.toLocal()).inDays;
    if (days <= 0) return 'Updated today';
    if (days == 1) return 'Updated 1d ago';
    if (days < 30) return 'Updated ${days}d ago';
    final months = days ~/ 30;
    if (months < 12) return 'Updated ${months}mo ago';
    return 'Updated ${days ~/ 365}y ago';
  }
}

class _PublisherAvatar extends StatelessWidget {
  const _PublisherAvatar({required this.model});

  final CatalogueModel model;

  @override
  Widget build(BuildContext context) {
    final url = model.avatarUrl;
    return ClipOval(
      child: SizedBox(
        width: 28,
        height: 28,
        child: url == null
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => Container(
    alignment: Alignment.center,
    color: KrithaColors.bgTertiary,
    child: Text(
      model.publisherLabel.isEmpty ? '?' : model.publisherLabel[0],
      style: TextStyle(
        color: KrithaColors.textSecondary,
        fontSize: KrithaText.sizeXs,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ModelMetadata extends StatelessWidget {
  const _ModelMetadata({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KrithaIcon(icon: icon, size: 14, color: KrithaColors.textMuted),
        SizedBox(width: KrithaSpacing.s4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: KrithaText.size2xs,
            color: KrithaColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class CapabilityFilterChips extends StatelessWidget {
  const CapabilityFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ModelCapability? selected;
  final ValueChanged<ModelCapability?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(ModelCapability?, String)>[
      (null, 'All'),
      for (final capability in ModelCapability.values)
        (capability, capability.label),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _FilterChip(
              label: item.$2,
              selected: selected == item.$1,
              onTap: () => onSelected(item.$1),
            ),
            SizedBox(width: KrithaSpacing.s8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        focusColor: KrithaColors.contextMenuPressed,
        splashColor: KrithaColors.contextMenuPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s14,
            vertical: KrithaSpacing.s8,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              fontWeight: FontWeight.w600,
              color: selected
                  ? KrithaColors.textOnAccent
                  : KrithaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
