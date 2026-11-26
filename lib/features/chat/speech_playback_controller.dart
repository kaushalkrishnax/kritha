import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/device_tts_service.dart';
import '../../services/tts_audio_cache.dart';
import '../../services/tts_playback_pipeline.dart';
import '../../services/tts_settings.dart';
import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';

/// Splits text into sentence-sized TTS chunks while preserving every sentence
/// and its order. A tiny final fragment is joined to the previous sentence so
/// it is not sent as an isolated, unnaturally short utterance.
List<String> splitTtsSentences(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final parts = trimmed.split(RegExp(r'(?<=[.!?…])\s+|\n+'));
  final result = <String>[];
  for (final part in parts) {
    final sentence = part.trim();
    if (sentence.isEmpty) continue;
    result.add(sentence);
  }
  if (result.length > 1 && result.last.length < 18) {
    final tail = result.removeLast();
    result[result.length - 1] = '${result.last} $tail';
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

/// Synthesizes assistant replies with application-managed streaming and an
/// in-memory audio cache. Streaming mode pipelines sentence synthesis behind
/// playback; non-streaming mode sends the whole reply in one request.
///
/// Speak requests are queued: an in-play message runs to completion before the
/// next queued message starts, so chunks are never dropped or interrupted.
class SpeechPlaybackNotifier extends Notifier<SpeechPlaybackState> {
  AudioPlayer? _player;
  TtsPlaybackPipeline? _pipeline;
  DeviceTtsSession? _deviceTts;
  int _playEpoch = 0;
  final Queue<({String messageId, String text})> _queue = Queue();
  bool _draining = false;

  @override
  SpeechPlaybackState build() {
    ref.onDispose(() {
      _playEpoch++;
      _pipeline?.cancel();
      _pipeline = null;
      _deviceTts?.cancel();
      _deviceTts = null;
      _player?.dispose();
      _player = null;
      _queue.clear();
      _draining = false;
    });
    return const SpeechPlaybackState();
  }

  Future<void> toggleSpeak({
    required String messageId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Tapping the same message while it plays stops it (toggle off).
    if (state.playingMessageId == messageId) {
      await stop();
      return;
    }

    // Do not duplicate an already-queued message.
    if (_queue.any((r) => r.messageId == messageId)) return;

    _queue.add((messageId: messageId, text: trimmed));
    if (!_draining) {
      unawaited(_drainQueue());
    }
  }

  Future<void> _drainQueue() async {
    if (_draining || _queue.isEmpty || !ref.mounted) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && ref.mounted) {
        final request = _queue.removeFirst();
        await _playRequest(messageId: request.messageId, text: request.text);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _playRequest({
    required String messageId,
    required String text,
  }) async {
    final epoch = ++_playEpoch;
    state = SpeechPlaybackState(playingMessageId: messageId, loading: true);

    final active = await ref.read(activeModelsProvider.future);
    if (epoch != _playEpoch || !ref.mounted) return;
    final ttsModelId =
        active.executableSelection[AiTaskId.textToSpeech] ??
        active.singleModels[ModelCapability.textToSpeech];

    final settings = await ref
        .read(ttsSettingsProvider.notifier)
        .readSettings();
    if (epoch != _playEpoch || !ref.mounted) return;

    final chunks = settings.streaming
        ? splitTtsSentences(text)
        : <String>[text];

    if (ttsModelId == null || ttsModelId.trim().isEmpty) {
      final session = DeviceTtsSession(
        driver: ref.read(deviceTtsDriverProvider),
        onFirstAudio: () {
          if (epoch != _playEpoch || !ref.mounted) return;
          state = SpeechPlaybackState(
            playingMessageId: messageId,
            loading: false,
          );
        },
      );
      _deviceTts = session;
      for (final chunk in chunks) {
        session.addText(chunk);
      }
      try {
        await session.finish();
        if (epoch == _playEpoch && ref.mounted) {
          if (session.firstError != null && !session.playedAny) {
            throw SpeechPlaybackException('${session.firstError}');
          }
          state = const SpeechPlaybackState();
        }
      } on Object {
        if (epoch == _playEpoch && ref.mounted) {
          state = const SpeechPlaybackState();
        }
        rethrow;
      } finally {
        if (identical(_deviceTts, session)) _deviceTts = null;
      }
      return;
    }

    final player = _player ??= AudioPlayer();
    final pipeline = TtsPlaybackPipeline(
      engine: ref.read(intelligenceEngineProvider),
      cache: ref.read(ttsAudioCacheProvider),
      modelId: ttsModelId,
      cachingEnabled: settings.caching,
      player: player,
      onFirstAudio: () {
        if (epoch != _playEpoch || !ref.mounted) return;
        state = SpeechPlaybackState(
          playingMessageId: messageId,
          loading: false,
        );
      },
    );
    _pipeline = pipeline;

    for (final chunk in chunks) {
      pipeline.addText(chunk);
    }

    try {
      await pipeline.finish();
      if (epoch == _playEpoch && ref.mounted) {
        if (pipeline.firstError != null && !pipeline.playedAny) {
          throw SpeechPlaybackException('${pipeline.firstError}');
        }
        state = const SpeechPlaybackState();
      }
    } on SpeechPlaybackException {
      if (epoch == _playEpoch && ref.mounted) {
        state = const SpeechPlaybackState();
      }
      rethrow;
    } on Object {
      if (epoch == _playEpoch && ref.mounted) {
        state = const SpeechPlaybackState();
      }
      rethrow;
    } finally {
      if (identical(_pipeline, pipeline)) _pipeline = null;
    }
  }

  Future<void> stop() async {
    _playEpoch++;
    _queue.clear();
    final pipeline = _pipeline;
    _pipeline = null;
    await pipeline?.cancel();
    final deviceTts = _deviceTts;
    _deviceTts = null;
    await deviceTts?.cancel();
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
