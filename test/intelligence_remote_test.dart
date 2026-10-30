import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/intelligence/runtime_ids.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/features/providers/providers_controller.dart';

import 'support/fake_inference.dart';
import 'support/fake_workspace.dart';

void main() {
  AiRequest prompt({Map<String, dynamic>? responseSchema}) => AiRequest(
    messages: [AiMessage.system('Be concise.'), AiMessage.user('Hello')],
    options: const AiGenerationOptions(maxOutputTokens: 64),
    responseSchema: responseSchema,
  );

  ActiveModelAssignment assignment({
    required ModelCapability capability,
    required String sourceId,
    required String runtimeId,
    required String modelId,
  }) => ActiveModelAssignment(
    capability: capability,
    modelId: modelId,
    displayName: modelId,
    runtimeId: runtimeId,
    sourceId: sourceId,
    activatedAt: DateTime(2026),
  );

  Future<ProviderContainer> containerFor({
    required Map<ModelCapability, ActiveModelAssignment> assignments,
    Map<String, StoredProviderSettings> settings = const {},
    Map<String, String> credentials = const {},
    required http.Client Function() clientFactory,
    String? localPath,
    FakeProviderConnectionTester? tester,
  }) async {
    final container = ProviderContainer(
      overrides: [
        activeModelStoreProvider.overrideWithValue(
          InMemoryActiveModelStore(assignments),
        ),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        providerSettingsStoreProvider.overrideWithValue(
          InMemoryProviderSettingsStore(settings),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          InMemoryProviderCredentialStore(credentials),
        ),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore(localPath),
        ),
        providerConnectionTesterProvider.overrideWithValue(
          tester ?? FakeProviderConnectionTester(),
        ),
        inferenceHttpClientFactoryProvider.overrideWithValue(clientFactory),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);
    await container.read(providersControllerProvider.future);
    return container;
  }

  http.Client Function() recorder(
    List<http.Request> requests,
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return () => MockClient((request) {
      requests.add(request);
      return handler(request);
    });
  }

  test(
    'routes to the active OpenAI assignment and normalizes a reply',
    () async {
      final requests = <http.Request>[];
      final container = await containerFor(
        assignments: {
          ModelCapability.text: assignment(
            capability: ModelCapability.text,
            sourceId: 'openai',
            runtimeId: openAiRuntimeId,
            modelId: 'gpt-4o',
          ),
        },
        settings: {
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
          ),
        },
        credentials: {'openai': 'sk-test'},
        clientFactory: recorder(requests, (request) async {
          return http.Response(
            jsonEncode({
              'id': 'chatcmpl-1',
              'object': 'chat.completion',
              'created': 1,
              'model': 'gpt-4o',
              'choices': [
                {
                  'index': 0,
                  'message': {'role': 'assistant', 'content': 'OpenAI reply'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 4,
                'completion_tokens': 2,
                'total_tokens': 6,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await container
          .read(intelligenceEngineProvider)
          .generate(prompt());

      expect(response.text, 'OpenAI reply');
      expect(response.modelId, 'gpt-4o');
      expect(response.metadata['totalTokens'], '6');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(
        request.url.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(request.headers['authorization'], 'Bearer sk-test');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o');
      expect(body['max_completion_tokens'], 64);
      expect((body['messages'] as List).first['role'], 'system');
      expect((body['messages'] as List).last['content'], 'Hello');
    },
  );

  test('streams OpenAI chunks as cumulative snapshots', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'openai',
          runtimeId: openAiRuntimeId,
          modelId: 'gpt-4o-mini',
        ),
      },
      settings: {
        'openai': const StoredProviderSettings(
          baseUrl: 'https://api.openai.com/v1',
        ),
      },
      credentials: {'openai': 'sk-test'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          'data: ${jsonEncode(_openAiChunk('Hel'))}\n\n'
          'data: ${jsonEncode(_openAiChunk('lo'))}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await container
        .read(intelligenceEngineProvider)
        .stream(prompt())
        .toList();

    expect(events.map((event) => event.text), ['Hel', 'Hello']);
    expect(events.last.modelId, 'gpt-4o-mini');
  });

  test(
    'routes a custom OpenAI-compatible endpoint without /v1 duplication',
    () async {
      final requests = <http.Request>[];
      final container = await containerFor(
        assignments: {
          ModelCapability.text: assignment(
            capability: ModelCapability.text,
            sourceId: 'custom',
            runtimeId: openAiRuntimeId,
            modelId: 'deepseek-chat',
          ),
        },
        settings: {
          'custom': const StoredProviderSettings(
            baseUrl: 'https://api.deepseek.com',
          ),
        },
        credentials: {'custom': 'ds-test'},
        clientFactory: recorder(requests, (request) async {
          return http.Response(
            jsonEncode(_completion('Custom reply', 'deepseek-chat')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await container
          .read(intelligenceEngineProvider)
          .generate(prompt());

      expect(response.text, 'Custom reply');
      final request = requests.single;
      expect(
        request.url.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['max_tokens'], 64);
      expect(body.containsKey('max_completion_tokens'), isFalse);
    },
  );

  test('keeps identical model IDs scoped to their provider and follows Active Models changes', () async {
    final requests = <http.Request>[];
    final tester = FakeProviderConnectionTester();
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'custom-a',
          runtimeId: openAiRuntimeId,
          modelId: 'shared:model',
        ),
      },
      settings: {
        'custom-a': const StoredProviderSettings(
          baseUrl: 'https://a.example.com/v1',
          alias: 'provider-a',
        ),
        'custom-b': const StoredProviderSettings(
          baseUrl: 'https://b.example.com/v1',
          alias: 'provider-b',
        ),
      },
      credentials: {'custom-a': 'a-key', 'custom-b': 'b-key'},
      tester: tester,
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          jsonEncode(_completion('${request.url.host} reply', 'shared:model')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    tester.models['custom-a'] = const [
      ProviderModelInfo(id: 'shared:model', name: 'Shared'),
    ];
    tester.models['custom-b'] = const [
      ProviderModelInfo(id: 'shared:model', name: 'Shared'),
    ];

    final first = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(first.text, 'a.example.com reply');
    expect(first.modelId, 'shared:model');
    expect(
      requests.single.url.toString(),
      'https://a.example.com/v1/chat/completions',
    );
    expect(requests.single.headers['authorization'], 'Bearer a-key');
    expect(
      (jsonDecode(requests.single.body) as Map<String, dynamic>)['model'],
      'shared:model',
    );

    await container
        .read(providersControllerProvider.notifier)
        .updateCustomProvider(
          'custom-a',
          baseUrl: 'https://a.example.com/v1',
          alias: 'renamed-a',
        );

    final afterRename = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(afterRename.text, 'a.example.com reply');
    expect(requests, hasLength(2));
    expect(requests.last.url.host, 'a.example.com');

    await container
        .read(activeModelsProvider.notifier)
        .assignModel(
          capability: ModelCapability.text,
          sourceId: 'custom-b',
          modelId: 'shared:model',
          displayName: 'Shared',
          runtimeId: openAiRuntimeId,
        );

    final second = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(second.text, 'b.example.com reply');
    expect(second.modelId, 'shared:model');
    expect(requests, hasLength(3));
    expect(
      requests.last.url.toString(),
      'https://b.example.com/v1/chat/completions',
    );
    expect(requests.last.headers['authorization'], 'Bearer b-key');
    expect(
      (jsonDecode(requests.last.body) as Map<String, dynamic>)['model'],
      'shared:model',
    );
  });

  test('routes Mistral through the OpenAI-compatible runtime', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'mistral',
          runtimeId: openAiRuntimeId,
          modelId: 'mistral-small-latest',
        ),
      },
      settings: {
        'mistral': const StoredProviderSettings(
          baseUrl: 'https://api.mistral.ai/v1',
        ),
      },
      credentials: {'mistral': 'ms-test'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          jsonEncode(_completion('Mistral reply', 'mistral-small-latest')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(response.text, 'Mistral reply');
    final request = requests.single;
    expect(
      request.url.toString(),
      'https://api.mistral.ai/v1/chat/completions',
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['max_tokens'], 64);
    expect(body.containsKey('max_completion_tokens'), isFalse);
  });

  test('routes Anthropic through its native Messages API', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'anthropic',
          runtimeId: anthropicRuntimeId,
          modelId: 'claude-3-5-sonnet-latest',
        ),
      },
      settings: {
        'anthropic': const StoredProviderSettings(
          baseUrl: 'https://api.anthropic.com/v1',
        ),
      },
      credentials: {'anthropic': 'sk-ant'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          jsonEncode({
            'id': 'msg_1',
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'Claude reply'},
            ],
            'model': 'claude-3-5-sonnet-latest',
            'usage': {'input_tokens': 3, 'output_tokens': 2},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(response.text, 'Claude reply');
    expect(response.metadata['promptTokens'], '3');
    final request = requests.single;
    expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(request.headers['x-api-key'], 'sk-ant');
    expect(request.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['system'], 'Be concise.');
    expect(body['messages'], [
      {'role': 'user', 'content': 'Hello'},
    ]);
    expect(body['max_tokens'], 64);
  });

  test('Anthropic credential rejection is a provider failure', () async {
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'anthropic',
          runtimeId: anthropicRuntimeId,
          modelId: 'claude-3-5-sonnet-latest',
        ),
      },
      settings: {
        'anthropic': const StoredProviderSettings(
          baseUrl: 'https://api.anthropic.com/v1',
        ),
      },
      credentials: {'anthropic': 'sk-bad'},
      clientFactory: recorder([], (request) async => http.Response('{}', 401)),
    );

    await expectLater(
      container.read(intelligenceEngineProvider).generate(prompt()),
      throwsA(isA<ProviderUnavailableException>()),
    );
  });

  test('streams Anthropic content-block deltas', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'anthropic',
          runtimeId: anthropicRuntimeId,
          modelId: 'claude-3-5-sonnet-latest',
        ),
      },
      settings: {
        'anthropic': const StoredProviderSettings(
          baseUrl: 'https://api.anthropic.com/v1',
        ),
      },
      credentials: {'anthropic': 'sk-ant'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Claude "}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"reply"}}\n\n'
          'event: message_stop\n'
          'data: {"type":"message_stop"}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await container
        .read(intelligenceEngineProvider)
        .stream(prompt())
        .toList();

    expect(events.map((event) => event.text), ['Claude ', 'Claude reply']);
  });

  test('routes Gemini through the OpenAI-compatible runtime', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'google',
          runtimeId: geminiRuntimeId,
          modelId: 'gemini-2.0-flash',
        ),
      },
      settings: {
        'google': const StoredProviderSettings(
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
        ),
      },
      credentials: {'google': 'gemini-key'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          jsonEncode(_completion('Gemini reply', 'gemini-2.0-flash')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await container
        .read(intelligenceEngineProvider)
        .generate(prompt());

    expect(response.text, 'Gemini reply');
    expect(response.modelId, 'gemini-2.0-flash');
    expect(response.metadata['totalTokens'], '2');
    final request = requests.single;
    expect(
      request.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    );
    expect(request.headers['authorization'], 'Bearer gemini-key');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['model'], 'gemini-2.0-flash');
    expect(body['max_tokens'], 64);
    expect((body['messages'] as List).first['role'], 'system');
    expect((body['messages'] as List).last['content'], 'Hello');
  });

  test('streams Gemini through the OpenAI-compatible runtime', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'google',
          runtimeId: geminiRuntimeId,
          modelId: 'gemini-2.0-flash',
        ),
      },
      settings: {
        'google': const StoredProviderSettings(
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
        ),
      },
      credentials: {'google': 'gemini-key'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          'data: ${jsonEncode(_openAiChunk('Gemini '))}\n\n'
          'data: ${jsonEncode(_openAiChunk('reply'))}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await container
        .read(intelligenceEngineProvider)
        .stream(prompt())
        .toList();

    expect(events.map((event) => event.text), ['Gemini ', 'Gemini reply']);
    expect(
      requests.single.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    );
    expect(requests.single.headers['authorization'], 'Bearer gemini-key');
  });

  test('switching the active assignment switches the backend', () async {
    final requests = <http.Request>[];
    final activeStore = InMemoryActiveModelStore({
      ModelCapability.text: assignment(
        capability: ModelCapability.text,
        sourceId: 'openai',
        runtimeId: openAiRuntimeId,
        modelId: 'gpt-4o',
      ),
    });
    final container = ProviderContainer(
      overrides: [
        activeModelStoreProvider.overrideWithValue(activeStore),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        providerSettingsStoreProvider.overrideWithValue(
          InMemoryProviderSettingsStore({
            'openai': const StoredProviderSettings(
              baseUrl: 'https://api.openai.com/v1',
            ),
            'anthropic': const StoredProviderSettings(
              baseUrl: 'https://api.anthropic.com/v1',
            ),
          }),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          InMemoryProviderCredentialStore({
            'openai': 'sk-test',
            'anthropic': 'sk-ant',
          }),
        ),
        modelConfigStoreProvider.overrideWithValue(InMemoryModelConfigStore()),
        inferenceHttpClientFactoryProvider.overrideWithValue(
          recorder(requests, (request) async {
            if (request.url.host == 'api.anthropic.com') {
              return http.Response(
                jsonEncode({
                  'content': [
                    {'type': 'text', 'text': 'Anthropic reply'},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(_completion('OpenAI reply', 'gpt-4o')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);
    await container.read(providersControllerProvider.future);

    expect(
      (await container.read(intelligenceEngineProvider).generate(prompt()))
          .text,
      'OpenAI reply',
    );
    expect(requests.single.url.host, 'api.openai.com');

    activeStore.assignments = {
      ModelCapability.text: assignment(
        capability: ModelCapability.text,
        sourceId: 'anthropic',
        runtimeId: anthropicRuntimeId,
        modelId: 'claude-3-5-sonnet-latest',
      ),
    };
    container.invalidate(activeModelsProvider);
    await container.read(activeModelsProvider.future);

    expect(
      (await container.read(intelligenceEngineProvider).generate(prompt()))
          .text,
      'Anthropic reply',
    );
    expect(requests.last.url.host, 'api.anthropic.com');
  });

  test('a stale local assignment fails instead of falling back', () async {
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: localProviderId,
          runtimeId: localRuntimeId,
          modelId: 'removed-model',
        ),
      },
      clientFactory: () => MockClient(
        (request) async => throw StateError('No HTTP request expected.'),
      ),
    );

    await expectLater(
      container.read(intelligenceEngineProvider).generate(prompt()),
      throwsA(
        isA<ProviderUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('no longer available'),
        ),
      ),
    );
  });

  test(
    'legacy local text stays available beside a non-text assignment',
    () async {
      final directory = Directory.systemTemp.createTempSync('kritha-legacy-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/legacy.litertlm')
        ..writeAsBytesSync([1]);
      final container = await containerFor(
        assignments: {
          ModelCapability.vision: assignment(
            capability: ModelCapability.vision,
            sourceId: 'openai',
            runtimeId: openAiRuntimeId,
            modelId: 'gpt-4o',
          ),
        },
        settings: {
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
          ),
        },
        credentials: {'openai': 'sk-test'},
        clientFactory: () => MockClient(
          (request) async => throw StateError('No HTTP request expected.'),
        ),
        localPath: file.path,
      );

      final models = container
          .read(inferenceProvidersProvider)
          .map((provider) => provider.descriptor.id);
      expect(models, contains('local:legacy'));
      expect(models, contains('gpt-4o'));
    },
  );

  test('a missing credential is reported before any request', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'openai',
          runtimeId: openAiRuntimeId,
          modelId: 'gpt-4o',
        ),
      },
      settings: {
        'openai': const StoredProviderSettings(
          baseUrl: 'https://api.openai.com/v1',
        ),
      },
      clientFactory: recorder(requests, (request) async {
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      container.read(intelligenceEngineProvider).generate(prompt()),
      throwsA(
        isA<ProviderUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('No API key'),
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test('rejected credentials are a typed provider failure', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.text: assignment(
          capability: ModelCapability.text,
          sourceId: 'openai',
          runtimeId: openAiRuntimeId,
          modelId: 'gpt-4o',
        ),
      },
      settings: {
        'openai': const StoredProviderSettings(
          baseUrl: 'https://api.openai.com/v1',
        ),
      },
      credentials: {'openai': 'sk-bad'},
      clientFactory: recorder(requests, (request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      container.read(intelligenceEngineProvider).generate(prompt()),
      throwsA(
        isA<ProviderUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('rejected the credential'),
        ),
      ),
    );
  });

  test(
    'structured output is rejected when the model only declares text',
    () async {
      final requests = <http.Request>[];
      final container = await containerFor(
        assignments: {
          ModelCapability.text: assignment(
            capability: ModelCapability.text,
            sourceId: 'openai',
            runtimeId: openAiRuntimeId,
            modelId: 'gpt-4o',
          ),
        },
        settings: {
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
          ),
        },
        credentials: {'openai': 'sk-test'},
        clientFactory: recorder(requests, (request) async {
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        container
            .read(intelligenceEngineProvider)
            .generate(prompt(responseSchema: {'type': 'object'})),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test('a vision-only assignment cannot serve text generation', () async {
    final requests = <http.Request>[];
    final container = await containerFor(
      assignments: {
        ModelCapability.vision: assignment(
          capability: ModelCapability.vision,
          sourceId: 'openai',
          runtimeId: openAiRuntimeId,
          modelId: 'gpt-4o',
        ),
      },
      settings: {
        'openai': const StoredProviderSettings(
          baseUrl: 'https://api.openai.com/v1',
        ),
      },
      credentials: {'openai': 'sk-test'},
      clientFactory: recorder(requests, (request) async {
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      container.read(intelligenceEngineProvider).generate(prompt()),
      throwsA(isA<UnsupportedCapabilityException>()),
    );
    expect(requests, isEmpty);
  });
}

Map<String, dynamic> _completion(String text, String model) => {
  'id': 'chatcmpl-1',
  'object': 'chat.completion',
  'created': 1,
  'model': model,
  'choices': [
    {
      'index': 0,
      'message': {'role': 'assistant', 'content': text},
      'finish_reason': 'stop',
    },
  ],
  'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
};

Map<String, dynamic> _openAiChunk(String text) => {
  'id': 'chatcmpl-1',
  'object': 'chat.completion.chunk',
  'created': 1,
  'model': 'gpt-4o-mini',
  'choices': [
    {
      'index': 0,
      'delta': {'content': text},
      'finish_reason': null,
    },
  ],
};
