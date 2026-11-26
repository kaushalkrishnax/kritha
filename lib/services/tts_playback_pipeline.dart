import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../features/intelligence/intelligence_engine.dart';
import '../features/intelligence/providers/provider.dart';
import 'tts_audio_cache.dart';

/// Minimal playlist-capable player contract used by [TtsPlaybackPipeline].
abstract class TtsAudioPlayer {
  Stream<int?> get currentIndexStream;
  Stream<ProcessingState> get processingStateStream;
  int? get currentIndex;
  ProcessingState get processingState;
  bool get playing;

  Future<void> setAudioFiles(List<String> paths);
  Future<void> addAudioFile(String path);
  Future<void> seekToIndex(int index);
  Future<void> play();
  Future<void> stop();
}

class _JustAudioTtsPlayer implements TtsAudioPlayer {
  _JustAudioTtsPlayer(this._player);

  final AudioPlayer _player;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  @override
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  @override
  int? get currentIndex => _player.currentIndex;
  @override
  ProcessingState get processingState => _player.processingState;
  @override
  bool get playing => _player.playing;

  @override
  Future<void> setAudioFiles(List<String> paths) => _player.setAudioSources([
    for (final path in paths) AudioSource.file(path),
  ]);
  @override
  Future<void> addAudioFile(String path) =>
      _player.addAudioSource(AudioSource.file(path));
  @override
  Future<void> seekToIndex(int index) =>
      _player.seek(Duration.zero, index: index);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> stop() => _player.stop();
}

/// Plays TTS text chunks in strict sequential order via a live playlist.
///
/// Keeps at most one chunk synthesised ahead of the active item. Temporary
/// files are deleted only after the player has advanced past them. All
/// in-flight work is cancelled and cleaned up on [cancel].
class TtsPlaybackPipeline {
  TtsPlaybackPipeline({
    required this.engine,
    required this.cache,
    required this.modelId,
    required this.cachingEnabled,
    AudioPlayer? player,
    TtsAudioPlayer? queuePlayer,
    this.onFirstAudio,
    this.onCompleted,
    this.onError,
  }) : assert(
         player != null || queuePlayer != null,
         'Either player or queuePlayer must be provided.',
       ),
       _player = queuePlayer ?? _JustAudioTtsPlayer(player!);

  final IntelligenceEngine engine;
  final TtsAudioCache cache;
  final String modelId;
  final bool cachingEnabled;
  final TtsAudioPlayer _player;
  final void Function()? onFirstAudio;
  final void Function()? onCompleted;
  final void Function(Object error)? onError;

  final Queue<_TtsChunk> _pending = Queue();
  final List<String> _appendedPaths = [];
  final Set<int> _deletedIndices = {};

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<ProcessingState>? _stateSub;

  // Resolved once and reused across all chunks.
  Future<Directory>? _tempDirFuture;

  int _generation = 0;
  int _lastObservedIndex = -1;
  bool _playlistStarted = false;
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
    await _cancelSubscriptions();
    try {
      await _player.stop();
    } on Object {
      // Best-effort.
    }
    _deleteAllFiles();
    if (!_done.isCompleted) _done.complete();
  }

  void _ensureWorker() {
    if (_running || (_sealed && _pending.isEmpty)) return;
    _running = true;
    unawaited(_run(_generation));
  }

  void _prefetchNext(int generation) {
    if (_pending.length < 2) return;
    final next = _pending.elementAt(1);
    next.synthesis ??= _synthesize(next.text, generation);
  }

  void _attachListeners(int generation) {
    _indexSub = _player.currentIndexStream.listen((index) {
      if (generation != _generation || index == null) return;
      if (index > _lastObservedIndex) {
        for (var i = 0; i < index; i++) {
          _deleteFile(i);
        }
        _lastObservedIndex = index;
        // Unblock the worker so it can queue the next chunk.
        _wake?.complete();
        _wake = null;
      }
      _checkFinished();
    });

    _stateSub = _player.processingStateStream.listen((ps) {
      if (generation == _generation && ps == ProcessingState.completed) {
        _checkFinished();
      }
    });
  }

  void _checkFinished() {
    if (!_sealed || _pending.isNotEmpty || !_playlistStarted) return;
    final lastIndex = _appendedPaths.length - 1;
    final current = _player.currentIndex ?? _lastObservedIndex;
    if (_player.processingState == ProcessingState.completed &&
        current >= lastIndex) {
      _deleteAllFiles();
      if (!_done.isCompleted) _done.complete();
      onCompleted?.call();
    }
  }

  Future<void> _run(int generation) async {
    try {
      _tempDirFuture ??= getTemporaryDirectory();
      while (true) {
        if (generation != _generation) return;

        if (_pending.isEmpty) {
          if (_sealed) {
            // Wait for the player to complete the last item.
            if (_playlistStarted && !_done.isCompleted) {
              final waiter = Completer<void>();
              _wake = waiter;
              await waiter.future;
            }
            return;
          }
          final waiter = Completer<void>();
          _wake = waiter;
          await waiter.future;
          continue;
        }

        // Backpressure: at most 1 chunk ahead of the active item.
        if (_playlistStarted) {
          final ahead = _appendedPaths.length - (_lastObservedIndex < 0 ? 0 : _lastObservedIndex);
          if (ahead >= 2) {
            final waiter = Completer<void>();
            _wake = waiter;
            await waiter.future;
            continue;
          }
        }

        final chunk = _pending.first;
        chunk.synthesis ??= _synthesize(chunk.text, generation);
        _prefetchNext(generation);

        final speech = await chunk.synthesis!;
        if (generation != _generation) return;
        _pending.removeFirst();
        if (speech == null) continue;

        final path = await _writeTempFile(speech, generation);
        if (path == null || generation != _generation) {
          if (path != null) unawaited(_deleteFilePath(path));
          return;
        }

        final chunkIndex = _appendedPaths.length;
        _appendedPaths.add(path);

        try {
          if (!_playlistStarted) {
            _attachListeners(generation);
            await _player.setAudioFiles([path]);
            if (generation != _generation) return;
            _playlistStarted = true;
            _lastObservedIndex = 0;
            if (!_playedAny) {
              _playedAny = true;
              onFirstAudio?.call();
            }
            unawaited(_player.play());
          } else {
            final wasEnded = _player.processingState == ProcessingState.completed ||
                !_player.playing;
            await _player.addAudioFile(path);
            if (generation != _generation) return;
            if (wasEnded) {
              await _player.seekToIndex(chunkIndex);
              if (generation != _generation) return;
              unawaited(_player.play());
            }
          }
        } on Object catch (e) {
          _firstError ??= e;
          onError?.call(e);
        }
      }
    } finally {
      if (generation == _generation) {
        _running = false;
        await _cancelSubscriptions();
        _deleteAllFiles();
        if (!_done.isCompleted) _done.complete();
        if (_playlistStarted) onCompleted?.call();
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
    } on Object catch (e) {
      if (generation == _generation) {
        _firstError ??= e;
        onError?.call(e);
      }
      return null;
    }
  }

  Future<String?> _writeTempFile(SynthesizedSpeech speech, int generation) async {
    try {
      final dir = await _tempDirFuture!;
      final ext = _ext(speech.mimeType);
      final file = File(
        '${dir.path}/kritha_tts_${DateTime.now().microsecondsSinceEpoch}_${_appendedPaths.length}.$ext',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      if (generation != _generation) {
        unawaited(_deleteFilePath(file.path));
        return null;
      }
      return file.path;
    } on Object catch (e) {
      if (generation == _generation) {
        _firstError ??= e;
        onError?.call(e);
      }
      return null;
    }
  }

  static String _ext(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('wav')) return 'wav';
    if (m.contains('ogg')) return 'ogg';
    if (m.contains('aac')) return 'aac';
    if (m.contains('flac')) return 'flac';
    return 'mp3';
  }

  void _deleteFile(int index) {
    if (index >= 0 && index < _appendedPaths.length && _deletedIndices.add(index)) {
      unawaited(_deleteFilePath(_appendedPaths[index]));
    }
  }

  void _deleteAllFiles() {
    for (var i = 0; i < _appendedPaths.length; i++) {
      _deleteFile(i);
    }
  }

  static Future<void> _deleteFilePath(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } on Object {
      // OS reclaims temp files.
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _indexSub?.cancel();
    _indexSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
  }
}

class _TtsChunk {
  _TtsChunk(this.text);
  final String text;
  Future<SynthesizedSpeech?>? synthesis;
}
