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

/// Synthesizes assistant replies through the active TTS model and plays audio.
class SpeechPlaybackNotifier extends Notifier<SpeechPlaybackState> {
  AudioPlayer? _player;
  String? _tempPath;

  @override
  SpeechPlaybackState build() {
    ref.onDispose(() {
      _player?.dispose();
      _player = null;
      _cleanupTempFile();
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

    state = SpeechPlaybackState(playingMessageId: messageId, loading: true);
    try {
      final speech = await ref
          .read(intelligenceEngineProvider)
          .synthesizeSpeech(text: trimmed, modelId: ttsModelId);
      if (!ref.mounted) return;
      final dir = await getTemporaryDirectory();
      final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
      final file = File(
        '${dir.path}/kritha_tts_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      _cleanupTempFile();
      _tempPath = file.path;

      final player = _player ??= AudioPlayer();
      await player.setFilePath(file.path);
      if (!ref.mounted) return;
      state = SpeechPlaybackState(playingMessageId: messageId, loading: false);
      unawaitedPlayerCompletion(player, messageId);
      await player.play();
    } on Object {
      if (ref.mounted) {
        state = const SpeechPlaybackState();
      }
      rethrow;
    }
  }

  void unawaitedPlayerCompletion(AudioPlayer player, String messageId) {
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
    _cleanupTempFile();
    if (ref.mounted) {
      state = const SpeechPlaybackState();
    }
  }

  void _cleanupTempFile() {
    final path = _tempPath;
    _tempPath = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // Temp cleanup is best-effort.
    }
  }
}

final speechPlaybackProvider =
    NotifierProvider<SpeechPlaybackNotifier, SpeechPlaybackState>(
      SpeechPlaybackNotifier.new,
    );
