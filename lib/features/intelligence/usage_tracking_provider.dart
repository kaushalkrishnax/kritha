import 'package:flutter/foundation.dart';

import 'inference_provider.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_descriptor.dart';

/// Records one local usage event for every provider request that settles.
///
/// The decorator keeps the provider adapters free of persistence concerns while
/// still counting requests at the same boundary the app invokes them.
class UsageTrackingInferenceProvider implements InferenceProvider {
  UsageTrackingInferenceProvider({
    required this.inner,
    required this.onRequestSettled,
  });

  final InferenceProvider inner;
  final void Function(bool ok) onRequestSettled;

  @override
  String get id => inner.id;

  @override
  ModelDescriptor get descriptor => inner.descriptor;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => inner.lifecycle;

  @override
  bool get isInitialized => inner.isInitialized;

  @override
  Future<void> initialize() => inner.initialize();

  @override
  Future<AiResponse> generate(AiRequest request) async {
    try {
      final response = await inner.generate(request);
      onRequestSettled(true);
      return response;
    } on Object {
      onRequestSettled(false);
      rethrow;
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request) async* {
    var settled = false;
    try {
      await for (final response in inner.stream(request)) {
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
