import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../features/intelligence/intelligence_engine.dart';
import '../features/intelligence/providers/provider.dart';
import 'tts_audio_cache.dart';

/// Plays TTS text chunks in order while synthesizing the next chunk.
///
/// The pipeline keeps at most one synthesis ahead of playback, so audio starts
/// as soon as the first chunk is ready without firing every sentence request at
/// once. Cancelling invalidates in-flight work so stale audio never resumes.
class TtsPlaybackPipeline {
  TtsPlaybackPipeline({
    required this.engine,
    required this.cache,
    required this.modelId,
    required this.cachingEnabled,
    required this.player,
    this.onFirstAudio,
    this.onCompleted,
    this.onError,
  });

  final IntelligenceEngine engine;
  final TtsAudioCache cache;
  final String modelId;
  final bool cachingEnabled;
  final AudioPlayer player;
  final void Function()? onFirstAudio;
  final void Function()? onCompleted;
  final void Function(Object error)? onError;

  final Queue<_TtsChunk> _pending = Queue();
  final Set<String> _temporaryFiles = {};

  int _generation = 0;
  bool _running = false;
  bool _sealed = false;
  bool _cancelled = false;
  bool _playedAny = false;
  Completer<void>? _wake;
  final Completer<void> _done = Completer<void>();

  Object? _firstError;

  Object? get firstError => _firstError;
  bool get playedAny => _playedAny;

  void addText(String text) {
    if (_sealed) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _pending.add(_TtsChunk(trimmed));
    _wake?.complete();
    _wake = null;
    _startIfRunning();
    _ensureWorker();
  }

  Future<void> finish() {
    _sealed = true;
    _wake?.complete();
    _wake = null;
    if (!_running && !_done.isCompleted) _done.complete();
    return _done.future;
  }

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _generation++;
    _sealed = true;
    _pending.clear();
    _wake?.complete();
    _wake = null;
    try {
      await player.stop();
    } on Object {
      // The player may already be stopped or disposed.
    }
    _deleteTemporaryFiles();
    if (!_done.isCompleted) _done.complete();
  }

  void _ensureWorker() {
    if (_running || (_sealed && _pending.isEmpty)) return;
    _running = true;
    unawaited(_run(_generation));
  }

  void _startIfRunning() {
    if (!_running || _pending.isEmpty) return;
    final first = _pending.first;
    first.synthesis ??= _synthesize(first.text, _generation);
  }

  void _startPrefetch(int generation) {
    if (_pending.length < 2) return;
    final next = _pending.elementAt(1);
    next.synthesis ??= _synthesize(next.text, generation);
  }

  Future<void> _run(int generation) async {
    try {
      while (true) {
        if (generation != _generation) return;
        if (_pending.isEmpty) {
          if (_sealed) return;
          final waiter = Completer<void>();
          _wake = waiter;
          await waiter.future;
          if (generation != _generation) return;
          continue;
        }

        final chunk = _pending.first;
        chunk.synthesis ??= _synthesize(chunk.text, generation);
        _startPrefetch(generation);
        final speech = await chunk.synthesis!;
        if (generation != _generation) return;
        _pending.removeFirst();
        if (speech == null) continue;

        final path = await _writeTemporaryFile(speech, generation);
        if (path == null) continue;
        try {
          if (generation != _generation) return;
          await player.setFilePath(path);
          if (generation != _generation) return;
          final playback = player.play();
          _startIfRunning();
          if (!_playedAny) {
            _playedAny = true;
            onFirstAudio?.call();
          }
          await playback;
        } on Object catch (error) {
          _firstError ??= error;
          onError?.call(error);
        } finally {
          _deleteTemporaryFile(path);
        }
        if (generation != _generation) return;
      }
    } finally {
      if (generation == _generation) {
        _running = false;
        _deleteTemporaryFiles();
        if (!_done.isCompleted) _done.complete();
        onCompleted?.call();
      }
    }
  }

  Future<SynthesizedSpeech?> _synthesize(String text, int generation) async {
    try {
      return await cache.synthesize(
        engine: engine,
        modelId: modelId,
        text: text,
        enabled: cachingEnabled,
      );
    } on Object catch (error) {
      if (generation == _generation) {
        _firstError ??= error;
        onError?.call(error);
      }
      return null;
    }
  }

  Future<String?> _writeTemporaryFile(
    SynthesizedSpeech speech,
    int generation,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final extension = _extensionFor(speech.mimeType);
      final file = File(
        '${directory.path}/kritha_tts_${DateTime.now().microsecondsSinceEpoch}_${_temporaryFiles.length}.$extension',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      if (generation != _generation) {
        await _deleteFile(file.path);
        return null;
      }
      _temporaryFiles.add(file.path);
      return file.path;
    } on Object catch (error) {
      if (generation == _generation) {
        _firstError ??= error;
        onError?.call(error);
      }
      return null;
    }
  }

  static String _extensionFor(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.contains('wav')) return 'wav';
    if (mime.contains('ogg')) return 'ogg';
    if (mime.contains('aac')) return 'aac';
    if (mime.contains('flac')) return 'flac';
    return 'mp3';
  }

  void _deleteTemporaryFile(String path) {
    _temporaryFiles.remove(path);
    unawaited(_deleteFile(path));
  }

  void _deleteTemporaryFiles() {
    final paths = List<String>.from(_temporaryFiles);
    _temporaryFiles.clear();
    for (final path in paths) {
      unawaited(_deleteFile(path));
    }
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object {
      // Temporary files are also reclaimed by the OS.
    }
  }
}

class _TtsChunk {
  _TtsChunk(this.text);

  final String text;
  Future<SynthesizedSpeech?>? synthesis;
}
