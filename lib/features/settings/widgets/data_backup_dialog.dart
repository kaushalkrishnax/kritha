import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../services/backup_service.dart';
import '../../../widgets/create_popup.dart';

class DataBackupDialog extends ConsumerStatefulWidget {
  const DataBackupDialog({super.key});

  @override
  ConsumerState<DataBackupDialog> createState() => _DataBackupDialogState();
}

class _DataBackupDialogState extends ConsumerState<DataBackupDialog> {
  final Set<BackupCategory> _selected = {
    BackupCategory.providers,
    BackupCategory.activeModels,
    BackupCategory.chatHistory,
    BackupCategory.archivedChats,
    BackupCategory.settings,
  };
  bool _busy = false;
  String? _statusMessage;

  bool get _hasChats =>
      _selected.contains(BackupCategory.chatHistory) ||
      _selected.contains(BackupCategory.archivedChats);

  bool get _allSelected => BackupCategory.values.every(_selected.contains);

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected.addAll(BackupCategory.values);
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleCategory(BackupCategory category, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(category);
      } else {
        _selected.remove(category);
        if (!_hasChats) {
          _selected.remove(BackupCategory.media);
        }
      }
    });
  }

  Future<void> _export() async {
    if (_selected.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final result = await ref
          .read(backupServiceProvider)
          .exportBackup(Set<BackupCategory>.from(_selected));
      if (!mounted) return;

      final fileName = result.file.uri.pathSegments.last;
      if (Platform.isAndroid || Platform.isIOS) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(result.file.path)],
            subject: 'Kritha Backup',
          ),
        );
      } else {
        final savedPath = await FilePicker.saveFile(
          dialogTitle: 'Save Kritha Backup',
          fileName: fileName,
          bytes: await result.file.readAsBytes(),
        );
        if (savedPath == null && mounted) {
          setState(() => _busy = false);
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isZip
                ? 'Exported ZIP backup (${result.mediaCount} media files).'
                : 'Exported JSON backup.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      final path = picked.singleOrNull?.path;
      if (path == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final lower = path.toLowerCase();
      if (!lower.endsWith('.json') && !lower.endsWith('.zip')) {
        throw const FormatException('Select a .json or .zip Kritha backup.');
      }

      final service = ref.read(backupServiceProvider);
      final parsed = await service.inspectBackup(path);
      if (!mounted) return;

      if (parsed.checksumMismatch) {
        final proceed = await _confirmChecksumMismatch(parsed.checksumMessage);
        if (proceed != true || !mounted) {
          setState(() => _busy = false);
          return;
        }
      }

      var resolution = ConflictResolution.replaceExisting;
      if (parsed.conflicts.hasAny) {
        final choice = await _resolveConflicts(parsed.conflicts);
        if (choice == null || !mounted) {
          setState(() => _busy = false);
          return;
        }
        resolution = choice;
      }

      await service.applyImport(parsed, resolution: resolution);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${parsed.sessionCount} chats '
            '(${parsed.messageCount} messages'
            '${parsed.mediaCount > 0 ? ', ${parsed.mediaCount} media files' : ''}).',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmChecksumMismatch(String? detail) {
    return createPopup<bool>(
      context: context,
      builder: (ctx) => CreatePopup(
        title: 'Checksum mismatch',
        subtitle: 'The ZIP media verification did not match.',
        actions: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          PopupPrimaryButton(
            label: 'Continue anyway',
            destructive: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s20),
          child: Text(
            '${detail ?? 'One or more media files failed SHA-256 verification.'}\n\n'
            'The archive may be incomplete or modified. Do you want to continue importing anyway?',
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textSecondary,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Future<ConflictResolution?> _resolveConflicts(BackupConflicts conflicts) {
    final items = conflicts.describe();
    return createPopup<ConflictResolution>(
      context: context,
      builder: (ctx) => CreatePopup(
        title: 'Existing data found',
        subtitle: 'Choose how to handle items that already exist on this device.',
        footer: Row(
          children: [
            PopupSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const Spacer(),
            PopupSecondaryButton(
              label: 'Keep existing',
              onPressed: () =>
                  Navigator.of(ctx).pop(ConflictResolution.keepExisting),
            ),
            SizedBox(width: KrithaSpacing.s8),
            PopupPrimaryButton(
              label: 'Replace',
              onPressed: () =>
                  Navigator.of(ctx).pop(ConflictResolution.replaceExisting),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This backup overlaps with:',
                style: TextStyle(
                  fontSize: KrithaText.sizeSm,
                  color: KrithaColors.textSecondary,
                ),
              ),
              SizedBox(height: KrithaSpacing.s8),
              for (final item in items)
                Padding(
                  padding: EdgeInsets.only(bottom: KrithaSpacing.s4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: KrithaColors.accentLightBlue,
                      ),
                      SizedBox(width: KrithaSpacing.s8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: KrithaText.sizeSm,
                            color: KrithaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: KrithaSpacing.s8),
              Text(
                'Keep existing skips overlapping items and only adds new ones. '
                'Replace overwrites conflicting items with the backup.',
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exportFormat = _selected.contains(BackupCategory.media)
        ? 'ZIP'
        : 'JSON';
    return CreatePopup(
      title: 'Export & Import Data',
      subtitle: 'Back up or restore your Kritha data across installs.',
      footer: Row(
        children: [
          PopupSecondaryButton(
            label: 'Cancel',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          PopupPrimaryButton(
            label: _busy ? 'Working…' : 'Export $exportFormat',
            onPressed: (_busy || _selected.isEmpty) ? null : _export,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: KrithaSpacing.s12,
                vertical: KrithaSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: KrithaColors.bgPrimary,
                borderRadius: BorderRadius.circular(KrithaRadius.md),
                border: Border.all(color: KrithaColors.borderSubtle),
              ),
              child: Row(
                children: [
                  KrithaIcon(
                    icon: HugeIcons.strokeRoundedDownload04,
                    size: 18,
                    color: KrithaColors.accentLightBlue,
                  ),
                  SizedBox(width: KrithaSpacing.s10),
                  Expanded(
                    child: Text(
                      'Import Data instead?',
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w600,
                        color: KrithaColors.textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _import,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(
                        horizontal: KrithaSpacing.s14,
                        vertical: KrithaSpacing.s8,
                      ),
                    ),
                    child: const Text('Import'),
                  ),
                ],
              ),
            ),
            SizedBox(height: KrithaSpacing.s12),
            CheckboxListTile(
              value: _allSelected,
              onChanged: _busy ? null : _toggleAll,
              title: Text(
                'Select All',
                style: TextStyle(
                  fontSize: KrithaText.sizeSm,
                  fontWeight: FontWeight.w600,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: KrithaColors.accentBlue,
            ),
            Divider(height: 1, color: KrithaColors.borderFaint),
            for (final category in BackupCategory.values)
              CheckboxListTile(
                value: _selected.contains(category),
                onChanged: _busy ||
                        (category == BackupCategory.media && !_hasChats)
                    ? null
                    : (v) => _toggleCategory(category, v),
                title: Text(
                  category.title,
                  style: TextStyle(fontSize: KrithaText.sizeSm),
                ),
                subtitle: Text(
                  category.subtitle,
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: KrithaColors.textMuted,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: KrithaColors.accentBlue,
              ),
            if (_statusMessage != null) ...[
              SizedBox(height: KrithaSpacing.s8),
              Text(
                _statusMessage!,
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
}
