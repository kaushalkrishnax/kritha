import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/inference_provider.dart';
import 'package:kritha/features/intelligence/intelligence_engine.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/model_lifecycle.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/ai_response.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/model_descriptor.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/intelligence/request_router.dart';
import 'package:kritha/features/intelligence/runtimes/litertlm_provider.dart';
import 'package:litertlm/litertlm.dart' as lite;

import 'support/fake_inference.dart';

const _descriptor = ModelDescriptor(
  id: 'test-model',
  displayName: 'Test model',
  runtimeId: LiteRtLmProvider.providerId,
  capabilities: ModelCapabilities.textOnly,
  modelPath: '/models/test.litertlm',
);

AiRequest _prompt(String text) => AiRequest(messages: [AiMessage.user(text)]);

class _FakeLiteRtLmEngine implements LiteRtLmEngine {
  _FakeLiteRtLmEngine({
    this.text = 'Local answer.',
    this.chunks = const ['Local ', 'answer.'],
  });

  final String text;
  final List<String> chunks;
  Object? initializeError;
  Object? completeError;
  Object? streamError;
  Completer<void>? initializeGate;
  StreamController<String>? streamController;
  bool streamCancelled = false;
  int initializeCalls = 0;
  int disposeCalls = 0;
  lite.ConversationConfig? conversation;
  lite.Message? message;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    final gate = initializeGate;
    if (gate != null) await gate.future;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<String> complete({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) async {
    this.conversation = conversation;
    this.message = message;
    final error = completeError;
    if (error != null) throw error;
    return text;
  }

  @override
  Stream<String> stream({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) {
    this.conversation = conversation;
    this.message = message;

    final manual = streamController;
    if (manual != null) {
      manual.onCancel = () => streamCancelled = true;
      return manual.stream;
    }

    return _chunks();
  }

  Stream<String> _chunks() async* {
    final error = streamError;
    if (error != null) throw error;
    for (final chunk in chunks) {
      yield chunk;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

class _FakeInferenceProvider implements InferenceProvider {
  _FakeInferenceProvider({
    this.descriptor = _descriptor,
    this.result = 'Fake answer.',
  });

  @override
  final ModelDescriptor descriptor;

  final String result;
  AiRequest? lastRequest;
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
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    lastRequest = request;
    await initialize();
    return AiResponse(
      text: result,
      modelId: descriptor.id,
      latency: Duration.zero,
    );
  }

  @override
  Stream<AiResponse> stream(AiRequest request) async* {
    lastRequest = request;
    yield await generate(request);
  }

  @override
  Future<void> dispose() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
  }
}

void main() {
  group('request and response contracts', () {
    test('AiRequest round-trips and derives text capability', () {
      final request = AiRequest(
        messages: [AiMessage.system('Be brief.'), AiMessage.user('Hello')],
        options: const AiGenerationOptions(
          temperature: 0.2,
          maxOutputTokens: 64,
        ),
        modelId: 'test-model',
        metadata: {'trace': 'unit'},
      );

      final decoded = AiRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, request);
      expect(decoded.messages.first.role, AiRole.system);
      expect(
        decoded.requiredCapabilities,
        contains(InferenceCapability.textGeneration),
      );
      expect(
        decoded.requiredCapabilities,
        isNot(contains(InferenceCapability.structuredOutput)),
      );
    });

    test('a response schema adds the structured-output capability', () {
      final request = AiRequest(
        messages: [AiMessage.user('Return JSON')],
        responseSchema: {'type': 'object'},
      );

      expect(request.requiredCapabilities, hasLength(2));
      expect(
        request.requiredCapabilities,
        containsAll([
          InferenceCapability.textGeneration,
          InferenceCapability.structuredOutput,
        ]),
      );
    });

    test('AiResponse keeps measured latency across JSON', () {
      const response = AiResponse(
        text: 'Done.',
        modelId: 'test-model',
        latency: Duration(milliseconds: 42),
        metadata: {'provider': 'fake'},
      );

      final decoded = AiResponse.fromJson(response.toJson());

      expect(decoded, response);
      expect(decoded.latency, const Duration(milliseconds: 42));
      expect(decoded.toJson()['latencyMs'], 42);
    });
  });

  group('model capabilities', () {
    test('the default declaration claims nothing', () {
      const capabilities = ModelCapabilities();

      expect(capabilities.supported, isEmpty);
      for (final capability in InferenceCapability.values) {
        expect(capabilities.supports(capability), isFalse);
      }
    });

    test('textOnly declares text generation and nothing else', () {
      expect(
        ModelCapabilities.textOnly.supports(InferenceCapability.textGeneration),
        isTrue,
      );
      expect(
        ModelCapabilities.textOnly.supports(InferenceCapability.imageInput),
        isFalse,
      );
      expect(
        ModelCapabilities.textOnly.supports(
          InferenceCapability.structuredOutput,
        ),
        isFalse,
      );
      expect(
        ModelCapabilities.textOnly.supportsAll({
          InferenceCapability.textGeneration,
        }),
        isTrue,
      );
      expect(
        ModelCapabilities.textOnly.supportsAll({
          InferenceCapability.textGeneration,
          InferenceCapability.structuredOutput,
        }),
        isFalse,
      );
    });
  });

  group('request routing', () {
    test('an empty provider list is unavailable', () async {
      const router = RequestRouter(providers: []);
      final engine = IntelligenceEngine(router: router);

      await expectLater(
        engine.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(engine.status.hasProvider, isFalse);
    });

    test('routes to a capable provider and honours modelId', () {
      final provider = _FakeInferenceProvider();
      final router = RequestRouter(providers: [provider]);

      expect(router.resolve(_prompt('Hello')), same(provider));
      expect(
        () => router.resolve(_prompt('Hello').copyWith(modelId: 'other')),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });

    test('rejects a capability the model does not declare', () {
      final provider = _FakeInferenceProvider();
      final router = RequestRouter(providers: [provider]);
      final request = AiRequest(
        messages: [AiMessage.user('Return JSON')],
        responseSchema: {'type': 'object'},
      );

      expect(
        () => router.resolve(request),
        throwsA(
          isA<UnsupportedCapabilityException>().having(
            (error) =>
                error.missing.contains(InferenceCapability.structuredOutput),
            'missing structured output',
            isTrue,
          ),
        ),
      );
    });

    test('selects the provider that declares the needed capability', () {
      const jsonModel = ModelDescriptor(
        id: 'json-model',
        displayName: 'JSON model',
        runtimeId: 'fake',
        capabilities: ModelCapabilities(
          supported: {
            InferenceCapability.textGeneration,
            InferenceCapability.structuredOutput,
          },
        ),
      );
      final textOnly = _FakeInferenceProvider();
      final json = _FakeInferenceProvider(descriptor: jsonModel);
      final router = RequestRouter(providers: [textOnly, json]);
      final request = AiRequest(
        messages: [AiMessage.user('Return JSON')],
        responseSchema: {'type': 'object'},
      );

      expect(router.resolve(request), same(json));
    });
  });

  group('intelligence engine', () {
    test('rejects malformed requests before routing', () async {
      final provider = _FakeInferenceProvider();
      final engine = IntelligenceEngine(
        router: RequestRouter(providers: [provider]),
      );

      await expectLater(
        engine.generate(const AiRequest(messages: [])),
        throwsA(isA<InvalidRequestException>()),
      );
      await expectLater(
        engine.generate(
          AiRequest(messages: [AiMessage.assistant('Not a prompt')]),
        ),
        throwsA(isA<InvalidRequestException>()),
      );
      await expectLater(
        engine.generate(_prompt('   ')),
        throwsA(isA<InvalidRequestException>()),
      );
      await expectLater(
        engine.generate(
          AiRequest(
            messages: [AiMessage.user('Hello')],
            options: const AiGenerationOptions(temperature: -1),
          ),
        ),
        throwsA(isA<InvalidRequestException>()),
      );
      expect(provider.lastRequest, isNull);
    });

    test('delegates a valid request to the selected provider', () async {
      final provider = _FakeInferenceProvider(result: 'Answer.');
      final engine = IntelligenceEngine(
        router: RequestRouter(providers: [provider]),
      );

      final response = await engine.generate(_prompt('Hello'));

      expect(response.text, 'Answer.');
      expect(provider.lastRequest?.messages.single.text, 'Hello');
    });

    test('streams through the same validation and routing', () async {
      final provider = _FakeInferenceProvider(result: 'Streamed.');
      final engine = IntelligenceEngine(
        router: RequestRouter(providers: [provider]),
      );

      final events = await engine.stream(_prompt('Hello')).toList();

      expect(events.single.text, 'Streamed.');
      expect(provider.lastRequest?.messages.single.text, 'Hello');
      expect(
        () => engine.stream(const AiRequest(messages: [])),
        throwsA(isA<InvalidRequestException>()),
      );
    });

    test('status reports configuration and loading, never inference', () {
      final provider = _FakeInferenceProvider();
      final engine = IntelligenceEngine(
        router: RequestRouter(providers: [provider]),
      );

      expect(engine.status.hasConfiguredModel, isTrue);
      expect(engine.status.hasLoadedModel, isFalse);
      expect(engine.status.providers.single.modelId, _descriptor.id);
    });
  });

  group('LiteRT-LM adapter', () {
    test('does not initialize until asked', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      expect(provider.isInitialized, isFalse);
      expect(engine.initializeCalls, 0);

      await provider.initialize();
      await provider.initialize();

      expect(provider.isInitialized, isTrue);
      expect(engine.initializeCalls, 1);
    });

    test('maps history, sampler options and the final turn', () async {
      final engine = _FakeLiteRtLmEngine(text: 'Local answer.');
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      final response = await provider.generate(
        AiRequest(
          messages: [
            AiMessage.system('Be concise.'),
            AiMessage.user('First'),
            AiMessage.assistant('First answer'),
            AiMessage.user('Second'),
          ],
          options: const AiGenerationOptions(
            temperature: 0.3,
            topP: 0.8,
            topK: 12,
            seed: 7,
            maxOutputTokens: 32,
          ),
        ),
      );

      expect(response.text, 'Local answer.');
      expect(response.modelId, _descriptor.id);
      expect(response.latency, isA<Duration>());

      final conversation = engine.conversation!;
      expect(conversation.systemMessage!.text, 'Be concise.');
      expect(conversation.automaticToolCalling, isFalse);
      expect(conversation.initialMessages.map((message) => message.role), [
        lite.Role.user,
        lite.Role.model,
      ]);
      expect(conversation.initialMessages.map((message) => message.text), [
        'First',
        'First answer',
      ]);

      final sampler = conversation.sessionConfig!.samplerConfig!;
      expect(sampler.temperature, 0.3);
      expect(sampler.topP, 0.8);
      expect(sampler.topK, 12);
      expect(sampler.seed, 7);
      expect(conversation.sessionConfig!.maxOutputTokens, 32);

      expect(engine.message!.role, lite.Role.user);
      expect(engine.message!.text, 'Second');
    });

    test('streams deltas as cumulative responses', () async {
      final engine = _FakeLiteRtLmEngine(chunks: const ['Hel', 'lo']);
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      final events = await provider.stream(_prompt('Hi')).toList();

      expect(events.map((event) => event.text), ['Hel', 'Hello']);
      expect(events.last.modelId, _descriptor.id);
      expect(engine.message!.text, 'Hi');
      expect(provider.isInitialized, isTrue);
    });

    test('cancellation stops the engine stream and keeps the model', () async {
      final controller = StreamController<String>();
      final engine = _FakeLiteRtLmEngine()..streamController = controller;
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      final subscription = provider.stream(_prompt('Hi')).listen((_) {});
      await pumpEventQueue();

      controller.add('Hel');
      await pumpEventQueue();

      await subscription.cancel();
      await pumpEventQueue();

      expect(engine.streamCancelled, isTrue);
      expect(provider.isInitialized, isTrue);
    });

    test('a stream failure is typed and the engine is discarded', () async {
      final engine = _FakeLiteRtLmEngine()
        ..streamError = const lite.LiteRtLmException('boom');
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.stream(_prompt('Hello')),
        emitsError(
          isA<InferenceFailedException>().having(
            (error) => error.cause,
            'cause',
            isA<lite.LiteRtLmException>(),
          ),
        ),
      );
      expect(provider.isInitialized, isFalse);
      expect(provider.lifecycle.value.stage, EngineLifecycleStage.unavailable);
    });

    test(
      'a stream initialization failure stays an initialization failure',
      () async {
        final engine = _FakeLiteRtLmEngine()
          ..initializeError = UnsupportedError('No native runtime');
        final provider = LiteRtLmProvider(
          descriptor: _descriptor,
          createEngine: () => engine,
        );

        await expectLater(
          provider.stream(_prompt('Hello')),
          emitsError(isA<ProviderUnavailableException>()),
        );
        expect(
          provider.lifecycle.value.stage,
          EngineLifecycleStage.initializationFailed,
        );
      },
    );

    test('rejects structured output without touching the engine', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.generate(
          AiRequest(
            messages: [AiMessage.user('Return JSON')],
            responseSchema: {'type': 'object'},
          ),
        ),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
      expect(engine.initializeCalls, 0);
    });

    test(
      'rejects structured output even when a descriptor over-declares it',
      () async {
        const overDeclared = ModelDescriptor(
          id: 'json-model',
          displayName: 'JSON model',
          runtimeId: LiteRtLmProvider.providerId,
          capabilities: ModelCapabilities(
            supported: {
              InferenceCapability.textGeneration,
              InferenceCapability.structuredOutput,
            },
          ),
        );
        final engine = _FakeLiteRtLmEngine();
        final provider = LiteRtLmProvider(
          descriptor: overDeclared,
          createEngine: () => engine,
        );

        await expectLater(
          provider.generate(
            AiRequest(
              messages: [AiMessage.user('Return JSON')],
              responseSchema: {'type': 'object'},
            ),
          ),
          throwsA(isA<UnsupportedCapabilityException>()),
        );
        expect(engine.initializeCalls, 0);
      },
    );

    test('rejects a request for another model before initialization', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.generate(_prompt('Hello').copyWith(modelId: 'other')),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(engine.initializeCalls, 0);
    });

    test('rejects invalid options before initialization', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.generate(
          _prompt('Hello')
              .copyWith(options: const AiGenerationOptions(temperature: -1)),
        ),
        throwsA(isA<InvalidRequestException>()),
      );
      expect(engine.initializeCalls, 0);
    });

    test('an unconfigured model path never builds an engine', () async {
      var created = 0;
      final provider = LiteRtLmProvider(
        descriptor: const ModelDescriptor(
          id: 'missing',
          displayName: 'Missing',
          runtimeId: LiteRtLmProvider.providerId,
          capabilities: ModelCapabilities.textOnly,
        ),
        createEngine: () {
          created += 1;
          return _FakeLiteRtLmEngine();
        },
      );

      await expectLater(
        provider.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(created, 0);
    });

    test('a native failure is typed and the engine is discarded', () async {
      final engine = _FakeLiteRtLmEngine()
        ..completeError = const lite.LiteRtLmException('boom');
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.generate(_prompt('Hello')),
        throwsA(
          isA<InferenceFailedException>().having(
            (error) => error.cause,
            'cause',
            isA<lite.LiteRtLmException>(),
          ),
        ),
      );
      expect(provider.isInitialized, isFalse);
      expect(engine.disposeCalls, greaterThanOrEqualTo(1));
    });

    test('an unsupported platform is reported as unavailable', () async {
      final engine = _FakeLiteRtLmEngine()
        ..initializeError = UnsupportedError('No native runtime');
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await expectLater(
        provider.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(provider.isInitialized, isFalse);
    });

    test('dispose releases the engine once', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      await provider.initialize();
      await provider.dispose();
      await provider.dispose();

      expect(provider.isInitialized, isFalse);
      expect(engine.disposeCalls, 1);
    });

    test('concurrent initialization loads the engine once', () async {
      final gate = Completer<void>();
      final engine = _FakeLiteRtLmEngine()..initializeGate = gate;
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );

      final first = provider.initialize();
      final second = provider.initialize();
      await pumpEventQueue();
      expect(engine.initializeCalls, 1);

      gate.complete();
      await Future.wait([first, second]);
      expect(provider.isInitialized, isTrue);
      expect(engine.initializeCalls, 1);
    });

    test(
      'disposing during initialization cannot leave a loaded engine',
      () async {
        final gate = Completer<void>();
        final engine = _FakeLiteRtLmEngine()..initializeGate = gate;
        final provider = LiteRtLmProvider(
          descriptor: _descriptor,
          createEngine: () => engine,
        );

        final initialization = provider.initialize();
        await pumpEventQueue();
        final disposal = provider.dispose();
        gate.complete();

        await expectLater(
          initialization,
          throwsA(isA<ProviderUnavailableException>()),
        );
        await disposal;
        expect(provider.isInitialized, isFalse);
        expect(provider.lifecycle.value.stage, EngineLifecycleStage.disposed);
        expect(engine.disposeCalls, 1);
      },
    );

    test('requests after disposal fail with a typed error', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmProvider(
        descriptor: _descriptor,
        createEngine: () => engine,
      );
      await provider.initialize();
      await provider.dispose();

      await expectLater(
        provider.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(
        () => provider.stream(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });
  });

  group('model lifecycle', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('kritha-lifecycle-');
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    File writeModel(String name) {
      final file = File('${directory.path}/$name');
      file.writeAsBytesSync([1, 2, 3]);
      return file;
    }

    ProviderContainer containerFor({
      required String? path,
      required LiteRtLmEngine Function(ModelDescriptor) factory,
    }) {
      final container = ProviderContainer(
        overrides: [
          modelConfigStoreProvider.overrideWithValue(
            InMemoryModelConfigStore(path),
          ),
          liteRtLmEngineFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'inspection reports file readiness without loading the engine',
      () async {
        final file = writeModel('lifecycle.litertlm');
        final engine = _FakeLiteRtLmEngine();
        final container = containerFor(
          path: file.path,
          factory: (model) => engine,
        );

        await container.read(modelConfigurationProvider.future);

        expect(
          container.read(modelLifecycleProvider).stage,
          ModelLifecycleStage.fileReady,
        );
        expect(
          container.read(intelligenceStatusProvider).hasLoadedModel,
          isFalse,
        );
        expect(engine.initializeCalls, 0);
      },
    );

    test('initialization moves through loading to loaded', () async {
      final file = writeModel('lifecycle.litertlm');
      final gate = Completer<void>();
      final engine = _FakeLiteRtLmEngine()..initializeGate = gate;
      final container = containerFor(
        path: file.path,
        factory: (model) => engine,
      );
      await container.read(modelConfigurationProvider.future);
      final provider = container.read(inferenceProvidersProvider).single;

      final initialization = provider.initialize();
      await pumpEventQueue();

      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.initializing,
      );
      expect(
        container.read(intelligenceStatusProvider).hasLoadedModel,
        isFalse,
      );

      gate.complete();
      await initialization;

      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.initialized,
      );
      expect(container.read(intelligenceStatusProvider).hasLoadedModel, isTrue);
      expect(engine.initializeCalls, 1);
    });

    test('an initialization failure is explicit and recoverable', () async {
      final file = writeModel('lifecycle.litertlm');
      final engine = _FakeLiteRtLmEngine()
        ..initializeError = UnsupportedError('No native runtime');
      final container = containerFor(
        path: file.path,
        factory: (model) => engine,
      );
      await container.read(modelConfigurationProvider.future);
      final provider = container.read(inferenceProvidersProvider).single;

      await expectLater(
        provider.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );

      final failed = container.read(modelLifecycleProvider);
      expect(failed.stage, ModelLifecycleStage.initializationFailed);
      expect(failed.message, isNot(contains('No native runtime')));
      expect(provider.isInitialized, isFalse);

      engine.initializeError = null;
      final response = await provider.generate(_prompt('Hello'));

      expect(response.text, 'Local answer.');
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.initialized,
      );
      expect(engine.initializeCalls, 2);
    });

    test('clearing during initialization disposes the old engine', () async {
      final file = writeModel('lifecycle.litertlm');
      final gate = Completer<void>();
      final engine = _FakeLiteRtLmEngine()..initializeGate = gate;
      final container = containerFor(
        path: file.path,
        factory: (model) => engine,
      );
      await container.read(modelConfigurationProvider.future);
      final provider = container.read(inferenceProvidersProvider).single;

      final initialization = provider.initialize();
      await pumpEventQueue();
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.initializing,
      );

      await container.read(modelConfigurationProvider.notifier).clear();
      expect(
        container.read(modelLifecycleProvider).stage,
        isNot(ModelLifecycleStage.initializing),
      );
      await pumpEventQueue();
      gate.complete();

      await expectLater(
        initialization,
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(provider.lifecycle.value.stage, EngineLifecycleStage.disposed);
      expect(engine.disposeCalls, 1);
      expect(container.read(inferenceProvidersProvider), isEmpty);
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.notConfigured,
      );
    });

    test(
      'a factory failure does not leave a permanent loading state',
      () async {
        final file = writeModel('lifecycle.litertlm');
        final container = containerFor(
          path: file.path,
          factory: (model) => throw StateError('secret native detail'),
        );
        await container.read(modelConfigurationProvider.future);
        final provider = container.read(inferenceProvidersProvider).single;

        await expectLater(provider.initialize(), throwsA(isA<StateError>()));

        final failed = container.read(modelLifecycleProvider);
        expect(failed.stage, ModelLifecycleStage.initializationFailed);
        expect(failed.message, isNot(contains('secret native detail')));
      },
    );

    test(
      'a generation failure releases the engine and reports unavailable',
      () async {
        final file = writeModel('lifecycle.litertlm');
        final engine = _FakeLiteRtLmEngine()
          ..completeError = const lite.LiteRtLmException('boom');
        final container = containerFor(
          path: file.path,
          factory: (model) => engine,
        );
        await container.read(modelConfigurationProvider.future);
        final provider = container.read(inferenceProvidersProvider).single;

        await expectLater(
          provider.generate(_prompt('Hello')),
          throwsA(isA<InferenceFailedException>()),
        );

        expect(
          container.read(modelLifecycleProvider).stage,
          ModelLifecycleStage.unavailable,
        );
        expect(provider.isInitialized, isFalse);
        expect(engine.disposeCalls, greaterThanOrEqualTo(1));

        engine.completeError = null;
        await provider.generate(_prompt('Hello'));

        expect(
          container.read(modelLifecycleProvider).stage,
          ModelLifecycleStage.initialized,
        );
      },
    );

    test('invalid configuration never creates an engine', () async {
      final container = containerFor(
        path: '${directory.path}/missing.litertlm',
        factory: (model) => _FakeLiteRtLmEngine(),
      );
      await container.read(modelConfigurationProvider.future);

      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.configurationUnavailable,
      );
      expect(container.read(inferenceProvidersProvider), isEmpty);
    });

    test('no selection is distinct from an unavailable file', () async {
      final container = containerFor(
        path: null,
        factory: (model) => _FakeLiteRtLmEngine(),
      );
      await container.read(modelConfigurationProvider.future);

      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.notConfigured,
      );
      expect(container.read(inferenceProvidersProvider), isEmpty);
    });
  });

  group('Riverpod wiring', () {
    test('the default graph has no provider and fails predictably', () async {
      final container = ProviderContainer(
        overrides: [
          modelConfigStoreProvider.overrideWithValue(
            InMemoryModelConfigStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final engine = container.read(intelligenceEngineProvider);
      expect(engine.router.providers, isEmpty);
      expect(container.read(intelligenceStatusProvider).hasProvider, isFalse);

      await expectLater(
        engine.generate(_prompt('Hello')),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });

    test('a fake engine can be injected through the graph', () async {
      final engine = _FakeLiteRtLmEngine(text: 'Injected answer.');
      final container = ProviderContainer(
        overrides: [
          configuredModelProvider.overrideWithValue(_descriptor),
          liteRtLmEngineFactoryProvider.overrideWithValue((model) => engine),
        ],
      );

      final response = await container
          .read(intelligenceEngineProvider)
          .generate(_prompt('Hello'));

      expect(response.text, 'Injected answer.');
      expect(
        container.read(inferenceProvidersProvider).single.isInitialized,
        isTrue,
      );
      expect(container.read(intelligenceStatusProvider).hasLoadedModel, isTrue);

      container.dispose();
      expect(engine.disposeCalls, 1);
    });

    test('clearing the selection disposes a loaded engine', () async {
      final directory = Directory.systemTemp.createTempSync('kritha-wiring-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/model.litertlm')
        ..writeAsBytesSync([1]);
      final store = InMemoryModelConfigStore(file.path);
      final engine = _FakeLiteRtLmEngine();
      final container = ProviderContainer(
        overrides: [
          modelConfigStoreProvider.overrideWithValue(store),
          liteRtLmEngineFactoryProvider.overrideWithValue((model) => engine),
        ],
      );
      addTearDown(container.dispose);

      final configuration = await container.read(
        modelConfigurationProvider.future,
      );
      expect(configuration.isReady, isTrue);
      await container.read(inferenceProvidersProvider).single.initialize();
      expect(container.read(intelligenceStatusProvider).hasLoadedModel, isTrue);
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.initialized,
      );

      await container.read(modelConfigurationProvider.notifier).clear();

      expect(container.read(inferenceProvidersProvider), isEmpty);
      final status = container.read(intelligenceStatusProvider);
      expect(status.hasProvider, isFalse);
      expect(status.hasLoadedModel, isFalse);
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.notConfigured,
      );
      expect(engine.disposeCalls, 1);
    });

    test('removing the file disposes the loaded engine', () async {
      final directory = Directory.systemTemp.createTempSync('kritha-wiring-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/model.litertlm')
        ..writeAsBytesSync([1]);
      final store = InMemoryModelConfigStore(file.path);
      final engine = _FakeLiteRtLmEngine();
      final container = ProviderContainer(
        overrides: [
          modelConfigStoreProvider.overrideWithValue(store),
          liteRtLmEngineFactoryProvider.overrideWithValue((model) => engine),
        ],
      );
      addTearDown(container.dispose);

      await container.read(modelConfigurationProvider.future);
      await container.read(inferenceProvidersProvider).single.initialize();
      file.deleteSync();

      await container.read(modelConfigurationProvider.notifier).revalidate();

      expect(container.read(inferenceProvidersProvider), isEmpty);
      expect(
        container.read(intelligenceStatusProvider).hasLoadedModel,
        isFalse,
      );
      expect(
        container.read(modelLifecycleProvider).stage,
        ModelLifecycleStage.configurationUnavailable,
      );
      expect(engine.disposeCalls, 1);
    });

    test('a fake provider can replace the whole registry', () async {
      final provider = _FakeInferenceProvider(result: 'Overridden answer.');
      final container = ProviderContainer(
        overrides: [
          inferenceProvidersProvider.overrideWithValue([provider]),
        ],
      );
      addTearDown(container.dispose);

      final engine = container.read(intelligenceEngineProvider);
      final response = await engine.generate(_prompt('Hello'));

      expect(response.text, 'Overridden answer.');
      expect(provider.lastRequest?.messages.single.text, 'Hello');
      expect(engine.status.hasConfiguredModel, isTrue);
      expect(engine.status.hasLoadedModel, isTrue);
      expect(
        engine.status.providers.single.lifecycle.stage,
        EngineLifecycleStage.initialized,
      );
    });
  });
}
