import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../../../widgets/context_menu.dart';
import '../../../../widgets/create_popup.dart';
import '../../catalogue/catalogue_model.dart';
import '../model_artifact.dart';
import '../model_setup_assessment.dart';
import '../model_setup_controller.dart';

const _viewLimitBytes = 512 * 1024;
const _tableBreakpoint = 640.0;
const _selectionColumnWidth = 42.0;

class ModelSetupSelectedArtifactsStep extends StatefulWidget {
  const ModelSetupSelectedArtifactsStep({super.key, required this.controller});

  final ModelSetupWizardController controller;

  @override
  State<ModelSetupSelectedArtifactsStep> createState() =>
      _ModelSetupSelectedArtifactsStepState();
}

class _ModelSetupSelectedArtifactsStepState
    extends State<ModelSetupSelectedArtifactsStep> {
  @override
  void initState() {
    super.initState();
    widget.controller.prepareArtifacts();
  }

  @override
  void didUpdateWidget(ModelSetupSelectedArtifactsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.prepareArtifacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.s20,
            KrithaSpacing.s4,
            KrithaSpacing.s20,
            KrithaSpacing.s16,
          ),
          child: _ManageArtifactsHeader(controller: controller),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s20,
              0,
              KrithaSpacing.s20,
              KrithaSpacing.s20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < ModelArtifactKind.values.length;
                  index++
                ) ...[
                  if (index > 0) SizedBox(height: KrithaSpacing.s12),
                  _ArtifactSection(
                    controller: controller,
                    kind: ModelArtifactKind.values[index],
                    repositoryId: controller.details.model.id,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ManageArtifactsHeader extends StatelessWidget {
  const _ManageArtifactsHeader({required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Artifacts',
              style: TextStyle(
                fontSize: KrithaText.sizeLg,
                fontWeight: FontWeight.w700,
                color: KrithaColors.textPrimary,
              ),
            ),
            SizedBox(height: KrithaSpacing.s4),
            Text(
              'Review, select and download the files required for this model.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
                height: 1.4,
              ),
            ),
            if (controller.saveError != null) ...[
              SizedBox(height: KrithaSpacing.s4),
              Text(
                controller.saveError!,
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.error,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
        final button = _DownloadAllButton(controller: controller);
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              SizedBox(height: KrithaSpacing.s12),
              button,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            SizedBox(width: KrithaSpacing.s16),
            button,
          ],
        );
      },
    );
  }
}

class _DownloadAllButton extends StatelessWidget {
  const _DownloadAllButton({required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    final enabled =
        controller.hasDownloadableSelection && !controller.downloadAllRunning;
    return FilledButton.icon(
      onPressed: enabled
          ? () => unawaited(controller.downloadAllArtifacts())
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: KrithaColors.accentBlue,
        foregroundColor: KrithaColors.textOnAccent,
        disabledBackgroundColor: KrithaColors.bgSecondary,
        disabledForegroundColor: KrithaColors.textMuted,
        minimumSize: const Size(0, 38),
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s14),
        textStyle: TextStyle(
          fontSize: KrithaText.sizeXs,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: controller.downloadAllRunning
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KrithaColors.textOnAccent,
              ),
            )
          : KrithaIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              size: KrithaIcons.xs,
              color: enabled
                  ? KrithaColors.textOnAccent
                  : KrithaColors.textMuted,
            ),
      label: const Text('Download All'),
    );
  }
}

class _ArtifactSection extends StatelessWidget {
  const _ArtifactSection({
    required this.controller,
    required this.kind,
    required this.repositoryId,
  });

  final ModelSetupWizardController controller;
  final ModelArtifactKind kind;
  final String repositoryId;

  @override
  Widget build(BuildContext context) {
    final rows = controller.artifactsFor(kind);
    final expanded = controller.isSectionExpanded(kind);
    final selection = controller.sectionSelection(kind);

    return Container(
      key: ValueKey('artifact-section-${kind.name}'),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s12,
              KrithaSpacing.s6,
              KrithaSpacing.s6,
              KrithaSpacing.s6,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: _RoundCheckbox(
                      key: ValueKey('artifact-section-check-${kind.name}'),
                      value: switch (selection) {
                        ModelArtifactSectionSelection.all => true,
                        ModelArtifactSectionSelection.partial => null,
                        ModelArtifactSectionSelection.none => false,
                      },
                      tristate: true,
                      enabled: rows.isNotEmpty,
                      onChanged: () => controller.toggleSectionSelection(kind),
                      semanticLabel:
                          '${kind.sectionTitle} selection: ${selection.name}',
                    ),
                  ),
                ),
                SizedBox(width: KrithaSpacing.s8),
                Expanded(
                  child: Text(
                    kind.sectionTitle,
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: FontWeight.w600,
                      color: KrithaColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => controller.addArtifactRow(kind),
                  style: TextButton.styleFrom(
                    foregroundColor: KrithaColors.accentBlue,
                    minimumSize: const Size(0, 32),
                    padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: TextStyle(
                      fontSize: KrithaText.size2xs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: KrithaIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: KrithaIcons.xs,
                    color: KrithaColors.accentBlue,
                  ),
                  label: const Text('Add Row'),
                ),
                IconButton(
                  tooltip: expanded
                      ? 'Collapse ${kind.sectionTitle}'
                      : 'Expand ${kind.sectionTitle}',
                  onPressed: () => controller.toggleSection(kind),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: KrithaIcon(
                    icon: expanded
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01,
                    size: KrithaIcons.sm,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (kind == ModelArtifactKind.weights &&
              controller.needsWeightSuggestion)
            Padding(
              padding: EdgeInsets.fromLTRB(
                KrithaSpacing.s12 + 30 + KrithaSpacing.s8,
                0,
                KrithaSpacing.s12,
                KrithaSpacing.s8,
              ),
              child: Text(
                'No model weight selected. Consider choosing an FP4 or INT4 variant if available.',
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                KrithaSpacing.s12,
                KrithaSpacing.s4,
                KrithaSpacing.s12,
                KrithaSpacing.s12,
              ),
              child: rows.isEmpty
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        KrithaSpacing.s4,
                        KrithaSpacing.s4,
                        KrithaSpacing.s4,
                        KrithaSpacing.s6,
                      ),
                      child: Text(
                        'No rows added yet. Add a row to get started.',
                        style: TextStyle(
                          fontSize: KrithaText.sizeXs,
                          color: KrithaColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    )
                  : _ArtifactTable(
                      controller: controller,
                      rows: rows,
                      repositoryId: repositoryId,
                    ),
            ),
        ],
      ),
    );
  }
}

class _ArtifactTable extends StatelessWidget {
  const _ArtifactTable({
    required this.controller,
    required this.rows,
    required this.repositoryId,
  });

  final ModelSetupWizardController controller;
  final List<ModelArtifactRow> rows;
  final String repositoryId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _tableBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++)
              if (compact)
                _ArtifactKeyValueRow(
                  controller: controller,
                  row: rows[index],
                  repositoryId: repositoryId,
                  showDivider: index < rows.length - 1,
                )
              else
                _ArtifactTableRow(
                  controller: controller,
                  row: rows[index],
                  repositoryId: repositoryId,
                  showDivider: index < rows.length - 1,
                ),
          ],
        );
      },
    );
  }
}

class _ArtifactTableRow extends StatelessWidget {
  const _ArtifactTableRow({
    required this.controller,
    required this.row,
    required this.repositoryId,
    required this.showDivider,
  });

  final ModelSetupWizardController controller;
  final ModelArtifactRow row;
  final String repositoryId;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final selected = row.selected;
    final active = selected && !row.isTransferring;
    return Container(
      key: ValueKey('artifact-row-${row.id}'),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: KrithaColors.borderFaint))
            : null,
      ),
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _selectionColumnWidth,
            child: Center(
              child: _RoundCheckbox(
                key: ValueKey('artifact-check-${row.id}'),
                value: selected,
                enabled: true,
                onChanged: () => controller.toggleArtifactSelected(row.id),
                semanticLabel: selected
                    ? 'Deselect ${_fileName(row)}'
                    : 'Select ${_fileName(row)}',
              ),
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: _TargetPathField(
              controller: controller,
              row: row,
              enabled: active,
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: _SourceCell(row: row, repositoryId: repositoryId),
          ),
          SizedBox(width: KrithaSpacing.s8),
          _RowActions(controller: controller, row: row, active: active),
        ],
      ),
    );
  }
}

class _ArtifactKeyValueRow extends StatelessWidget {
  const _ArtifactKeyValueRow({
    required this.controller,
    required this.row,
    required this.repositoryId,
    required this.showDivider,
  });

  final ModelSetupWizardController controller;
  final ModelArtifactRow row;
  final String repositoryId;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final selected = row.selected;
    final active = selected && !row.isTransferring;
    return Container(
      key: ValueKey('artifact-row-${row.id}'),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: KrithaColors.borderFaint))
            : null,
      ),
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Padding(
              padding: EdgeInsets.only(top: KrithaSpacing.s4),
              child: Center(
                child: _RoundCheckbox(
                  key: ValueKey('artifact-check-${row.id}'),
                  value: selected,
                  enabled: true,
                  onChanged: () => controller.toggleArtifactSelected(row.id),
                  semanticLabel: selected
                      ? 'Deselect ${_fileName(row)}'
                      : 'Select ${_fileName(row)}',
                ),
              ),
            ),
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TargetPathField(
                  controller: controller,
                  row: row,
                  enabled: active,
                ),
                SizedBox(height: KrithaSpacing.s8),
                _SourceCell(row: row, repositoryId: repositoryId),
                SizedBox(height: KrithaSpacing.s8),
                _RowActions(controller: controller, row: row, active: active),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundCheckbox extends StatelessWidget {
  const _RoundCheckbox({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.semanticLabel,
    this.tristate = false,
  });

  final bool? value;
  final bool tristate;
  final bool enabled;
  final VoidCallback onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Checkbox(
            value: value,
            tristate: tristate,
            onChanged: enabled ? (_) => onChanged() : null,
            shape: const CircleBorder(),
            side: BorderSide(color: KrithaColors.borderStrong),
            activeColor: KrithaColors.accentBlue,
            // The default glyph spans nearly the whole box; a smaller overlay
            // keeps the round control legible with real internal padding.
            checkColor: Colors.transparent,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            splashRadius: 16,
          ),
          // Checkbox paints checkColor transparent, so both the tick and the
          // indeterminate dash are drawn here.
          if (value != false)
            IgnorePointer(
              child: KrithaIcon(
                icon: value == true
                    ? HugeIcons.strokeRoundedTick02
                    : HugeIcons.strokeRoundedMinusSign,
                size: 10,
                color: KrithaColors.textOnAccent,
                strokeWidth: 2.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceCell extends StatelessWidget {
  const _SourceCell({required this.row, required this.repositoryId});

  final ModelArtifactRow row;
  final String repositoryId;

  @override
  Widget build(BuildContext context) {
    final path = _sourcePath(row);
    final muted = !row.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _sourceTooltip(row, repositoryId),
          child: Row(
            children: [
              KrithaIcon(
                icon: _sourceIcon(row.sourceType),
                size: KrithaIcons.sm,
                color: _sourceColor(row.sourceType, muted),
              ),
              SizedBox(width: KrithaSpacing.s6),
              Expanded(
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: muted
                        ? KrithaColors.textDimmed
                        : KrithaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (row.isRepository && row.isTransferring) ...[
          SizedBox(height: KrithaSpacing.s4),
          _ArtifactProgress(row: row),
        ],
      ],
    );
  }
}

class _ArtifactProgress extends StatelessWidget {
  const _ArtifactProgress({required this.row});

  final ModelArtifactRow row;

  @override
  Widget build(BuildContext context) {
    final paused = row.isPaused;
    final color = paused ? KrithaColors.warning : KrithaColors.success;
    final progress = row.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KrithaRadius.xs),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress ?? 0),
            duration: KrithaMotion.fast,
            curve: Curves.easeOut,
            builder: (context, value, child) => LinearProgressIndicator(
              value: progress == null ? null : value,
              minHeight: 4,
              backgroundColor: KrithaColors.bgTertiary,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        SizedBox(height: 2),
        Text(
          '${_byteLabel(row.receivedBytes)} of ${_byteLabel(row.sizeBytes)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: KrithaText.size2xs,
            color: paused ? KrithaColors.warning : KrithaColors.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

String _byteLabel(int? bytes) {
  if (bytes == null) return '—';
  if (bytes <= 0) return '0 B';
  return formatBytes(bytes);
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.controller,
    required this.row,
    required this.active,
  });

  final ModelSetupWizardController controller;
  final ModelArtifactRow row;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KrithaSpacing.s6,
      runSpacing: KrithaSpacing.s6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _primaryAction(),
        _secondaryAction(context),
        Builder(
          builder: (buttonContext) => IconButton(
            key: ValueKey('artifact-menu-${row.id}'),
            tooltip: 'Artifact options',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              fixedSize: const Size(30, 30),
              minimumSize: const Size(30, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openMenu(context, buttonContext),
            icon: KrithaIcon(
              icon: HugeIcons.strokeRoundedEllipsisVertical,
              size: KrithaIcons.sm,
              color: KrithaColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryAction() {
    if (row.isWorking) {
      return _SmallActionButton(
        label: 'Pause',
        icon: HugeIcons.strokeRoundedPause,
        enabled: true,
        primary: true,
        onPressed: () => controller.pauseArtifactDownload(row.id),
      );
    }
    if (row.isPaused) {
      return _SmallActionButton(
        label: 'Resume',
        icon: HugeIcons.strokeRoundedPlay,
        enabled: true,
        primary: true,
        onPressed: () => controller.resumeArtifactDownload(row.id),
      );
    }
    if (row.isUnassigned) {
      return _SmallActionButton(
        label: 'Download',
        icon: HugeIcons.strokeRoundedDownload01,
        enabled: false,
        primary: true,
        onPressed: null,
      );
    }
    if (row.isDevice) {
      return _SmallActionButton(
        label: 'Download',
        icon: HugeIcons.strokeRoundedDownload01,
        enabled: false,
        primary: true,
        onPressed: null,
      );
    }
    if (row.isReady) {
      return _SmallActionButton(
        label: 'Delete',
        icon: HugeIcons.strokeRoundedDelete02,
        enabled: active,
        destructive: true,
        onPressed: () => unawaited(controller.deleteArtifactCopy(row.id)),
      );
    }
    return _SmallActionButton(
      label: 'Download',
      icon: HugeIcons.strokeRoundedDownload01,
      enabled: active && row.canDownload,
      primary: true,
      onPressed: () => unawaited(controller.downloadArtifact(row.id)),
    );
  }

  Widget _secondaryAction(BuildContext context) {
    if (row.isUnassigned) {
      return _SmallActionButton(
        label: 'Choose',
        icon: HugeIcons.strokeRoundedLink01,
        enabled: active,
        onPressed: () => unawaited(_chooseSource(context, row)),
      );
    }
    return _SmallActionButton(
      label: 'Replace',
      icon: HugeIcons.strokeRoundedLink01,
      enabled: active,
      onPressed: () => unawaited(_chooseSource(context, row)),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final canView =
        row.selected &&
        row.viewPath != null &&
        row.kind != ModelArtifactKind.weights &&
        (row.sizeBytes == null || row.sizeBytes! <= _viewLimitBytes);
    final selected = await showKrithaContextMenu(
      context: context,
      anchor: ContextMenuAnchor.fromContext(buttonContext),
      align: ContextMenuAlign.right,
      items: [
        ContextMenuItem(
          id: 'view',
          label: 'View',
          icon: HugeIcons.strokeRoundedEye,
          disabled: !canView,
        ),
        ContextMenuItem(
          id: 'choose',
          label: 'Choose from device',
          icon: HugeIcons.strokeRoundedFolder01,
          disabled: !row.selected || row.isTransferring,
        ),
        ContextMenuItem(
          id: 'remove',
          label: 'Remove row',
          icon: HugeIcons.strokeRoundedDelete02,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'view':
        await _view(context);
      case 'choose':
        await _chooseDevice(context, row);
      case 'remove':
        await controller.removeArtifactRow(row.id);
    }
  }

  Future<void> _view(BuildContext context) async {
    final path = row.viewPath;
    if (path == null) return;
    final file = File(path);
    try {
      if (!await file.exists()) {
        if (context.mounted) {
          _message(context, 'The file no longer exists on this device.');
        }
        return;
      }
      final size = await file.length();
      if (size > _viewLimitBytes) {
        if (context.mounted) {
          _message(context, 'This file is too large to preview.');
        }
        return;
      }
      final text = await file.readAsString();
      if (!context.mounted) return;
      await createPopup<void>(
        context: context,
        builder: (popupContext) => CreatePopup(
          title: row.displayName,
          subtitle: row.targetPath,
          actions: [
            PopupSecondaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(popupContext).pop(),
            ),
          ],
          child: SizedBox(
            height: 360,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(KrithaSpacing.s16),
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ).copyWith(color: KrithaColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    } on FileSystemException {
      if (context.mounted) _message(context, 'The file could not be read.');
    } on FormatException {
      if (context.mounted) {
        _message(context, 'This file is not text and cannot be previewed.');
      }
    }
  }

  Future<void> _chooseSource(
    BuildContext context,
    ModelArtifactRow current,
  ) async {
    final choice = await _showSourcePicker(context, current);
    if (!context.mounted || choice == null) return;
    if (choice.isDevice) {
      await _chooseDevice(context, current);
      return;
    }
    final file = choice.file;
    if (file == null) return;
    if (!current.isUnassigned) {
      final confirmed = await _confirmReplacement(
        context,
        current,
        replacementKind: 'repository file',
        willDownload: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    await controller.assignRepositoryArtifact(current.id, file);
  }

  Future<void> _chooseDevice(
    BuildContext context,
    ModelArtifactRow current,
  ) async {
    String? path;
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      path = files.first.path;
    } on Object {
      if (context.mounted) {
        _message(context, 'A device file could not be selected.');
      }
      return;
    }
    if (path == null || path.trim().isEmpty || !context.mounted) return;
    if (!current.isUnassigned) {
      final confirmed = await _confirmReplacement(
        context,
        current,
        replacementKind: 'device file',
        willDownload: false,
      );
      if (!confirmed || !context.mounted) return;
    }
    await controller.assignDeviceArtifact(current.id, path);
  }

  Future<bool> _confirmReplacement(
    BuildContext context,
    ModelArtifactRow current, {
    required String replacementKind,
    required bool willDownload,
  }) async {
    final localCopy = current.hasLocalCopy
        ? 'The local copy at ${current.targetPath} will be deleted. '
        : '';
    final acquisition = willDownload
        ? 'The replacement will be downloaded again before setup can continue.'
        : 'The replacement will be copied into this configuration before setup can continue.';
    final confirmed = await createPopup<bool>(
      context: context,
      builder: (popupContext) => CreatePopup(
        title: 'Replace source?',
        actions: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(popupContext).pop(false),
          ),
          PopupPrimaryButton(
            label: 'Replace',
            onPressed: () => Navigator.of(popupContext).pop(true),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.all(KrithaSpacing.s20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KrithaIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: KrithaIcons.sm,
                color: KrithaColors.warning,
              ),
              SizedBox(width: KrithaSpacing.s8),
              Expanded(
                child: Text(
                  '${localCopy}The $replacementKind will replace the current source. $acquisition',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<_SourceChoice?> _showSourcePicker(
    BuildContext context,
    ModelArtifactRow current,
  ) async {
    final artifacts =
        controller.assessment?.artifacts ?? const <SetupArtifact>[];
    final selection = await createPopup<String>(
      context: context,
      builder: (popupContext) => CreatePopup(
        title: current.isUnassigned ? 'Choose a source' : 'Replace source',
        subtitle: 'Repository files are downloaded into this configuration. Device files are copied into it.',
        actions: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(popupContext).pop(),
          ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s12,
              0,
              KrithaSpacing.s12,
              KrithaSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s8),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(popupContext).pop(_deviceChoiceId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KrithaColors.textSecondary,
                      side: BorderSide(color: KrithaColors.borderSubtle),
                      minimumSize: const Size(0, 40),
                    ),
                    icon: KrithaIcon(
                      icon: HugeIcons.strokeRoundedFolder01,
                      size: KrithaIcons.sm,
                      color: KrithaColors.accentLightBlue,
                    ),
                    label: const Text('Choose from device'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: KrithaSpacing.s8,
                    bottom: KrithaSpacing.s4,
                  ),
                  child: Text(
                    'Repository files',
                    style: TextStyle(
                      fontSize: KrithaText.size2xs,
                      fontWeight: FontWeight.w600,
                      color: KrithaColors.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (artifacts.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s12),
                    child: Text(
                      'This repository returned no files to choose from.',
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  )
                else
                  for (final artifact in artifacts)
                    _RepositoryFileTile(
                      artifact: artifact,
                      onTap: () => Navigator.of(popupContext)
                          .pop(_repositoryChoicePrefix + artifact.file.path),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null) return null;
    if (selection == _deviceChoiceId) return const _SourceChoice.device();
    if (!selection.startsWith(_repositoryChoicePrefix)) return null;
    final path = selection.substring(_repositoryChoicePrefix.length);
    for (final artifact in artifacts) {
      if (artifact.file.path == path) {
        return _SourceChoice.repository(artifact.file);
      }
    }
    return null;
  }

  void _message(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

const _deviceChoiceId = '__device__';
const _repositoryChoicePrefix = 'repo:';

class _SourceChoice {
  const _SourceChoice.device() : file = null;
  const _SourceChoice.repository(this.file);

  final ModelFile? file;

  bool get isDevice => file == null;
}

class _RepositoryFileTile extends StatelessWidget {
  const _RepositoryFileTile({required this.artifact, required this.onTap});

  final SetupArtifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KrithaRadius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: KrithaSpacing.s8,
          vertical: KrithaSpacing.s10,
        ),
        child: Row(
          children: [
            KrithaIcon(
              icon: HugeIcons.strokeRoundedGitBranch,
              size: KrithaIcons.sm,
              color: KrithaColors.accentLightBlue,
            ),
            SizedBox(width: KrithaSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: KrithaText.sizeXs,
                      fontWeight: FontWeight.w600,
                      color: KrithaColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${artifact.kind.kindLabel} · ${artifact.file.path}',
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
            if (artifact.file.sizeBytes != null)
              Text(
                artifact.file.readableSize,
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final List<List<dynamic>> icon;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? KrithaColors.error
        : primary
        ? KrithaColors.textOnAccent
        : KrithaColors.textSecondary;
    final background = primary
        ? KrithaColors.accentBlue
        : KrithaColors.bgPrimary;
    final disabledForeground = KrithaColors.textMuted;
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TextStyle(
          fontSize: KrithaText.size2xs,
          fontWeight: FontWeight.w600,
        ),
        foregroundColor: foreground,
        backgroundColor: background,
        disabledForegroundColor: disabledForeground,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        side: primary
            ? BorderSide.none
            : BorderSide(
                color: destructive
                    ? KrithaColors.error.withValues(alpha: 0.35)
                    : KrithaColors.borderSubtle,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
        ),
      ),
      icon: KrithaIcon(
        icon: icon,
        size: 14,
        color: enabled ? foreground : disabledForeground,
      ),
      label: Text(label),
    );
  }
}

class _TargetPathField extends StatefulWidget {
  const _TargetPathField({
    required this.controller,
    required this.row,
    required this.enabled,
  });

  final ModelSetupWizardController controller;
  final ModelArtifactRow row;
  final bool enabled;

  @override
  State<_TargetPathField> createState() => _TargetPathFieldState();
}

class _TargetPathFieldState extends State<_TargetPathField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.row.targetPath,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_TargetPathField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.row.targetPath;
    if (!_focus.hasFocus && _text.text != value) _text.text = value;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) return;
    _submit();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty || value == widget.row.targetPath) return;
    unawaited(widget.controller.updateArtifactTarget(widget.row.id, value));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('artifact-target-${widget.row.id}'),
      controller: _text,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        _submit();
        _focus.unfocus();
      },
      style: TextStyle(
        fontSize: KrithaText.size2xs,
        color: widget.enabled
            ? KrithaColors.textSecondary
            : KrithaColors.textDimmed,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: widget.enabled
            ? KrithaColors.bgPrimary
            : KrithaColors.bgSurface,
        hintText: 'Relative path',
        hintStyle: TextStyle(
          fontSize: KrithaText.size2xs,
          color: KrithaColors.textDimmed,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: KrithaSpacing.s8,
          vertical: 7,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
          borderSide: BorderSide(color: KrithaColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
          borderSide: BorderSide(color: KrithaColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
          borderSide: BorderSide(color: KrithaColors.accentBlue),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
          borderSide: BorderSide(color: KrithaColors.borderFaint),
        ),
      ),
    );
  }
}

List<List<dynamic>> _sourceIcon(ModelArtifactSourceType type) => switch (type) {
  ModelArtifactSourceType.repository => HugeIcons.strokeRoundedGitBranch,
  ModelArtifactSourceType.device => HugeIcons.strokeRoundedFolder01,
  ModelArtifactSourceType.unassigned =>
    HugeIcons.strokeRoundedCircleQuestionMark,
};

Color _sourceColor(ModelArtifactSourceType type, bool muted) {
  if (muted) return KrithaColors.textDimmed;
  return switch (type) {
    ModelArtifactSourceType.repository => KrithaColors.accentLightBlue,
    ModelArtifactSourceType.device => KrithaColors.textSecondary,
    ModelArtifactSourceType.unassigned => KrithaColors.textMuted,
  };
}

String _fileName(ModelArtifactRow row) {
  final name = switch (row.sourceType) {
    ModelArtifactSourceType.repository => row.repositoryFile?.name ?? '',
    ModelArtifactSourceType.device => artifactFileName(
      row.deviceSourcePath ?? '',
    ),
    ModelArtifactSourceType.unassigned => artifactFileName(row.targetPath),
  };
  return name.isEmpty ? 'New artifact' : name;
}

String _sourcePath(ModelArtifactRow row) {
  return switch (row.sourceType) {
    ModelArtifactSourceType.repository => '/${row.repositoryFile?.path ?? ''}',
    ModelArtifactSourceType.device => row.deviceSourcePath ?? 'Device file',
    ModelArtifactSourceType.unassigned => 'No source assigned',
  };
}

String _sourceTooltip(ModelArtifactRow row, String repositoryId) {
  return switch (row.sourceType) {
    ModelArtifactSourceType.repository =>
      '$repositoryId/${row.repositoryFile?.path ?? ''}',
    ModelArtifactSourceType.device => row.deviceSourcePath ?? 'Device file',
    ModelArtifactSourceType.unassigned => 'No source assigned',
  };
}
