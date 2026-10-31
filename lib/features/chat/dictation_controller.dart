import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum DictationPhase { idle, listening, transcribing }

extension DictationPhaseX on DictationPhase {
  bool get isIdle => this == DictationPhase.idle;
  bool get isActive => this != DictationPhase.idle;
  bool get isListening => this == DictationPhase.listening;
  bool get isTranscribing => this == DictationPhase.transcribing;
}

class DictationState {
  const DictationState({
    this.phase = DictationPhase.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
  });

  final DictationPhase phase;
  final Duration elapsed;

  /// Newest amplitude (0..1) at the end, capped at 42 entries.
  final List<double> levels;

  bool get isActive => phase.isActive;
  bool get isIdle => phase.isIdle;
  bool get isListening => phase.isListening;
  bool get isTranscribing => phase.isTranscribing;

  DictationState copyWith({
    DictationPhase? phase,
    Duration? elapsed,
    List<double>? levels,
  }) {
    return DictationState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      levels: levels ?? this.levels,
    );
  }
}

class DictationException implements Exception {
  const DictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Microphone capture and audio metering for dictation.
class DictationNotifier extends Notifier<DictationState> {
  static const int maxBars = 42;

  AudioRecorder? _recorder;
  Timer? _ticker;
  final Stopwatch _watch = Stopwatch();
  final math.Random _random = math.Random();
  String? _path;
  bool _ticking = false;

  @override
  DictationState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _watch.stop();
      final recorder = _recorder;
      _recorder = null;
      recorder?.dispose();
    });
    return const DictationState();
  }

  AudioRecorder get _engine => _recorder ??= AudioRecorder();

  Future<void> start() async {
    if (state.isActive) return;
    final recorder = _engine;
    try {
      final allowed = await recorder.hasPermission();
      if (!allowed) {
        throw const DictationException(
          'Microphone permission is required for dictation.',
        );
      }
      final directory = await getTemporaryDirectory();
      _path =
          '${directory.path}/kritha_dictation_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _path!,
      );
      _watch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 110),
        (_) => _tick(),
      );
      state = const DictationState(phase: DictationPhase.listening);
    } on DictationException {
      await _discardFile();
      rethrow;
    } on Object catch (error) {
      await _discardFile();
      throw DictationException('Could not start recording: $error');
    }
  }

  Future<void> _tick() async {
    if (!state.isListening || _ticking) return;
    _ticking = true;
    var level = 0.18 + _random.nextDouble() * 0.4;
    try {
      final amplitude = await _engine.getAmplitude();
      // dBFS ≈ -50 (silence) .. 0 (max) → 0..1.
      if (amplitude.current < 0) {
        level = ((amplitude.current + 50) / 50).clamp(0.12, 1.0);
      }
    } on Object {
      // Keep the synthesised fallback so the waveform never freezes on a
      // platform that cannot report amplitude.
    } finally {
      _ticking = false;
    }
    if (!state.isActive) return;

    final levels = [...state.levels, level];
    while (levels.length > maxBars) {
      levels.removeAt(0);
    }
    state = state.copyWith(elapsed: _watch.elapsed, levels: levels);
  }

  /// Stops the take and returns its transcript.
  ///
  /// TODO(stt): feed the stopped file to the offline sherpa-onnx recogniser and
  /// return its text. Until a model is bundled this throws, so callers surface
  /// the missing-model error and no audio file is attached to the message.
  Future<String> transcribe() async {
    if (!state.isActive) {
      throw const DictationException('There is no recording to transcribe.');
    }
    _ticker?.cancel();
    _watch.stop();
    state = state.copyWith(phase: DictationPhase.transcribing);

    String? path;
    try {
      path = await _engine.stop();
    } on Object catch (error) {
      await _discardFile();
      _reset();
      throw DictationException('Could not stop recording: $error');
    }

    path ??= _path;
    _path = null;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on Object {
        // Temp files are cleaned up by the OS anyway.
      }
    }
    _reset();
    throw const DictationException(
      'Speech recognition needs a local STT model. None is bundled in this '
      'build yet.',
    );
  }

  Future<void> discard() async {
    if (!state.isActive) return;
    _ticker?.cancel();
    _watch.stop();
    try {
      await _engine.cancel();
    } on Object {
      // Cancelling is best-effort; the file is removed below.
    }
    await _discardFile();
    _reset();
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _watch
      ..stop()
      ..reset();
    state = const DictationState();
  }

  Future<void> _discardFile() async {
    final path = _path;
    _path = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object {
      // Temp files are cleaned up by the OS anyway.
    }
  }
}

final dictationProvider = NotifierProvider<DictationNotifier, DictationState>(
  DictationNotifier.new,
);
