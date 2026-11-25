import 'dart:convert';
import 'dart:io';

import '../models/chat_attachment.dart';

const _extToMime = <String, String>{
  // Images
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
  // Video
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/mov',
  'webm': 'video/webm',
  'mkv': 'video/x-matroska',
  'avi': 'video/avi',
  '3gp': 'video/3gpp',
  '3gpp': 'video/3gpp',
  'mpeg': 'video/mpeg',
  'mpg': 'video/mpg',
  'flv': 'video/x-flv',
  'wmv': 'video/wmv',
  // Audio
  'mp3': 'audio/mp3',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'opus': 'audio/ogg',
  'flac': 'audio/flac',
  'aiff': 'audio/aiff',
  // Documents & text
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'json': 'application/json',
  'csv': 'text/csv',
  'xml': 'text/xml',
  'html': 'text/html',
  'htm': 'text/html',
  'yaml': 'text/yaml',
  'yml': 'text/yaml',
  'log': 'text/plain',
  'dart': 'text/plain',
  'py': 'text/plain',
  'js': 'text/javascript',
  'ts': 'text/plain',
  'zip': 'application/zip',
};

String normalizeMimeType(String mime) {
  final lower = mime.split(';').first.trim().toLowerCase();
  return switch (lower) {
    'audio/x-wav' => 'audio/wav',
    'audio/mpeg' => 'audio/mp3',
    'audio/x-m4a' => 'audio/mp4',
    'audio/x-aac' => 'audio/aac',
    'video/quicktime' => 'video/mov',
    _ => lower,
  };
}

/// Auto-detects MIME type from extension first, then magic-byte sniffing.
String detectMimeType({
  String? path,
  String? name,
  String? extension,
  List<int>? headerBytes,
}) {
  final ext =
      (extension ?? _extensionOf(name) ?? _extensionOf(path))?.toLowerCase();
  if (ext != null && _extToMime.containsKey(ext)) {
    return _extToMime[ext]!;
  }
  final bytes = headerBytes ?? _readHeaderSync(path);
  if (bytes != null && bytes.isNotEmpty) {
    final sniffed = _sniffMagicBytes(bytes);
    if (sniffed != null) return sniffed;
    if (_looksLikeText(bytes)) return 'text/plain';
  }
  return 'application/octet-stream';
}

ChatAttachmentKind attachmentKindForMime(String? mimeType, {String? name}) {
  final resolved = (mimeType != null &&
          mimeType.isNotEmpty &&
          mimeType != 'application/octet-stream')
      ? normalizeMimeType(mimeType)
      : detectMimeType(name: name);
  if (resolved.startsWith('image/')) return ChatAttachmentKind.image;
  if (resolved.startsWith('video/')) return ChatAttachmentKind.video;
  if (resolved.startsWith('audio/')) return ChatAttachmentKind.audio;
  return ChatAttachmentKind.file;
}

String? _extensionOf(String? fileNameOrPath) {
  if (fileNameOrPath == null || fileNameOrPath.isEmpty) return null;
  final base = fileNameOrPath.split(RegExp(r'[/\\]')).last;
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return null;
  return base.substring(dot + 1);
}

List<int>? _readHeaderSync(String? path) {
  if (path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final raf = file.openSync();
    try {
      return raf.readSync(64);
    } finally {
      raf.closeSync();
    }
  } on Object {
    return null;
  }
}

String? _sniffMagicBytes(List<int> b) {
  if (b.length >= 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46) {
    return 'application/pdf';
  }
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (b.length >= 4 &&
      b[0] == 0x47 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x38) {
    return 'image/gif';
  }
  if (b.length >= 12 &&
      _ascii(b, 0, 'RIFF') &&
      _ascii(b, 8, 'WEBP')) {
    return 'image/webp';
  }
  if (b.length >= 12 &&
      _ascii(b, 0, 'RIFF') &&
      _ascii(b, 8, 'WAVE')) {
    return 'audio/wav';
  }
  if (b.length >= 12 &&
      _ascii(b, 0, 'RIFF') &&
      _ascii(b, 8, 'AVI ')) {
    return 'video/avi';
  }
  if (b.length >= 4 && _ascii(b, 0, 'OggS')) {
    return 'audio/ogg';
  }
  if (b.length >= 4 && _ascii(b, 0, 'fLaC')) {
    return 'audio/flac';
  }
  if (b.length >= 3 && _ascii(b, 0, 'ID3')) {
    return 'audio/mp3';
  }
  if (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
    return 'audio/mp3';
  }
  if (b.length >= 12 && _ascii(b, 4, 'ftyp')) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (brand.startsWith('M4A')) return 'audio/mp4';
    if (brand.startsWith('qt')) return 'video/mov';
    if (brand.startsWith('3gp')) return 'video/3gpp';
    return 'video/mp4';
  }
  if (b.length >= 4 &&
      b[0] == 0x1A &&
      b[1] == 0x45 &&
      b[2] == 0xDF &&
      b[3] == 0xA3) {
    return 'video/webm';
  }
  return null;
}

bool _ascii(List<int> bytes, int offset, String expected) {
  if (bytes.length < offset + expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected.codeUnitAt(i)) return false;
  }
  return true;
}

bool _looksLikeText(List<int> bytes) {
  try {
    utf8.decode(bytes, allowMalformed: false);
    for (final byte in bytes) {
      if (byte < 0x09 || (byte > 0x0D && byte < 0x20)) return false;
    }
    return true;
  } on FormatException {
    return false;
  }
}
