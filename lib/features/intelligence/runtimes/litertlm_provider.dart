import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:litertlm/litertlm.dart' as lite;

import '../inference_provider.dart';
import '../intelligence_exception.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/model_capabilities.dart';
import '../models/model_descriptor.dart';
import '../request_validation.dart';
import '../runtime_ids.dart';

/// Engine-level seam over litertlm to test mappings and errors without native libs.
abstract interface class LiteRtLmEngine {
  Future<void> initialize();

  Future<String> complete({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  });

  /// Streams text fragments for one turn; cancelling aborts native generation.
  Stream<String> stream({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  });

  Future<void> dispose();
}

/// Real LiteRT-LM engine; native initialization is deferred until execution.
class NativeLiteRtLmEngine implements LiteRtLmEngine {
  NativeLiteRtLmEngine({
    required this.modelPath,
    this.backend = const lite.Backend.cpu(),
  });

  final String modelPath;
  final lite.Backend backend;

  lite.Engine? _engine;

  @override
  Future<void> initialize() async {
    if (_engine != null) return;
    final engine = lite.Engine(
      engineConfig: lite.EngineConfig(modelPath: modelPath, backend: backend),
    );
    try {
      await engine.initialize();
    } on Object {
      await engine.dispose();
      rethrow;
    }
    _engine = engine;
  }

  @override
  Future<String> complete({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw StateError('The LiteRT-LM engine has not been initialized.');
    }
    final active = await engine.createConversation(conversation);
    try {
      final response = await active.sendMessage(message);
      return response.text;
    } finally {
      await active.dispose();
    }
  }

  @override
  Stream<String> stream({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) {
    final engine = _engine;
    if (engine == null) {
      return Stream.error(
        StateError('The LiteRT-LM engine has not been initialized.'),
      );
    }

    late StreamController<String> controller;
    StreamSubscription<lite.Message>? subscription;
    lite.Conversation? active;
    var cleanedUp = false;

    Future<void> cleanup() async {
      if (cleanedUp) return;
      cleanedUp = true;
      final current = subscription;
      subscription = null;
      // Teardown must not replace stream outcome with a cancel error.
      try {
        await current?.cancel();
      } on Object {
        // Native stream may already be closed.
      }
      final conversation = active;
      active = null;
      try {
        await conversation?.dispose();
      } on Object {
        // Disposing failed conversation is best-effort.
      }
    }

    controller = StreamController<String>(
      onListen: () async {
        try {
          final created = await engine.createConversation(conversation);
          if (cleanedUp) {
            await created.dispose();
            return;
          }
          active = created;
          subscription = created
              .sendMessageStream(message)
              .listen(
                (chunk) {
                  if (!chunk.isEmpty) controller.add(chunk.text);
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                    unawaited(controller.close());
                  }
                },
                onDone: () {
                  if (!controller.isClosed) unawaited(controller.close());
                },
                cancelOnError: true,
              );
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
            await controller.close();
          }
          await cleanup();
        }
      },
      onCancel: cleanup,
    );
    unawaited(controller.done.whenComplete(cleanup));

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}

/// Text-generation provider backed by LiteRT-LM; creates conversation per request.
class LiteRtLmProvider implements InferenceProvider {
  LiteRtLmProvider({required this.descriptor, required this.createEngine});

  /// Runtime identifier used by descriptors and persisted assignments.
  static const providerId = localRuntimeId;

  /// Source identifier used by the provider graph and Active Models.
  static const sourceId = localProviderId;

  @override
  final ModelDescriptor descriptor;
  final LiteRtLmEngine Function() createEngine;

  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.fileReady(),
  );

  LiteRtLmEngine? _engine;
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool _disposed = false;

  @override
  String get id => sourceId;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isInitialized;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (isInitialized) return;
    final pending = _initialization;
    if (pending != null) return pending;

    final path = descriptor.modelPath;
    if (path == null || path.trim().isEmpty) {
      _publish(
        const EngineLifecycle(
          EngineLifecycleStage.initializationFailed,
          message: 'No model file is configured.',
        ),
      );
      throw ProviderUnavailableException(
        'No model file is configured for ${descriptor.id}.',
        providerId: id,
      );
    }

    final future = _start();
    _initialization = future;
    try {
      await future;
    } finally {
      if (identical(_initialization, future)) _initialization = null;
    }
  }

  Future<void> _start() async {
    _ensureNotDisposed();
    _publish(const EngineLifecycle(EngineLifecycleStage.initializing));
    try {
      final engine = createEngine();
      _engine = engine;
      await engine.initialize();
      if (_disposed) {
        throw ProviderUnavailableException(
          'The LiteRT-LM provider was disposed while loading.',
          providerId: id,
        );
      }
      _publish(const EngineLifecycle(EngineLifecycleStage.initialized));
    } on Object catch (error) {
      await _discardEngine(
        stage: EngineLifecycleStage.initializationFailed,
        message: _initializationFailureFor(error),
      );
      rethrow;
    }
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    _ensureSupported(request);
    _ensureNotDisposed();

    await _run(method: () => initialize());
    _ensureNotDisposed();

    final engine = _engine;
    if (engine == null) {
      throw ProviderUnavailableException(
        'The LiteRT-LM engine is not loaded.',
        providerId: id,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final text = await engine.complete(
        conversation: _conversationFor(request),
        message: _messageFor(request.messages.last),
      );
      stopwatch.stop();
      return AiResponse(
        text: text,
        modelId: descriptor.id,
        latency: stopwatch.elapsed,
      );
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      await _discardAfterGenerationFailure();
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request) {
    _ensureSupported(request);
    _ensureNotDisposed();

    late StreamController<AiResponse> controller;
    StreamSubscription<String>? subscription;
    var cancelled = false;

    Future<void> stop() async {
      final active = subscription;
      subscription = null;
      // Cancelling native stream must not trigger unhandled background error.
      try {
        await active?.cancel();
      } on Object {
        // Engine stream may already be closed.
      }
    }

    controller = StreamController<AiResponse>(
      onListen: () async {
        try {
          await _run(method: () => initialize());
          if (cancelled) return;
          _ensureNotDisposed();

          final engine = _engine;
          if (engine == null) {
            throw ProviderUnavailableException(
              'The LiteRT-LM engine is not loaded.',
              providerId: id,
            );
          }

          final stopwatch = Stopwatch()..start();
          final buffer = StringBuffer();
          if (cancelled) return;
          subscription = engine
              .stream(
                conversation: _conversationFor(request),
                message: _messageFor(request.messages.last),
              )
              .listen(
                (delta) {
                  if (delta.isEmpty || cancelled) return;
                  buffer.write(delta);
                  controller.add(
                    AiResponse(
                      text: buffer.toString(),
                      modelId: descriptor.id,
                      latency: stopwatch.elapsed,
                    ),
                  );
                },
                onError: (Object error, StackTrace stackTrace) async {
                  stopwatch.stop();
                  if (cancelled) return;
                  await _discardAfterGenerationFailure();
                  if (controller.isClosed) return;
                  controller.addError(_mapError(error), stackTrace);
                  await controller.close();
                },
                onDone: () async {
                  stopwatch.stop();
                  if (controller.isClosed) return;
                  await controller.close();
                },
                cancelOnError: true,
              );
        } on Object catch (error, stackTrace) {
          if (cancelled) return;
          await _discardAfterGenerationFailure();
          if (controller.isClosed) return;
          controller.addError(_mapError(error), stackTrace);
          await controller.close();
        }
      },
      onCancel: () async {
        cancelled = true;
        await stop();
      },
    );
    unawaited(controller.done.whenComplete(stop));

    return controller.stream;
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _disposed = true;
    _publish(const EngineLifecycle(EngineLifecycleStage.disposed));
    return _disposal = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    final pending = _initialization;
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // Initialization expected to fail once disposal has begun.
      }
    }
    await _discardEngine();
  }

  void _publish(EngineLifecycle lifecycle) {
    if (_disposed && lifecycle.stage != EngineLifecycleStage.disposed) return;
    _lifecycle.value = lifecycle;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw ProviderUnavailableException(
        'The LiteRT-LM provider has been disposed.',
        providerId: id,
      );
    }
  }

  void _ensureSupported(AiRequest request) {
    const AiRequestValidator().validate(request);

    final requestedModel = request.modelId;
    if (requestedModel != null && requestedModel != descriptor.id) {
      throw ProviderUnavailableException(
        'This provider serves ${descriptor.id}, not "$requestedModel".',
        providerId: id,
      );
    }

    final missing = request.requiredCapabilities
        .where((capability) => !descriptor.capabilities.supports(capability))
        .toSet();
    if (missing.isNotEmpty) {
      throw UnsupportedCapabilityException(providerId: id, missing: missing);
    }

    // Reject structured generation explicitly even if descriptor over-declares it.
    if (request.responseSchema != null) {
      throw UnsupportedCapabilityException(
        providerId: id,
        missing: const {InferenceCapability.structuredOutput},
      );
    }
  }

  lite.ConversationConfig _conversationFor(AiRequest request) {
    final systemText = [
      for (final message in request.messages)
        if (message.role == AiRole.system) message.text.trim(),
    ].where((text) => text.isNotEmpty).join('\n\n');

    final turns = request.messages
        .where((message) => message.role != AiRole.system)
        .toList(growable: false);

    return lite.ConversationConfig(
      systemMessage: systemText.isEmpty
          ? null
          : lite.Message.system(systemText),
      initialMessages: [
        for (final message in turns.take(turns.length - 1))
          _messageFor(message),
      ],
      automaticToolCalling: false,
      sessionConfig: lite.SessionConfig(
        maxOutputTokens: request.options.maxOutputTokens,
        samplerConfig: lite.SamplerConfig(
          topK: request.options.topK,
          topP: request.options.topP,
          temperature: request.options.temperature,
          seed: request.options.seed,
        ),
      ),
    );
  }

  lite.Message _messageFor(AiMessage message) => switch (message.role) {
    AiRole.system => lite.Message.system(message.text),
    AiRole.user => lite.Message.user(message.text),
    AiRole.assistant => lite.Message.modelText(message.text),
  };

  Future<T> _run<T>({required Future<T> Function() method}) async {
    try {
      return await method();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    }
  }

  IntelligenceException _mapError(Object error) {
    if (error is IntelligenceException) return error;
    if (error is lite.LiteRtLmException) {
      return InferenceFailedException(
        'LiteRT-LM could not complete the request.',
        providerId: id,
        cause: error,
      );
    }
    if (error is UnsupportedError) {
      return ProviderUnavailableException(
        'This platform cannot run LiteRT-LM.',
        providerId: id,
        cause: error,
      );
    }
    return InferenceFailedException(
      'LiteRT-LM failed unexpectedly.',
      providerId: id,
      cause: error,
    );
  }

  String _initializationFailureFor(Object error) {
    if (error is UnsupportedError) {
      return 'This platform cannot run LiteRT-LM.';
    }
    if (error is ProviderUnavailableException) return error.message;
    return 'The local model could not be initialized.';
  }

  Future<void> _discardAfterGenerationFailure() async {
    // Initialization failures recorded by _start; avoid replacing with generation failure.
    if (!_lifecycle.value.isInitialized) return;
    await _discardEngine(
      message: 'The local engine stopped after a generation failure.',
    );
  }

  Future<void> _discardEngine({
    EngineLifecycleStage stage = EngineLifecycleStage.unavailable,
    String? message,
  }) async {
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.dispose();
      } on Object {
        // Native teardown failure must not mask original failure.
      }
    }
    if (!_disposed) _publish(EngineLifecycle(stage, message: message));
  }
}
