import 'package:flutter/foundation.dart';

import 'inference_provider.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';

/// Decorator recording usage events without coupling adapters to persistence.
class UsageTrackingInferenceProvider implements InferenceProvider {
  UsageTrackingInferenceProvider({
    required this.inner,
    required this.onRequestSettled,
  });

  final InferenceProvider inner;
  final void Function(bool ok) onRequestSettled;

  @override
  String get alias => inner.alias;

  @override
  ProviderConfig get config => inner.config;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => inner.lifecycle;

  @override
  bool get isInitialized => inner.isInitialized;

  @override
  Future<void> initialize() => inner.initialize();

  @override
  Future<List<DiscoveredModel>> discoverModels() => inner.discoverModels();

  @override
  Future<ProviderTestResult> test() => inner.test();

  @override
  Future<AiResponse> generate(AiRequest request, ProviderModel model) async {
    try {
      final response = await inner.generate(request, model);
      onRequestSettled(true);
      return response;
    } on Object {
      onRequestSettled(false);
      rethrow;
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request, ProviderModel model) async* {
    var settled = false;
    try {
      await for (final response in inner.stream(request, model)) {
        yield response;
      }
      settled = true;
      onRequestSettled(true);
    } on Object {
      settled = true;
      onRequestSettled(false);
      rethrow;
    } finally {
      if (!settled) onRequestSettled(false);
    }
  }

  @override
  Future<void> dispose() => inner.dispose();
}
