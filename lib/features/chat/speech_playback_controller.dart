import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';

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

/// Synthesizes assistant replies through the active TTS model, caching audio on disk.
class SpeechPlaybackNotifier extends Notifier<SpeechPlaybackState> {
  AudioPlayer? _player;
  final Map<String, String> _memoryCache = {};

  @override
  SpeechPlaybackState build() {
    ref.onDispose(() {
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final active = await ref.read(activeModelsProvider.future);
    final ttsModelId =
        active.executableSelection[AiTaskId.textToSpeech] ??
        active.singleModels[ModelCapability.textToSpeech];
    if (ttsModelId == null || ttsModelId.trim().isEmpty) {
      throw const SpeechPlaybackException(
        'No Text to speech model assigned. Assign one in Active Models.',
      );
    }

    final cacheKey = '${ttsModelId}_${Object.hash(ttsModelId, trimmed)}';
    state = SpeechPlaybackState(playingMessageId: messageId, loading: true);
    try {
      var filePath = await _lookupCachedFile(cacheKey);
      if (filePath == null) {
        final speech = await ref
            .read(intelligenceEngineProvider)
            .synthesizeSpeech(text: trimmed, modelId: ttsModelId);
        if (!ref.mounted) return;
        final cacheDir = await _cacheDir();
        final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
        final file = File('${cacheDir.path}/$cacheKey.$ext');
        await file.writeAsBytes(speech.bytes, flush: true);
        filePath = file.path;
        _memoryCache[cacheKey] = filePath;
      }

      final player = _player ??= AudioPlayer();
      await player.setFilePath(filePath);
      if (!ref.mounted) return;
      state = SpeechPlaybackState(playingMessageId: messageId, loading: false);
      _listenCompletion(player, messageId);
      await player.play();
    } on Object {
      if (ref.mounted) {
        state = const SpeechPlaybackState();
      }
      rethrow;
    }
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

  void _listenCompletion(AudioPlayer player, String messageId) {
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed &&
          ref.mounted &&
          state.playingMessageId == messageId) {
        state = const SpeechPlaybackState();
      }
    });
  }

  Future<void> stop() async {
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
