import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/chat_attachment.dart';

/// Picks attachments for the composer. Kept behind an interface so widget
/// tests can supply deterministic files without touching platform channels.
abstract interface class AttachmentPicker {
  Future<List<ChatAttachment>> pickImages();
  Future<List<ChatAttachment>> pickFiles();
}

class FileAttachmentPicker implements AttachmentPicker {
  @override
  Future<List<ChatAttachment>> pickImages() =>
      _pick(type: FileType.image, kind: ChatAttachmentKind.image);

  @override
  Future<List<ChatAttachment>> pickFiles() =>
      _pick(type: FileType.any, kind: ChatAttachmentKind.file);

  Future<List<ChatAttachment>> _pick({
    required FileType type,
    required ChatAttachmentKind kind,
  }) async {
    final files = await FilePicker.pickFiles(
      type: type,
      compressionQuality: 85,
    );
    if (files.isEmpty) return const [];

    final now = DateTime.now().microsecondsSinceEpoch;
    final attachments = <ChatAttachment>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final path = file.path;
      if (path == null) continue;
      attachments.add(
        ChatAttachment(
          id: '$now-$index-${file.name}',
          name: file.name,
          path: path,
          sizeBytes: await file.length() ?? 0,
          kind: kind == ChatAttachmentKind.image || _isImage(file.name)
              ? ChatAttachmentKind.image
              : ChatAttachmentKind.file,
          mimeType: _mimeTypeFor(file.extension),
        ),
      );
    }
    return attachments;
  }

  static bool _isImage(String name) {
    final extension = name.split('.').last.toLowerCase();
    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'heif',
      'bmp',
    }.contains(extension);
  }

  static String? _mimeTypeFor(String? extension) {
    return switch (extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      _ => null,
    };
  }
}

final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => FileAttachmentPicker(),
);
