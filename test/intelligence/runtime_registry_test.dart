import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/model_descriptor.dart';
import 'package:kritha/features/intelligence/runtime_registry.dart';

class _FakeRuntime implements LocalRuntime {
  @override
  Future<void> initialize() async {}

  @override
  Future<String> generate(AiRequest request) async => 'ok';

  @override
  Stream<String> stream(AiRequest request) => Stream<String>.value('ok');

  @override
  Future<void> dispose() async {}
}

void main() {
  const model = ModelDescriptor(
    id: 'local-model',
    displayName: 'Local model',
    runtimeId: 'fake',
    capabilities: ModelCapabilities.textOnly,
  );
  final request = AiRequest(messages: [AiMessage.user('hello')]);

  test('selects a compatible registered runtime deterministically', () {
    final registry = RuntimeRegistry(
      registrations: [
        RuntimeRegistration(
          id: 'fake',
          displayName: 'Fake runtime',
          tasks: {InferenceCapability.textGeneration},
          modalities: {'text'},
          platforms: {'test'},
          formats: {'test'},
          isAvailable: () => true,
          compatibility: (_, _, artifacts) => artifacts.isEmpty
              ? const RuntimeCompatibility.ok()
              : const RuntimeCompatibility.incompatible('unexpected artifact'),
          create: (_, _) => _FakeRuntime(),
        ),
      ],
    );

    expect(
      registry
          .select(
            model: model,
            request: request,
            artifacts: const [],
            platform: 'test',
          )
          .id,
      'fake',
    );
  });

  test('a second runtime can be registered without changing the provider', () {
    final registry = RuntimeRegistry();
    registry.register(
      RuntimeRegistration(
        id: 'first',
        displayName: 'First',
        tasks: {InferenceCapability.textGeneration},
        modalities: {'text'},
        platforms: {'test'},
        formats: {'test'},
        isAvailable: () => false,
        compatibility: (_, _, _) => const RuntimeCompatibility.ok(),
        create: (_, _) => _FakeRuntime(),
      ),
    );
    registry.register(
      RuntimeRegistration(
        id: 'second',
        displayName: 'Second',
        tasks: {InferenceCapability.textGeneration},
        modalities: {'text'},
        platforms: {'test'},
        formats: {'test'},
        isAvailable: () => true,
        compatibility: (_, _, _) => const RuntimeCompatibility.ok(),
        create: (_, _) => _FakeRuntime(),
      ),
    );

    expect(
      registry
          .select(
            model: model,
            request: request,
            artifacts: const [],
            platform: 'test',
          )
          .id,
      'second',
    );
  });
}
