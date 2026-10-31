import 'dart:io';

/// Attachment kind; composer distinguishes images from generic files.
enum ChatAttachmentKind { image, file }

/// Selected attachment copied to temporary cache with persisted metadata.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.kind,
    this.mimeType,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final ChatAttachmentKind kind;
  final String? mimeType;

  bool get isImage => kind == ChatAttachmentKind.image;

  bool get exists => path.isNotEmpty && File(path).existsSync();

  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'sizeBytes': sizeBytes,
    'kind': kind.name,
    'mimeType': mimeType,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'attachment',
      path: json['path'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      kind: json['kind'] == ChatAttachmentKind.image.name
          ? ChatAttachmentKind.image
          : ChatAttachmentKind.file,
      mimeType: json['mimeType'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatAttachment &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.sizeBytes == sizeBytes &&
        other.kind == kind &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode => Object.hash(id, name, path, sizeBytes, kind, mimeType);
}
