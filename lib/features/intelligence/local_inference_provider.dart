import 'dart:async';

import 'package:flutter/foundation.dart';

import 'inference_provider.dart';
import 'intelligence_exception.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_descriptor.dart';
import 'runtime_registry.dart';

class LocalInferenceProvider implements InferenceProvider {
  LocalInferenceProvider({
    required this.descriptor,
    required this.registry,
    this.artifacts = const [],
    this.platform,
    this.providerId,
  });

  @override
  final ModelDescriptor descriptor;
  final RuntimeRegistry registry;
  final List<LocalModelArtifact> artifacts;
  final String? platform;
  final String? providerId;

  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.fileReady(),
  );
  LocalRuntime? _runtime;
  Future<void>? _initialization;
  bool _disposed = false;

  @override
  String get id => providerId ?? descriptor.runtimeId;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isInitialized;

  @override
  Future<void> initialize() async {
    _ensureUsable();
    if (isInitialized) return;
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initialize();
    _initialization = operation;
    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) _initialization = null;
    }
  }

  Future<void> _initialize() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initializing);
    try {
      final registration = registry.select(
        model: descriptor,
        request: AiRequest(messages: [AiMessage.user('runtime probe')]),
        artifacts: artifacts,
        platform: platform,
      );
      final runtime = registration.create(descriptor, artifacts);
      await runtime.initialize();
      if (_disposed) {
        await runtime.dispose();
        throw ProviderUnavailableException(
          'The local provider was disposed while loading.',
          providerId: id,
        );
      }
      _runtime = runtime;
      if (!_disposed) {
        _lifecycle.value = const EngineLifecycle(
          EngineLifecycleStage.initialized,
        );
      }
    } on Object catch (error) {
      if (!_disposed) {
        _lifecycle.value = EngineLifecycle(
          EngineLifecycleStage.initializationFailed,
          message: error is UnsupportedError
              ? 'This platform cannot run the selected local runtime.'
              : 'The local runtime could not be initialized.',
        );
      }
      if (error is IntelligenceException) rethrow;
      throw ProviderUnavailableException(
        'No compatible local runtime is available for ${descriptor.id}.',
        providerId: id,
        cause: error,
      );
    }
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    _ensureUsable();
    await initialize();
    final runtime = _runtime;
    if (runtime == null) {
      throw ProviderUnavailableException(
        'The local runtime is not loaded.',
        providerId: id,
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final text = await runtime.generate(request);
      stopwatch.stop();
      return AiResponse(
        text: text,
        modelId: descriptor.id,
        latency: stopwatch.elapsed,
      );
    } on Object catch (error, stackTrace) {
      await _discardRuntimeAfterFailure();
      Error.throwWithStackTrace(
        InferenceFailedException(
          'Local inference failed for ${descriptor.id}.',
          providerId: id,
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request) {
    _ensureUsable();
    late StreamController<AiResponse> controller;
    StreamSubscription<String>? subscription;
    var cancelled = false;

    Future<void> cancel() async {
      cancelled = true;
      await subscription?.cancel();
      subscription = null;
    }

    controller = StreamController<AiResponse>(
      onListen: () async {
        try {
          await initialize();
          if (cancelled) return;
          final runtime = _runtime;
          if (runtime == null) {
            throw StateError('Local runtime is unavailable.');
          }
          final buffer = StringBuffer();
          subscription = runtime
              .stream(request)
              .listen(
                (chunk) {
                  if (cancelled) return;
                  buffer.write(chunk);
                  controller.add(
                    AiResponse(
                      text: buffer.toString(),
                      modelId: descriptor.id,
                      latency: Duration.zero,
                    ),
                  );
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                },
                onDone: () async {
                  await subscription?.cancel();
                  if (!controller.isClosed) await controller.close();
                },
                cancelOnError: true,
              );
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
            await controller.close();
          }
        }
      },
      onCancel: cancel,
    );
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final runtime = _runtime;
    _runtime = null;
    await runtime?.dispose();
    if (_lifecycle.value.stage != EngineLifecycleStage.disposed) {
      _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
    }
  }

  Future<void> _discardRuntimeAfterFailure() async {
    final runtime = _runtime;
    _runtime = null;
    await runtime?.dispose();
    if (!_disposed) {
      _lifecycle.value = const EngineLifecycle(
        EngineLifecycleStage.unavailable,
        message: 'The local runtime stopped after an inference failure.',
      );
    }
  }

  void _ensureUsable() {
    if (_disposed) {
      throw ProviderUnavailableException(
        'The local provider has been disposed.',
        providerId: id,
      );
    }
  }
}
