import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kritha/features/intelligence/inference_provider.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/ai_response.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/model_descriptor.dart';
import 'package:kritha/features/intelligence/runtimes/litertlm_provider.dart';

const testModelDescriptor = ModelDescriptor(
  id: 'test-model',
  displayName: 'Test model',
  runtimeId: LiteRtLmProvider.providerId,
  capabilities: ModelCapabilities.textOnly,
  modelPath: '/models/test.litertlm',
);

class InMemoryModelConfigStore implements ModelConfigStore {
  InMemoryModelConfigStore([this.path]);

  String? path;

  @override
  Future<String?> readPath() async => path;

  @override
  Future<void> writePath(String? path) async {
    this.path = path?.trim();
  }
}

/// Deterministic provider for engine, controller and widget tests.
class FakeInferenceProvider implements InferenceProvider {
  FakeInferenceProvider({
    this.descriptor = testModelDescriptor,
    this.chunks = const ['Fake reply.'],
    this.error,
    this.initializeError,
  });

  @override
  final ModelDescriptor descriptor;

  final List<String> chunks;
  Object? error;
  Object? initializeError;

  AiRequest? lastRequest;
  int streamCalls = 0;
  int generateCalls = 0;
  int disposeCalls = 0;
  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.fileReady(),
  );

  @override
  String get id => descriptor.runtimeId;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isInitialized;

  @override
  Future<void> initialize() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initializing);
    final failure = initializeError;
    if (failure != null) {
      _lifecycle.value = const EngineLifecycle(
        EngineLifecycleStage.initializationFailed,
        message: 'The fake engine could not initialize.',
      );
      throw failure;
    }
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    generateCalls += 1;
    lastRequest = request;
    await initialize();
    final failure = error;
    if (failure != null) {
      _lifecycle.value = const EngineLifecycle(
        EngineLifecycleStage.unavailable,
        message: 'The fake engine stopped.',
      );
      throw failure;
    }
    return AiResponse(
      text: chunks.join(),
      modelId: descriptor.id,
      latency: Duration.zero,
    );
  }

  @override
  Stream<AiResponse> stream(AiRequest request) async* {
    streamCalls += 1;
    lastRequest = request;
    await initialize();

    final buffer = StringBuffer();
    for (final chunk in chunks) {
      final failure = error;
      if (failure != null) {
        _lifecycle.value = const EngineLifecycle(
          EngineLifecycleStage.unavailable,
          message: 'The fake engine stopped.',
        );
        throw failure;
      }
      buffer.write(chunk);
      yield AiResponse(
        text: buffer.toString(),
        modelId: descriptor.id,
        latency: Duration.zero,
      );
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
  }
}

/// Provider whose output is pushed by the test, for streaming/cancel flows.
class ManualInferenceProvider implements InferenceProvider {
  ManualInferenceProvider({this.descriptor = testModelDescriptor});

  @override
  final ModelDescriptor descriptor;

  AiRequest? lastRequest;
  bool cancelled = false;
  bool throwOnCancel = false;
  int streamCalls = 0;
  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.fileReady(),
  );
  StreamController<AiResponse>? _controller;

  bool get isListening => _controller?.hasListener ?? false;

  @override
  String get id => descriptor.runtimeId;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isInitialized;

  @override
  Future<void> initialize() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
  }

  @override
  Future<AiResponse> generate(AiRequest request) {
    throw UnsupportedError('Use stream in manual streaming tests.');
  }

  @override
  Stream<AiResponse> stream(AiRequest request) {
    streamCalls += 1;
    lastRequest = request;
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
    cancelled = false;
    final controller = StreamController<AiResponse>(
      onCancel: () async {
        cancelled = true;
        if (throwOnCancel) throw StateError('cancel failed');
      },
    );
    _controller = controller;
    return controller.stream;
  }

  void emit(String text) {
    _controller?.add(
      AiResponse(text: text, modelId: descriptor.id, latency: Duration.zero),
    );
  }

  Future<void> fail(Object error) async {
    final controller = _controller;
    if (controller == null) return;
    controller.addError(error);
    await controller.close();
  }

  Future<void> finish() async {
    await _controller?.close();
  }

  @override
  Future<void> dispose() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
    await _controller?.close();
  }
}
