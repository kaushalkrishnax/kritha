import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:litertlm/litertlm.dart' as lite;

import '../../../../models/model_record.dart';
import '../../intelligence_exception.dart';
import '../../models/ai_input.dart';
import '../../models/ai_request.dart';
import '../../models/ai_response.dart';
import '../../models/model_capabilities.dart';
import '../../models/task_registry.dart';
import '../../inference_provider.dart';
import '../../request_validation.dart';

/// Engine-level seam over litertlm to test mappings and errors without native
/// libraries.
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
        // Disposing a failed conversation is best-effort.
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

/// Local LiteRT-LM provider. Executes models through the on-device LiteRT-LM
/// runtime; never makes network requests.
class LiteRtLmLocalProvider implements InferenceProvider {
  static const providerAlias = 'local-litertlm';

  LiteRtLmLocalProvider({
    required this.config,
    required this.createEngine,
    required this.localModels,
  }) : _lifecycle = ValueNotifier(const EngineLifecycle.ready());

  @override
  final ProviderConfig config;
  final LiteRtLmEngine Function(String modelPath) createEngine;
  final Future<List<ModelRecord>> Function() localModels;

  final ValueNotifier<EngineLifecycle> _lifecycle;
  LiteRtLmEngine? _engine;
  String? _engineModelPath;
  bool _disposed = false;

  @override
  String get alias => config.alias;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _engine != null;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    _lifecycle.value = const EngineLifecycle.ready();
  }

  static String? _primaryWeightsPath(ProviderModel model) {
    if (model.modelPath != null && model.modelPath!.trim().isNotEmpty) {
      return model.modelPath;
    }
    for (final artifact in model.artifacts) {
      final path = artifact.record.targetPath;
      if (path != null && path.trim().isNotEmpty && artifact.record.kind == 'weights') {
        return path;
      }
    }
    for (final artifact in model.artifacts) {
      final path = artifact.record.targetPath;
      if (path != null && path.trim().isNotEmpty) return path;
    }
    return null;
  }

  Future<void> _ensureEngine(String modelPath) async {
    if (_disposed) return;
    if (_engine != null && _engineModelPath == modelPath) return;
    await _disposeEngine();
    _engineModelPath = modelPath;
    _engine = createEngine(modelPath);
    await _engine!.initialize();
    if (_disposed) {
      await _disposeEngine();
      throw ProviderUnavailableException(
        'The LiteRT-LM provider was disposed while loading.',
        providerId: alias,
      );
    }
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
  }

  @override
  Future<AiResponse> generate(AiRequest request, ProviderModel model) async {
    _ensureSupported(request, model);
    _ensureNotDisposed();
    final path = _primaryWeightsPath(model);
    if (path == null || path.trim().isEmpty) {
      throw ProviderUnavailableException(
        'No model file is available for ${model.displayName}.',
        providerId: alias,
      );
    }
    await _ensureEngine(path);
    _ensureNotDisposed();
    final engine = _engine;
    if (engine == null) {
      throw ProviderUnavailableException(
        'The LiteRT-LM engine is not loaded.',
        providerId: alias,
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final text = await engine.complete(
        conversation: _conversationFor(request),
        message: _lastTurnMessage(request),
      );
      stopwatch.stop();
      return AiResponse(
        text: text,
        modelId: model.id,
        latency: stopwatch.elapsed,
      );
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      await _discardAfterGenerationFailure();
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request, ProviderModel model) {
    _ensureSupported(request, model);
    _ensureNotDisposed();

    late StreamController<AiResponse> controller;
    StreamSubscription<String>? subscription;
    var cancelled = false;

    Future<void> stop() async {
      final active = subscription;
      subscription = null;
      try {
        await active?.cancel();
      } on Object {
        // Engine stream may already be closed.
      }
    }

    controller = StreamController<AiResponse>(
      onListen: () async {
        try {
          final path = _primaryWeightsPath(model);
          if (path == null || path.trim().isEmpty) {
            throw ProviderUnavailableException(
              'No model file is available for ${model.displayName}.',
              providerId: alias,
            );
          }
          await _ensureEngine(path);
          if (cancelled) return;
          final engine = _engine;
          if (engine == null) {
            throw ProviderUnavailableException(
              'The LiteRT-LM engine is not loaded.',
              providerId: alias,
            );
          }
          final stopwatch = Stopwatch()..start();
          final buffer = StringBuffer();
          subscription = engine
              .stream(
                conversation: _conversationFor(request),
                message: _lastTurnMessage(request),
              )
              .listen(
                (delta) {
                  if (delta.isEmpty || cancelled) return;
                  buffer.write(delta);
                  controller.add(
                    AiResponse(
                      text: buffer.toString(),
                      modelId: model.id,
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
  Future<List<DiscoveredModel>> discoverModels() async {
    final models = await localModels();
    return [
      for (final model in models)
        DiscoveredModel(
          externalModelId: model.externalModelId,
          displayName: model.displayName,
          capabilities: _capabilitiesFor(model.tasks),
          tasks: model.tasks,
          metadata: model.metadata,
        ),
    ];
  }

  @override
  Future<ProviderTestResult> test() async {
    // The local provider never contacts a remote URL. Verify the LiteRT-LM
    // runtime is available and a configured model can initialize.
    try {
      final models = await localModels();
      if (models.isEmpty) {
        return const ProviderTestResult(
          ok: true,
          message: 'Local LiteRT-LM runtime is available.',
        );
      }
      final path = _primaryWeightsPath(
        ProviderModel(
          id: models.first.id,
          providerId: models.first.providerId,
          externalModelId: models.first.externalModelId,
          displayName: models.first.displayName,
          capabilities: _capabilitiesFor(models.first.tasks),
          tasks: models.first.tasks,
          modelPath: null,
          artifacts: const [],
          metadata: models.first.metadata,
        ),
      );
      if (path == null || path.trim().isEmpty) {
        return const ProviderTestResult(
          ok: false,
          message: 'No LiteRT-LM model artifact is configured.',
        );
      }
      final engine = createEngine(path);
      await engine.initialize();
      await engine.dispose();
      return const ProviderTestResult(
        ok: true,
        message: 'Local LiteRT-LM runtime is available and initialized.',
      );
    } on Object {
      return const ProviderTestResult(
        ok: false,
        message: 'The LiteRT-LM runtime could not be initialized.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _disposeEngine();
    if (_lifecycle.value.stage != EngineLifecycleStage.disposed) {
      _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
    }
  }

  Future<void> _disposeEngine() async {
    final engine = _engine;
    _engine = null;
    _engineModelPath = null;
    if (engine != null) {
      try {
        await engine.dispose();
      } on Object {
        // Native teardown failure must not mask original failure.
      }
    }
  }

  Future<void> _discardAfterGenerationFailure() async {
    if (_engine == null) return;
    await _disposeEngine();
    if (!_disposed) {
      _lifecycle.value = const EngineLifecycle(
        EngineLifecycleStage.unavailable,
        message: 'The local engine stopped after a generation failure.',
      );
    }
  }

  void _ensureSupported(AiRequest request, ProviderModel model) {
    const AiRequestValidator().validate(request);

    final requestedModel = request.modelId;
    if (requestedModel != null && requestedModel != model.id) {
      throw ProviderUnavailableException(
        'This provider serves ${model.id}, not "$requestedModel".',
        providerId: alias,
      );
    }

    final missing = request.requiredCapabilities
        .where((capability) => !model.capabilities.contains(capability))
        .toSet();
    if (missing.isNotEmpty) {
      throw UnsupportedCapabilityException(providerId: alias, missing: missing);
    }

    if (request.responseSchema != null) {
      throw UnsupportedCapabilityException(
        providerId: alias,
        missing: const {InferenceCapability.structuredOutput},
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw ProviderUnavailableException(
        'The LiteRT-LM provider has been disposed.',
        providerId: alias,
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

  lite.Message _lastTurnMessage(AiRequest request) {
    final last = request.messages.last;
    if (request.inputs.isEmpty) return _messageFor(last);
    final parts = <lite.Content>[
      lite.Content.text(last.text),
      for (final input in request.inputs)
        if (input is AiImageInput)
          lite.Content.imageBytes(input.bytes)
        else if (input is AiAudioInput)
          lite.Content.audioBytes(input.bytes),
    ];
    return lite.Message.userContents(lite.Contents(parts));
  }

  lite.Message _messageFor(AiMessage message) => switch (message.role) {
        AiRole.system => lite.Message.system(message.text),
        AiRole.user => lite.Message.user(message.text),
        AiRole.assistant => lite.Message.modelText(message.text),
      };

  IntelligenceException _mapError(Object error) {
    if (error is IntelligenceException) return error;
    if (error is lite.LiteRtLmException) {
      return InferenceFailedException(
        'LiteRT-LM could not complete the request.',
        providerId: alias,
        cause: error,
      );
    }
    if (error is UnsupportedError) {
      return ProviderUnavailableException(
        'This platform cannot run LiteRT-LM.',
        providerId: alias,
        cause: error,
      );
    }
    return InferenceFailedException(
      'LiteRT-LM failed unexpectedly.',
      providerId: alias,
      cause: error,
    );
  }
}

Set<InferenceCapability> _capabilitiesFor(List<TaskDeclaration> tasks) {
  final result = <InferenceCapability>{};
  for (final declaration in tasks) {
    result.addAll(capabilitiesForTask(declaration.task));
  }
  return result;
}
