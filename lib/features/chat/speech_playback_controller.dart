import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';

/// Splits text into natural sentence chunks for low-latency streamed TTS.
List<String> splitTtsSentences(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  final raw = trimmed.split(RegExp(r'(?<=[.!?])\s+|\n+'));
  final result = <String>[];
  final buffer = StringBuffer();
  for (final part in raw) {
    final s = part.trim();
    if (s.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(s);
    if (buffer.length >= 28) {
      result.add(buffer.toString());
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) {
    if (result.isNotEmpty && buffer.length < 18) {
      result[result.length - 1] = '${result.last} ${buffer.toString()}';
    } else {
      result.add(buffer.toString());
    }
  }
  return result;
}

class SpeechPlaybackState {
  const SpeechPlaybackState({this.playingMessageId, this.loading = false});

  final String? playingMessageId;
  final bool loading;

  bool isPlaying(String messageId) => playingMessageId == messageId;
}

class SpeechPlaybackException implements Exception {
  const SpeechPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Synthesizes assistant replies sentence-by-sentence with disk caching for fast start.
class SpeechPlaybackNotifier extends Notifier<SpeechPlaybackState> {
  AudioPlayer? _player;
  final Map<String, String> _memoryCache = {};
  int _playEpoch = 0;

  @override
  SpeechPlaybackState build() {
    ref.onDispose(() {
      _playEpoch++;
      _player?.dispose();
      _player = null;
    });
    return const SpeechPlaybackState();
  }

  Future<void> toggleSpeak({
    required String messageId,
    required String text,
  }) async {
    if (state.playingMessageId == messageId) {
      await stop();
      return;
    }
    await stop();
    final sentences = splitTtsSentences(text);
    if (sentences.isEmpty) return;

    final active = await ref.read(activeModelsProvider.future);
    final ttsModelId =
        active.executableSelection[AiTaskId.textToSpeech] ??
        active.singleModels[ModelCapability.textToSpeech];
    if (ttsModelId == null || ttsModelId.trim().isEmpty) {
      throw const SpeechPlaybackException(
        'No Text to speech model assigned. Assign one in Active Models.',
      );
    }

    final epoch = ++_playEpoch;
    state = SpeechPlaybackState(playingMessageId: messageId, loading: true);
    try {
      // Kick off sentence synthesis sequentially in-order, starting playback on chunk 0.
      final futures = <Future<String>>[
        for (final sentence in sentences)
          _synthesizeCached(ttsModelId: ttsModelId, text: sentence),
      ];

      final player = _player ??= AudioPlayer();
      for (var i = 0; i < futures.length; i++) {
        final path = await futures[i];
        if (epoch != _playEpoch || !ref.mounted) return;
        await player.setFilePath(path);
        if (epoch != _playEpoch || !ref.mounted) return;
        if (i == 0) {
          state = SpeechPlaybackState(
            playingMessageId: messageId,
            loading: false,
          );
        }
        await player.play();
      }
      if (epoch == _playEpoch && ref.mounted) {
        state = const SpeechPlaybackState();
      }
    } on Object {
      if (epoch == _playEpoch && ref.mounted) {
        state = const SpeechPlaybackState();
      }
      rethrow;
    }
  }

  Future<String> _synthesizeCached({
    required String ttsModelId,
    required String text,
  }) async {
    final cacheKey = '${ttsModelId}_${Object.hash(ttsModelId, text)}';
    final cached = await _lookupCachedFile(cacheKey);
    if (cached != null) return cached;

    final speech = await ref
        .read(intelligenceEngineProvider)
        .synthesizeSpeech(text: text, modelId: ttsModelId);
    final cacheDir = await _cacheDir();
    final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
    final file = File('${cacheDir.path}/$cacheKey.$ext');
    await file.writeAsBytes(speech.bytes, flush: true);
    _memoryCache[cacheKey] = file.path;
    return file.path;
  }

  Future<Directory> _cacheDir() async {
    final dir = await getTemporaryDirectory();
    final cache = Directory('${dir.path}/kritha_tts_cache');
    if (!cache.existsSync()) cache.createSync(recursive: true);
    return cache;
  }

  Future<String?> _lookupCachedFile(String cacheKey) async {
    final mem = _memoryCache[cacheKey];
    if (mem != null && File(mem).existsSync() && File(mem).lengthSync() > 0) {
      return mem;
    }
    final dir = await _cacheDir();
    for (final ext in const ['wav', 'mp3']) {
      final candidate = File('${dir.path}/$cacheKey.$ext');
      if (candidate.existsSync() && candidate.lengthSync() > 0) {
        _memoryCache[cacheKey] = candidate.path;
        return candidate.path;
      }
    }
    return null;
  }

  Future<void> stop() async {
    _playEpoch++;
    try {
      await _player?.stop();
    } on Object {
      // Stopping playback is best-effort.
    }
    if (ref.mounted) {
      state = const SpeechPlaybackState();
    }
  }
}

final speechPlaybackProvider =
    NotifierProvider<SpeechPlaybackNotifier, SpeechPlaybackState>(
      SpeechPlaybackNotifier.new,
    );
