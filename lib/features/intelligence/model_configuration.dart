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

  @override
  Future<ModelConfiguration> build() async {
    final revision = _revision;
    final store = ref.watch(modelConfigStoreProvider);
    final next = ModelConfiguration.validate(await store.readPath());
    // A selection or removal can finish while the startup read is pending.
    if (revision != _revision) return state.value ?? next;
    return next;
  }

  Future<void> setPath(String path) async {
    final revision = ++_revision;
    final next = ModelConfiguration.validate(path);
    await ref.read(modelConfigStoreProvider).writePath(path);
    if (ref.mounted && revision == _revision) state = AsyncData(next);
  }

  Future<void> clear() async {
    final revision = ++_revision;
    await ref.read(modelConfigStoreProvider).writePath(null);
    if (ref.mounted && revision == _revision) {
      state = const AsyncData(ModelConfiguration.notConfigured());
    }
  }

  /// Re-checks the saved path so a file removed after selection is reported
  /// before the runtime sees it.
  Future<void> revalidate() async {
    final revision = ++_revision;
    final path = await ref.read(modelConfigStoreProvider).readPath();
    final next = ModelConfiguration.validate(path);
    if (ref.mounted && revision == _revision) state = AsyncData(next);
  }
}

final modelConfigurationProvider =
    AsyncNotifierProvider<ModelConfigurationController, ModelConfiguration>(
      ModelConfigurationController.new,
    );
