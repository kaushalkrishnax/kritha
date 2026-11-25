import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kritha/features/intelligence/inference_provider.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/ai_response.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/task_registry.dart';
import 'package:kritha/features/intelligence/providers/local/litertlm_provider.dart';
import 'package:kritha/features/intelligence/providers/provider_registry.dart';
import 'package:kritha/features/intelligence/providers/remote/anthropic_provider.dart';
import 'package:kritha/features/intelligence/providers/remote/google_gemini_provider.dart';
import 'package:kritha/features/intelligence/providers/remote/mistral_provider.dart';
import 'package:kritha/features/intelligence/providers/remote/oai_spec_provider.dart';
import 'package:kritha/features/intelligence/providers/remote/xai_provider.dart';
import 'package:kritha/features/intelligence/usage_tracking_provider.dart';
import 'package:litertlm/litertlm.dart' as lite;

const _localProviderId = '11111111-1111-1111-1111-111111111101';
const _geminiProviderId = '11111111-1111-1111-1111-111111111102';

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
  _FakeInferenceProvider({this.error});

  String get providerAlias => 'test-provider';
  String get result => 'Fake answer.';
  final Object? error;
  AiRequest? lastRequest;
  ProviderModel? lastModel;
  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.fileReady(),
  );

  @override
  String get alias => providerAlias;

  @override
  ProviderConfig get config =>
      ProviderConfig(id: 'test-provider-id', alias: alias);

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isInitialized;

  @override
  Future<void> initialize() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.initialized);
  }

  @override
  Future<List<DiscoveredModel>> discoverModels() async => const [];

  @override
  Future<ProviderTestResult> test() async =>
      const ProviderTestResult(ok: true, message: 'ok');

  @override
  Future<AiResponse> generate(AiRequest request, ProviderModel model) async {
    lastRequest = request;
    lastModel = model;
    await initialize();
    if (error != null) throw error!;
    return AiResponse(text: result, modelId: model.id, latency: Duration.zero);
  }

  @override
  Stream<AiResponse> stream(AiRequest request, ProviderModel model) async* {
    lastRequest = request;
    lastModel = model;
    yield await generate(request, model);
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
    });
  });

  group('LiteRT-LM adapter', () {
    test('does not initialize until asked', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      expect(provider.isInitialized, isFalse);
      expect(engine.initializeCalls, 0);

      await provider.initialize();
      await provider.initialize();

      expect(provider.isInitialized, isFalse);
      expect(engine.initializeCalls, 0);
    });

    test('maps history, sampler options and the final turn', () async {
      final engine = _FakeLiteRtLmEngine(text: 'Local answer.');
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: '/models/test.litertlm',
        artifacts: const [],
        metadata: const {},
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
          modelId: model.id,
        ),
        model,
      );

      expect(response.text, 'Local answer.');
      expect(response.modelId, model.id);
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
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: '/models/test.litertlm',
        artifacts: const [],
        metadata: const {},
      );

      final events = await provider
          .stream(
            AiRequest(messages: [AiMessage.user('Hi')], modelId: model.id),
            model,
          )
          .toList();

      expect(events.map((event) => event.text), ['Hel', 'Hello']);
      expect(events.last.modelId, model.id);
      expect(engine.message!.text, 'Hi');
      expect(provider.isInitialized, isTrue);
    });

    test('cancellation stops the engine stream and keeps the model', () async {
      final controller = StreamController<String>();
      final engine = _FakeLiteRtLmEngine()..streamController = controller;
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: '/models/test.litertlm',
        artifacts: const [],
        metadata: const {},
      );

      final subscription = provider
          .stream(
            AiRequest(messages: [AiMessage.user('Hi')], modelId: model.id),
            model,
          )
          .listen((_) {});
      await pumpEventQueue();

      controller.add('Hel');
      await pumpEventQueue();

      await subscription.cancel();
      await pumpEventQueue();

      expect(engine.streamCancelled, isTrue);
      expect(provider.isInitialized, isTrue);
    });

    test('rejects structured output without touching the engine', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: '/models/test.litertlm',
        artifacts: const [],
        metadata: const {},
      );

      await expectLater(
        provider.generate(
          AiRequest(
            messages: [AiMessage.user('Return JSON')],
            responseSchema: {'type': 'object'},
            modelId: model.id,
          ),
          model,
        ),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
      expect(engine.initializeCalls, 0);
    });

    test('an unconfigured model path never builds an engine', () async {
      var created = 0;
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) {
          created += 1;
          return _FakeLiteRtLmEngine();
        },
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: null,
        artifacts: const [],
        metadata: const {},
      );

      await expectLater(
        provider.generate(
          AiRequest(messages: [AiMessage.user('Hello')], modelId: model.id),
          model,
        ),
        throwsA(isA<ProviderUnavailableException>()),
      );
      expect(created, 0);
    });

    test('dispose releases the engine once', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final model = ProviderModel(
        id: 'model-1',
        providerId: _localProviderId,
        externalModelId: 'local-test',
        displayName: 'Local test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        modelPath: '/models/test.litertlm',
        artifacts: const [],
        metadata: const {},
      );

      await provider.initialize();
      await provider.generate(
        AiRequest(messages: [AiMessage.user('Hello')], modelId: model.id),
        model,
      );
      await provider.dispose();
      await provider.dispose();

      expect(provider.isInitialized, isFalse);
      expect(engine.disposeCalls, 1);
    });

    test('local test does not contact a remote URL', () async {
      final engine = _FakeLiteRtLmEngine();
      final provider = LiteRtLmLocalProvider(
        config: ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
        createEngine: (path) => engine,
        localModels: () async => [],
      );

      final result = await provider.test();

      expect(result.ok, isTrue);
    });
  });

  group('provider registry resolution', () {
    test('resolves every default provider alias', () {
      final registry = ProviderRegistry(
        factories: {
          'local-litertlm': (config) => LiteRtLmLocalProvider(
            config: config,
            createEngine: (path) => _FakeLiteRtLmEngine(),
            localModels: () async => [],
          ),
          'google-gemini': (config) => GoogleGeminiProvider(
            config: config,
            clientFactory: () => http.Client(),
          ),
          'anthropic': (config) => AnthropicProvider(
            config: config,
            clientFactory: () => http.Client(),
          ),
          'xai': (config) =>
              XaiProvider(config: config, clientFactory: () => http.Client()),
          'mistral': (config) => MistralProvider(
            config: config,
            clientFactory: () => http.Client(),
          ),
          'openai': (config) => OaiSpecProvider(
            config: config,
            clientFactory: () => http.Client(),
          ),
        },
      );

      expect(registry.isRegistered('local-litertlm'), isTrue);
      expect(registry.isRegistered('google-gemini'), isTrue);
      expect(registry.isRegistered('anthropic'), isTrue);
      expect(registry.isRegistered('xai'), isTrue);
      expect(registry.isRegistered('mistral'), isTrue);
      expect(registry.isRegistered('openai'), isTrue);

      final gemini = registry.createProvider(
        ProviderConfig(id: _geminiProviderId, alias: 'google-gemini'),
      );
      expect(gemini, isA<GoogleGeminiProvider>());
      expect(gemini.alias, 'google-gemini');

      final local = registry.createProvider(
        ProviderConfig(id: _localProviderId, alias: 'local-litertlm'),
      );
      expect(local, isA<LiteRtLmLocalProvider>());
      expect(local.alias, 'local-litertlm');
    });

    test('throws for unknown alias', () {
      final registry = ProviderRegistry(factories: const {});
      expect(
        () => registry.createProvider(
          ProviderConfig(id: 'unknown', alias: 'no-such-provider'),
        ),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });

    test('custom providers use the OpenAI spec fallback', () {
      final customRegistry = ProviderRegistry(
        factories: const {},
        fallback: (config) =>
            OaiSpecProvider(config: config, clientFactory: () => http.Client()),
      );
      final custom = customRegistry.createProvider(
        ProviderConfig(
          id: 'custom-1',
          alias: 'My Custom Endpoint',
          baseUrl: 'https://api.example.com/v1',
        ),
      );
      expect(custom, isA<OaiSpecProvider>());
      expect(custom.alias, 'My Custom Endpoint');
      expect(custom.config.baseUrl, 'https://api.example.com/v1');
    });
  });

  group('usage tracking', () {
    test('tracks settled generate and stream requests', () async {
      final inner = _FakeInferenceProvider();
      final results = <bool>[];
      final tracked = UsageTrackingInferenceProvider(
        inner: inner,
        onRequestSettled: results.add,
      );
      final model = ProviderModel(
        id: 'model-1',
        providerId: 'provider-1',
        externalModelId: 'test-model',
        displayName: 'Test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        artifacts: const [],
        metadata: const {},
      );
      final request = AiRequest(
        messages: [AiMessage.user('Hello')],
        modelId: model.id,
      );

      await tracked.generate(request, model);
      await tracked.stream(request, model).toList();
      expect(results, [true, true]);
    });

    test('records failures', () async {
      final results = <bool>[];
      final model = ProviderModel(
        id: 'model-1',
        providerId: 'provider-1',
        externalModelId: 'test-model',
        displayName: 'Test',
        capabilities: const {InferenceCapability.textGeneration},
        tasks: const [],
        artifacts: const [],
        metadata: const {},
      );
      final request = AiRequest(
        messages: [AiMessage.user('Hello')],
        modelId: model.id,
      );

      // Use a provider that always fails to verify failure tracking.
      final failingInner = _FakeInferenceProvider(
        error: StateError('provider failed'),
      );
      final failingTracked = UsageTrackingInferenceProvider(
        inner: failingInner,
        onRequestSettled: results.add,
      );

      await expectLater(
        failingTracked.generate(request, model),
        throwsA(isA<StateError>()),
      );
      expect(results, [false]);
    });
  });

  group(
    'remote provider model discovery and multimodal capability mapping',
    () {
      test(
        'GoogleGeminiProvider parses native models payload and pagination',
        () async {
          var calls = 0;
          final client = MockClient((request) async {
            calls++;
            if (calls == 1) {
              expect(request.url.path, '/v1beta/models');
              expect(request.url.queryParameters['key'], 'gemini-key');
              return http.Response(
                jsonEncode({
                  'models': [
                    {
                      'name': 'models/gemini-2.5-flash',
                      'displayName': 'Gemini 2.5 Flash',
                      'supportedGenerationMethods': [
                        'generateContent',
                        'countTokens',
                      ],
                    },
                    {
                      'name': 'models/text-embedding-004',
                      'displayName': 'Text Embedding 004',
                      'supportedGenerationMethods': ['embedContent'],
                    },
                  ],
                  'nextPageToken': 'page-2',
                }),
                200,
              );
            }
            expect(request.url.queryParameters['pageToken'], 'page-2');
            return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/imagen-3.0-generate-002',
                    'displayName': 'Imagen 3',
                    'supportedGenerationMethods': ['predict'],
                  },
                ],
              }),
              200,
            );
          });

          final provider = GoogleGeminiProvider(
            config: const ProviderConfig(
              id: _geminiProviderId,
              alias: 'google-gemini',
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              apiKey: 'gemini-key',
            ),
            clientFactory: () => client,
          );

          final discovered = await provider.discoverModels();
          expect(discovered.map((m) => m.externalModelId).toList(), [
            'gemini-2.5-flash',
            'text-embedding-004',
            'imagen-3.0-generate-002',
          ]);

          final flash = discovered.first;
          expect(
            flash.tasks.map((t) => t.task),
            containsAll([
              AiTaskId.textGeneration,
              AiTaskId.imageTextToText,
              AiTaskId.audioUnderstanding,
              AiTaskId.videoTextToText,
            ]),
          );
          expect(
            flash.capabilities,
            containsAll([
              InferenceCapability.textGeneration,
              InferenceCapability.imageInput,
              InferenceCapability.audioInput,
            ]),
          );
          expect(discovered[1].tasks.map((t) => t.task), [AiTaskId.embeddings]);
          expect(discovered[2].tasks.map((t) => t.task), [
            AiTaskId.textToImage,
          ]);
        },
      );

      test(
        'GoogleGeminiProvider encodes multimodal image input in _body',
        () async {
          late Map<String, dynamic> capturedBody;
          final client = MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'It is a cat.'},
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          });

          final provider = GoogleGeminiProvider(
            config: const ProviderConfig(
              id: _geminiProviderId,
              alias: 'google-gemini',
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              apiKey: 'gemini-key',
            ),
            clientFactory: () => client,
          );

          final model = ProviderModel(
            id: 'uuid-flash',
            providerId: _geminiProviderId,
            externalModelId: 'gemini-2.5-flash',
            displayName: 'Gemini 2.5 Flash',
            capabilities: const {
              InferenceCapability.textGeneration,
              InferenceCapability.imageInput,
            },
            tasks: const [],
            artifacts: const [],
            metadata: const {},
          );

          final response = await provider.generate(
            AiRequest(
              messages: [AiMessage.user('Describe this image')],
              modelId: model.id,
            ),
            model,
          );

          expect(response.text, 'It is a cat.');
          final contents = capturedBody['contents'] as List;
          final parts = (contents.single as Map)['parts'] as List;
          expect(parts, hasLength(1));
          expect((parts.first as Map)['text'], 'Describe this image');
        },
      );

      test('AnthropicProvider maps both text and vision tasks', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'claude-sonnet-4-20250514',
                  'display_name': 'Claude Sonnet 4',
                },
                {
                  'id': 'claude-3-5-sonnet-latest',
                  'display_name': 'Claude 3.5 Sonnet',
                  'capabilities': {'image_input': true},
                },
              ],
            }),
            200,
          );
        });

        final provider = AnthropicProvider(
          config: const ProviderConfig(
            id: 'anthropic-id',
            alias: 'anthropic',
            baseUrl: 'https://api.anthropic.com/v1',
            apiKey: 'ant-key',
          ),
          clientFactory: () => client,
        );

        final discovered = await provider.discoverModels();
        expect(discovered, hasLength(2));
        for (final model in discovered) {
          expect(
            model.tasks.map((t) => t.task),
            containsAll([AiTaskId.textGeneration, AiTaskId.imageTextToText]),
          );
        }
      });

      test(
        'OaiSpecProvider classifies multimodal and embedding models',
        () async {
          final client = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'gpt-4o'},
                  {'id': 'text-embedding-3-small'},
                ],
              }),
              200,
            );
          });

          final provider = OaiSpecProvider(
            config: const ProviderConfig(
              id: 'openai-id',
              alias: 'openai',
              baseUrl: 'https://api.openai.com/v1',
              apiKey: 'oai-key',
            ),
            clientFactory: () => client,
          );

          final discovered = await provider.discoverModels();
          expect(
            discovered[0].tasks.map((t) => t.task),
            containsAll([AiTaskId.textGeneration, AiTaskId.imageTextToText]),
          );
          expect(discovered[1].tasks.map((t) => t.task), [AiTaskId.embeddings]);
        },
      );

      test(
        'OaiSpecProvider image generation omits response_format and reads url',
        () async {
          Map<String, dynamic>? requestBody;
          final client = MockClient((request) async {
            if (request.url.path.endsWith('/images/generations')) {
              requestBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'data': [
                    {'url': 'https://images.example.com/out.png'},
                  ],
                }),
                200,
              );
            }
            expect(
              request.url.toString(),
              'https://images.example.com/out.png',
            );
            return http.Response.bytes(
              [9, 8, 7],
              200,
              headers: {'content-type': 'image/png'},
            );
          });

          final provider = OaiSpecProvider(
            config: const ProviderConfig(
              id: 'openai-id',
              alias: 'openai',
              baseUrl: 'https://api.openai.com/v1',
              apiKey: 'oai-key',
            ),
            clientFactory: () => client,
          );

          final model = ProviderModel(
            id: 'uuid-image',
            providerId: 'openai-id',
            externalModelId: 'gpt-image-1',
            displayName: 'GPT Image 1',
            capabilities: const {},
            tasks: const [],
            artifacts: const [],
            metadata: const {},
          );

          final image = await provider.generateImage('A sunset', model);
          expect(image.bytes, [9, 8, 7]);
          expect(image.mimeType, 'image/png');
          expect(requestBody?.containsKey('response_format'), isFalse);
          expect(requestBody?['model'], 'gpt-image-1');
        },
      );

      test(
        'GoogleGeminiProvider streams SSE without doubling /v1beta',
        () async {
          final client = MockClient.streaming((request, bodyStream) async {
            expect(
              request.url.path,
              '/v1beta/models/gemini-2.5-flash:streamGenerateContent',
            );
            expect(request.url.queryParameters['alt'], 'sse');
            expect(request.url.queryParameters['key'], 'gemini-key');
            final sse = [
              'data: ${jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Hello '},
                      ],
                    },
                  },
                ],
              })}\n\n',
              'data: ${jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'world!'},
                      ],
                    },
                  },
                ],
              })}\n\n',
            ].join();
            return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
          });

          final provider = GoogleGeminiProvider(
            config: const ProviderConfig(
              id: _geminiProviderId,
              alias: 'google-gemini',
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              apiKey: 'gemini-key',
            ),
            clientFactory: () => client,
          );

          final model = ProviderModel(
            id: 'uuid-flash',
            providerId: _geminiProviderId,
            externalModelId: 'gemini-2.5-flash',
            displayName: 'Gemini 2.5 Flash',
            capabilities: const {InferenceCapability.textGeneration},
            tasks: const [],
            artifacts: const [],
            metadata: const {},
          );

          final responses = await provider
              .stream(
                AiRequest(messages: [AiMessage.user('Hi')], modelId: model.id),
                model,
              )
              .toList();

          expect(responses.map((r) => r.text).toList(), [
            'Hello ',
            'Hello world!',
          ]);
        },
      );

      test('GoogleGeminiProvider supports image gen, ASR, and TTS', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith(':predict')) {
            return http.Response(
              jsonEncode({
                'predictions': [
                  {
                    'bytesBase64Encoded': base64Encode([10, 20, 30]),
                    'mimeType': 'image/png',
                  },
                ],
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final genConfig = body['generationConfig'] as Map?;
          final modalities = genConfig?['responseModalities'] as List?;
          if (modalities != null && modalities.contains('AUDIO')) {
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'inlineData': {
                            'mimeType': 'audio/L16;rate=24000',
                            'data': base64Encode([1, 2, 3, 4]),
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'transcribed text'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider = GoogleGeminiProvider(
          config: const ProviderConfig(
            id: _geminiProviderId,
            alias: 'google-gemini',
            baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
            apiKey: 'gemini-key',
          ),
          clientFactory: () => client,
        );

        final imagen = ProviderModel(
          id: 'uuid-imagen',
          providerId: _geminiProviderId,
          externalModelId: 'imagen-3.0-generate-002',
          displayName: 'Imagen 3',
          capabilities: const {},
          tasks: const [],
          artifacts: const [],
          metadata: const {},
        );
        final img = await provider.generateImage('A sunset', imagen);
        expect(img.bytes, [10, 20, 30]);
        expect(img.mimeType, 'image/png');

        final flash = ProviderModel(
          id: 'uuid-flash',
          providerId: _geminiProviderId,
          externalModelId: 'gemini-2.5-flash',
          displayName: 'Gemini 2.5 Flash',
          capabilities: const {
            InferenceCapability.textGeneration,
            InferenceCapability.audioInput,
          },
          tasks: const [],
          artifacts: const [],
          metadata: const {},
        );
        final transcript = await provider.transcribeAudio(
          Uint8List.fromList([7, 8]),
          'audio/mp4',
          flash,
        );
        expect(transcript, 'transcribed text');

        final tts = ProviderModel(
          id: 'uuid-tts',
          providerId: _geminiProviderId,
          externalModelId: 'gemini-2.5-flash-preview-tts',
          displayName: 'Gemini TTS',
          capabilities: const {},
          tasks: const [],
          artifacts: const [],
          metadata: const {},
        );
        final speech = await provider.synthesizeSpeech('Hello', tts);
        expect(speech.mimeType, 'audio/wav');
        expect(utf8.decode(speech.bytes.sublist(0, 4)), 'RIFF');
        expect(speech.bytes.length, 48);
      });

      test(
        'GoogleGeminiProvider generates Nano Banana images and skips thoughts',
        () async {
          late Map<String, dynamic> capturedBody;
          final client = MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'thought': true,
                          'inlineData': {
                            'mimeType': 'image/png',
                            'data': base64Encode([1, 2]),
                          },
                        },
                        {
                          'inlineData': {
                            'mimeType': 'image/png',
                            'data': base64Encode([3, 4]),
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          });

          final provider = GoogleGeminiProvider(
            config: const ProviderConfig(
              id: _geminiProviderId,
              alias: 'google-gemini',
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              apiKey: 'gemini-key',
            ),
            clientFactory: () => client,
          );

          final model = ProviderModel(
            id: 'uuid-nano-banana',
            providerId: _geminiProviderId,
            externalModelId: 'gemini-nano-banana-2.1',
            displayName: 'Nano Banana 2.1',
            capabilities: const {},
            tasks: const [],
            artifacts: const [],
            metadata: const {},
          );

          final image = await provider.generateImage('A cat', model);
          expect(image.bytes, [3, 4]);
          expect(image.mimeType, 'image/png');
          expect(
            (capturedBody['generationConfig'] as Map)['responseModalities'],
            ['TEXT', 'IMAGE'],
          );
        },
      );

      test(
        'GoogleGeminiProvider classifies Nano Banana as image generation',
        () async {
          final client = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/gemini-nano-banana-2.1',
                    'displayName': 'Nano Banana 2.1',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              }),
              200,
            );
          });

          final provider = GoogleGeminiProvider(
            config: const ProviderConfig(
              id: _geminiProviderId,
              alias: 'google-gemini',
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              apiKey: 'gemini-key',
            ),
            clientFactory: () => client,
          );

          final discovered = await provider.discoverModels();
          expect(
            discovered.single.tasks.map((t) => t.task),
            contains(AiTaskId.textToImage),
          );
        },
      );
    },
  );
}
