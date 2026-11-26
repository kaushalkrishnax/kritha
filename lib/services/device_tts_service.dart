import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Abstracted OS TTS driver — testable without a real FlutterTts instance.
abstract class DeviceTtsDriver {
  Future<void> configure();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

class _FlutterTtsDriver implements DeviceTtsDriver {
  _FlutterTtsDriver(this._tts);

  final FlutterTts _tts;
  bool _ready = false;

  @override
  Future<void> configure() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  @override
  Future<void> speak(String text) async {
    // flutter_tts returns 1 on success, 0 on failure (wraps Android TTS.SUCCESS).
    final result = await _tts.speak(text);
    if (result == 0) throw StateError('Device TTS failed to speak.');
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}

/// Queues text chunks and speaks them sequentially via the device TTS engine.
///
/// Mirrors [TtsPlaybackPipeline]'s lifecycle so callers treat both uniformly.
class DeviceTtsSession {
  DeviceTtsSession({
    DeviceTtsDriver? driver,
    this.onFirstAudio,
    this.onCompleted,
    this.onError,
  }) : _driver = driver ?? _FlutterTtsDriver(FlutterTts());

  final DeviceTtsDriver _driver;
  final void Function()? onFirstAudio;
  final void Function()? onCompleted;
  final void Function(Object error)? onError;

  final Queue<String> _pending = Queue();
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
    final t = text.trim();
    if (t.isEmpty) return;
    _pending.add(t);
    _wake?.complete();
    _wake = null;
    if (!_running && !(_sealed && _pending.isEmpty)) {
      _running = true;
      unawaited(_run(_generation));
    }
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
      await _driver.stop();
    } on Object {
      // Best-effort.
    }
    if (!_done.isCompleted) _done.complete();
  }

  Future<void> _run(int generation) async {
    try {
      await _driver.configure();
      while (true) {
        if (generation != _generation) return;
        if (_pending.isEmpty) {
          if (_sealed) return;
          final w = Completer<void>();
          _wake = w;
          await w.future;
          continue;
        }
        final chunk = _pending.removeFirst();
        if (!_playedAny) {
          _playedAny = true;
          onFirstAudio?.call();
        }
        try {
          await _driver.speak(chunk);
        } on Object catch (e) {
          if (generation == _generation) {
            _firstError ??= e;
            onError?.call(e);
          }
        }
      }
    } on Object catch (e) {
      if (generation == _generation) {
        _firstError ??= e;
        onError?.call(e);
      }
    } finally {
      if (generation == _generation) {
        _running = false;
        if (!_done.isCompleted) _done.complete();
        onCompleted?.call();
      }
    }
  }
}

final deviceTtsDriverProvider = Provider<DeviceTtsDriver>((ref) {
  final driver = _FlutterTtsDriver(FlutterTts());
  ref.onDispose(driver.dispose);
  return driver;
});
