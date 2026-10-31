import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalogue/catalogue_providers.dart';
import '../catalogue/hugging_face_hub_client.dart';

/// Owns the files for one model configuration.
///
/// Every configuration gets its own root; rows only store paths relative to
/// that root, so two configurations can never share a physical artifact.
abstract interface class ModelArtifactStorage {
  String get rootPath;

  String resolve(String targetPath);

  Future<void> copyFile(String sourcePath, String targetPath);

  Future<void> moveFile(String sourcePath, String targetPath);

  Future<void> deleteFile(String path);
}

class FileModelArtifactStorage implements ModelArtifactStorage {
  const FileModelArtifactStorage(this.rootPath);

  @override
  final String rootPath;

  static String rootFor({
    required String documentsPath,
    required String repositoryId,
    required String configurationId,
  }) {
    final base = documentsPath.trim();
    if (base.isEmpty) return '';
    final repository = _safeSegment(repositoryId);
    final configuration = _safeSegment(configurationId);
    return [
      base,
      'model_artifacts',
      repository,
      configuration,
    ].join(Platform.pathSeparator);
  }

  @override
  String resolve(String targetPath) {
    final relative = normalizeArtifactTarget(targetPath);
    if (relative == null || rootPath.isEmpty) return '';
    return [rootPath, relative].join(Platform.pathSeparator);
  }

  @override
  Future<void> copyFile(String sourcePath, String targetPath) async {
    final destination = resolve(targetPath);
    if (destination.isEmpty) {
      throw const FileSystemException('The artifact path is not valid.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'The source file no longer exists.',
        sourcePath,
      );
    }
    final file = File(destination);
    await file.parent.create(recursive: true);
    await source.copy(destination);
  }

  @override
  Future<void> moveFile(String sourcePath, String targetPath) async {
    final destination = resolve(targetPath);
    if (destination.isEmpty) {
      throw const FileSystemException('The artifact path is not valid.');
    }
    if (sourcePath == destination) return;
    final source = File(sourcePath);
    if (!await source.exists()) return;
    final file = File(destination);
    await file.parent.create(recursive: true);
    await source.rename(destination);
  }

  @override
  Future<void> deleteFile(String path) async {
    if (path.trim().isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String _safeSegment(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'configuration' : cleaned;
  }
}

/// Returns a normalized, configuration-relative path, or `null` when the
/// supplied path could escape the configuration root.
String? normalizeArtifactTarget(String raw) {
  final normalized = raw.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return null;
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList(growable: false);
  if (segments.isEmpty || segments.any((segment) => segment == '..')) {
    return null;
  }
  return segments.join(Platform.pathSeparator);
}

/// One in-flight resumable transfer.
///
/// Pausing stops the network read but keeps the bytes already written, so
/// [resume] continues from the partial file instead of starting again.
abstract interface class ModelArtifactDownload {
  Future<void> get done;

  bool get isPaused;

  void pause();

  void resume();
}

abstract interface class ModelArtifactDownloader {
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  });
}

class HubArtifactDownloader implements ModelArtifactDownloader {
  const HubArtifactDownloader(this._client);

  final HuggingFaceHubClient _client;

  @override
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    return _HubDownload(
      client: _client,
      repositoryId: repositoryId,
      revision: revision,
      path: path,
      destinationPath: destinationPath,
      onProgress: onProgress,
    );
  }
}

class _HubDownload implements ModelArtifactDownload {
  _HubDownload({
    required this.client,
    required this.repositoryId,
    required this.revision,
    required this.path,
    required this.destinationPath,
    required this.onProgress,
  }) {
    _done = _run();
  }

  final HuggingFaceHubClient client;
  final String repositoryId;
  final String revision;
  final String path;
  final String destinationPath;
  final void Function(int received, int total) onProgress;

  late final Future<void> _done;
  bool _paused = false;
  Completer<void>? _resume;

  @override
  Future<void> get done => _done;

  @override
  bool get isPaused => _paused;

  @override
  void pause() {
    if (_paused) return;
    _paused = true;
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;
    final pending = _resume;
    _resume = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> _run() async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();

    int? total;
    while (true) {
      if (_paused) {
        await _waitForResume();
        continue;
      }

      final offset = await _length(file);
      final chunk = await client.openDownload(
        repositoryId: repositoryId,
        revision: revision,
        path: path,
        offset: offset,
      );
      if (chunk.totalBytes != null && chunk.totalBytes! > 0) {
        total = chunk.totalBytes;
      }

      var start = chunk.startOffset;
      if (start == 0 && offset > 0) {
        // The server ignored the range request, so the partial file cannot be
        // appended to without duplicating bytes.
        await file.writeAsBytes(const []);
        start = 0;
      }

      final sink = await file.open(mode: FileMode.append);
      var written = 0;
      try {
        await for (final bytes in chunk.stream) {
          if (_paused) break;
          await sink.writeFrom(bytes);
          written += bytes.length;
          onProgress(start + written, total ?? start + written);
        }
      } finally {
        await sink.close();
        chunk.cancel();
      }

      if (_paused) continue;
      final received = start + written;
      if (total != null && received >= total) return;
      if (written == 0) {
        if (total != null && received >= total) return;
        throw const FileSystemException(
          'The download ended before the file was complete.',
        );
      }
    }
  }

  Future<void> _waitForResume() async {
    if (!_paused) return;
    final pending = Completer<void>();
    _resume = pending;
    await pending.future;
  }

  Future<int> _length(File file) async {
    try {
      return await file.exists() ? await file.length() : 0;
    } on FileSystemException {
      return 0;
    }
  }
}

final modelArtifactDownloaderProvider = Provider<ModelArtifactDownloader>((
  ref,
) {
  return HubArtifactDownloader(ref.watch(huggingFaceHubClientProvider));
});
