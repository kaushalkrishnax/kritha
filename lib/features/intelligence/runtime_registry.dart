import 'dart:io';

import 'models/ai_request.dart';
import 'models/model_capabilities.dart';
import 'models/model_descriptor.dart';

class LocalModelArtifact {
  const LocalModelArtifact({required this.path, this.format, this.sizeBytes});

  final String path;
  final String? format;
  final int? sizeBytes;
}

class RuntimeCompatibility {
  const RuntimeCompatibility({required this.compatible, this.reason});

  final bool compatible;
  final String? reason;

  const RuntimeCompatibility.ok() : this(compatible: true);

  const RuntimeCompatibility.incompatible(String reason)
    : this(compatible: false, reason: reason);
}

abstract interface class LocalRuntime {
  Future<void> initialize();
  Future<String> generate(AiRequest request);
  Stream<String> stream(AiRequest request);
  Future<void> dispose();
}

typedef LocalRuntimeFactory = LocalRuntime Function(
  ModelDescriptor model,
  List<LocalModelArtifact> artifacts,
);

class RuntimeRegistration {
  const RuntimeRegistration({
    required this.id,
    required this.displayName,
    required this.tasks,
    required this.modalities,
    required this.platforms,
    required this.formats,
    required this.isAvailable,
    required this.compatibility,
    required this.create,
  });

  final String id;
  final String displayName;
  final Set<InferenceCapability> tasks;
  final Set<String> modalities;
  final Set<String> platforms;
  final Set<String> formats;
  final bool Function() isAvailable;
  final RuntimeCompatibility Function(
    ModelDescriptor model,
    AiRequest request,
    List<LocalModelArtifact> artifacts,
  )
  compatibility;
  final LocalRuntimeFactory create;
}

class RuntimeRegistry {
  RuntimeRegistry({Iterable<RuntimeRegistration> registrations = const []}) {
    for (final registration in registrations) {
      register(registration);
    }
  }

  final Map<String, RuntimeRegistration> _registrations = {};

  Iterable<RuntimeRegistration> get registrations => _registrations.values;

  void register(RuntimeRegistration registration) {
    if (registration.id.trim().isEmpty) {
      throw ArgumentError.value(
        registration.id,
        'id',
        'Runtime ID is required.',
      );
    }
    if (_registrations.containsKey(registration.id)) {
      throw StateError('Runtime ${registration.id} is already registered.');
    }
    _registrations[registration.id] = registration;
  }

  RuntimeRegistration? registrationFor(String id) => _registrations[id];

  List<RuntimeRegistration> compatibleRuntimes({
    required ModelDescriptor model,
    required AiRequest request,
    required List<LocalModelArtifact> artifacts,
    String? platform,
  }) {
    final currentPlatform = platform ?? _currentPlatform;
    return [
      for (final registration in _registrations.values)
        if (registration.tasks.containsAll(request.requiredCapabilities) &&
            registration.platforms.contains(currentPlatform) &&
            registration.isAvailable())
          if (registration.compatibility(model, request, artifacts).compatible)
            registration,
    ];
  }

  RuntimeRegistration select({
    required ModelDescriptor model,
    required AiRequest request,
    required List<LocalModelArtifact> artifacts,
    String? platform,
  }) {
    final matches = compatibleRuntimes(
      model: model,
      request: request,
      artifacts: artifacts,
      platform: platform,
    );
    if (matches.isEmpty) {
      throw StateError(
        'No compatible runtime is available for ${model.id} and '
        '${request.requiredCapabilities.map((capability) => capability.name).join(', ')}.',
      );
    }
    matches.sort((a, b) => a.id.compareTo(b.id));
    return matches.first;
  }

  String get _currentPlatform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
