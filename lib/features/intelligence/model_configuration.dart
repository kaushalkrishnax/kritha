import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/model_capabilities.dart';
import 'models/model_descriptor.dart';
import 'runtimes/litertlm_provider.dart';

/// Where a selected model stands before any runtime work happens.
///
/// Configuration, engine loading and successful generation are deliberately
/// separate: [ready] only means the file is present and looks like a model.
enum ModelConfigurationStatus {
  notConfigured,
  missingFile,
  invalidFile,
  unreadableFile,
  ready,
}

/// A validated local model selection.
class ModelConfiguration {
  const ModelConfiguration._({
    required this.status,
    this.path,
    this.fileName,
    this.message,
    this.descriptor,
  });

  const ModelConfiguration.notConfigured()
    : this._(
        status: ModelConfigurationStatus.notConfigured,
        message: 'No local model is selected.',
      );

  final ModelConfigurationStatus status;
  final String? path;
  final String? fileName;
  final String? message;

  /// Present only when the file passed validation.
  final ModelDescriptor? descriptor;

  bool get isReady => descriptor != null;

  String get statusLabel => switch (status) {
    ModelConfigurationStatus.notConfigured => 'not configured',
    ModelConfigurationStatus.missingFile => 'file missing',
    ModelConfigurationStatus.invalidFile => 'invalid file',
    ModelConfigurationStatus.unreadableFile => 'unavailable',
    ModelConfigurationStatus.ready => 'file ready',
  };

  static const modelExtension = '.litertlm';

  /// Validates a persisted path without loading the runtime or the weights.
  static ModelConfiguration validate(String? rawPath) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return const ModelConfiguration.notConfigured();
    }

    final fileName = _fileName(path);

    FileStat stat;
    try {
      stat = File(path).statSync();
    } on FileSystemException {
      return ModelConfiguration._(
        status: ModelConfigurationStatus.unreadableFile,
        path: path,
        fileName: fileName,
        message: 'The selected model file cannot be read.',
      );
    }

    if (stat.type == FileSystemEntityType.notFound) {
      return ModelConfiguration._(
        status: ModelConfigurationStatus.missingFile,
        path: path,
        fileName: fileName,
        message: 'The selected model file no longer exists.',
      );
    }
    if (stat.type != FileSystemEntityType.file) {
      return ModelConfiguration._(
        status: ModelConfigurationStatus.invalidFile,
        path: path,
        fileName: fileName,
        message: 'The selected path is not a file.',
      );
    }
    if (!fileName.toLowerCase().endsWith(modelExtension)) {
      return ModelConfiguration._(
        status: ModelConfigurationStatus.invalidFile,
        path: path,
        fileName: fileName,
        message: 'Choose a LiteRT-LM model file ending in $modelExtension.',
      );
    }
    if (stat.size <= 0) {
      return ModelConfiguration._(
        status: ModelConfigurationStatus.invalidFile,
        path: path,
        fileName: fileName,
        message: 'The selected model file is empty.',
      );
    }

    final stem = fileName.substring(0, fileName.length - modelExtension.length);
    return ModelConfiguration._(
      status: ModelConfigurationStatus.ready,
      path: path,
      fileName: fileName,
      descriptor: ModelDescriptor(
        id: 'local:${stem.isEmpty ? 'model' : stem}',
        displayName: stem.isEmpty ? fileName : stem,
        runtimeId: LiteRtLmProvider.providerId,
        capabilities: ModelCapabilities.textOnly,
        modelPath: path,
      ),
    );
  }

  static String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}

abstract interface class ModelConfigStore {
  Future<String?> readPath();

  Future<void> writePath(String? path);
}

class SharedPreferencesModelConfigStore implements ModelConfigStore {
  const SharedPreferencesModelConfigStore();

  static const preferenceKey = 'kritha.model.path';

  @override
  Future<String?> readPath() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(preferenceKey);
  }

  @override
  Future<void> writePath(String? path) async {
    final preferences = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await preferences.remove(preferenceKey);
      return;
    }
    await preferences.setString(preferenceKey, path.trim());
  }
}

final modelConfigStoreProvider = Provider<ModelConfigStore>(
  (ref) => const SharedPreferencesModelConfigStore(),
);

class ModelConfigurationController extends AsyncNotifier<ModelConfiguration> {
  /// Guards against a slow read from overwriting a newer selection or removal.
  int _revision = 0;

  /// Serializes writes so two selections cannot land out of order.
  Future<void> _writes = Future<void>.value();

  /// Completes after the most recently started mutation or revalidation.
  Future<void> _latest = Future<void>.value();

  @override
  Future<ModelConfiguration> build() async {
    final revision = _revision;
    final store = ref.watch(modelConfigStoreProvider);
    await _writes;
    final next = ModelConfiguration.validate(await store.readPath());
    // A selection or removal can finish while the startup read is pending.
    if (revision != _revision) {
      await _settle();
      final current = state;
      if (current.hasError) {
        Error.throwWithStackTrace(current.error!, current.stackTrace!);
      }
      if (current.hasValue) return current.requireValue;
    }
    return next;
  }

  Future<void> setPath(String path) {
    final revision = ++_revision;
    return _track(
      _enqueueWrite(() async {
        try {
          final next = ModelConfiguration.validate(path);
          await ref.read(modelConfigStoreProvider).writePath(path);
          if (ref.mounted && revision == _revision) state = AsyncData(next);
        } on Object catch (error, stackTrace) {
          _publishError(revision, error, stackTrace);
          rethrow;
        }
      }),
    );
  }

  Future<void> clear() {
    final revision = ++_revision;
    return _track(
      _enqueueWrite(() async {
        try {
          await ref.read(modelConfigStoreProvider).writePath(null);
          if (ref.mounted && revision == _revision) {
            state = const AsyncData(ModelConfiguration.notConfigured());
          }
        } on Object catch (error, stackTrace) {
          _publishError(revision, error, stackTrace);
          rethrow;
        }
      }),
    );
  }

  /// Re-checks the saved path so a file removed after selection is reported
  /// before the runtime sees it. It waits for writes already in flight, but a
  /// newer write can still invalidate this read.
  Future<void> revalidate() {
    final revision = ++_revision;
    return _track(() async {
      try {
        await _writes;
        final path = await ref.read(modelConfigStoreProvider).readPath();
        final next = ModelConfiguration.validate(path);
        if (ref.mounted && revision == _revision) state = AsyncData(next);
      } on Object catch (error, stackTrace) {
        _publishError(revision, error, stackTrace);
        rethrow;
      }
    }());
  }

  Future<void> _track(Future<void> operation) {
    _latest = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _settle() async {
    while (true) {
      final latest = _latest;
      await latest;
      if (identical(latest, _latest)) return;
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    final previous = _writes;
    final done = Completer<void>();
    _writes = done.future;
    return () async {
      try {
        await previous;
        await action();
      } finally {
        done.complete();
      }
    }();
  }

  void _publishError(int revision, Object error, StackTrace stackTrace) {
    if (ref.mounted && revision == _revision) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final modelConfigurationProvider =
    AsyncNotifierProvider<ModelConfigurationController, ModelConfiguration>(
      ModelConfigurationController.new,
    );
