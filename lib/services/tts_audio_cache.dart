import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/intelligence/intelligence_engine.dart';
import '../features/intelligence/providers/provider.dart';

/// Process-lifetime TTS audio cache. Audio is retained only in memory, so it
/// disappears with the application process.
class TtsAudioCache {
  static const _maxEntries = 24;
  static const _maxBytes = 48 * 1024 * 1024;

  final LinkedHashMap<String, SynthesizedSpeech> _entries = LinkedHashMap();
  int _bytes = 0;

  Future<SynthesizedSpeech> synthesize({
    required IntelligenceEngine engine,
    required String modelId,
    required String text,
    required bool enabled,
  }) async {
    if (!enabled) {
      return engine.synthesizeSpeech(text: text, modelId: modelId);
    }

    final key = await engine.synthesizeSpeechCacheKey(
      text: text,
      modelId: modelId,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }

    final speech = await engine.synthesizeSpeech(
      text: text,
      modelId: modelId,
    );
    _store(key, speech);
    return speech;
  }

  void _store(String key, SynthesizedSpeech speech) {
    final replaced = _entries.remove(key);
    if (replaced != null) _bytes -= replaced.bytes.length;
    _entries[key] = speech;
    _bytes += speech.bytes.length;
    while (_entries.length > _maxEntries || _bytes > _maxBytes) {
      final oldest = _entries.keys.first;
      final removed = _entries.remove(oldest);
      _bytes -= removed?.bytes.length ?? 0;
      if (_bytes < 0) _bytes = 0;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

final ttsAudioCacheProvider = Provider<TtsAudioCache>((ref) {
  final cache = TtsAudioCache();
  ref.onDispose(cache.clear);
  return cache;
});
