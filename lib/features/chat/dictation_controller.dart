import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../services/device_asr_service.dart';
import '../../services/silero_vad_service.dart';

import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';

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
  StreamSubscription<Uint8List>? _vadSub;
  SileroVadSession? _vad;
  int _autoEpoch = 0;
  bool _usingDeviceAsr = false;
  String _deviceTranscript = '';
  double _deviceSoundLevel = 0.18;

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

      final active = await ref.read(activeModelsProvider.future);
      final sttModelId = _sttModelId(active);
      if (sttModelId == null || sttModelId.trim().isEmpty) {
        _usingDeviceAsr = true;
        _deviceTranscript = '';
        _deviceSoundLevel = 0.18;
        await ref
            .read(deviceAsrServiceProvider)
            .startListening(
              onResult: (words, _) {
                if (words.isNotEmpty) _deviceTranscript = words;
              },
              onSoundLevel: (level) => _deviceSoundLevel = level,
            );
        _watch
          ..reset()
          ..start();
        _ticker?.cancel();
        _ticker = Timer.periodic(
          const Duration(milliseconds: 110),
          (_) => _tickDeviceAsr(),
        );
        state = const DictationState(phase: DictationPhase.listening);
        return;
      }

      _usingDeviceAsr = false;
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
      _usingDeviceAsr = false;
      rethrow;
    } on Object catch (error) {
      await _discardFile();
      _usingDeviceAsr = false;
      throw DictationException('Could not start recording: $error');
    }
  }

  void _tickDeviceAsr() {
    if (!state.isListening) return;
    final levels = [...state.levels, _deviceSoundLevel];
    while (levels.length > maxBars) {
      levels.removeAt(0);
    }
    state = state.copyWith(elapsed: _watch.elapsed, levels: levels);
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
      // Fallback amplitude prevents frozen waveform on unsupported platforms.
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

  /// Stops recording and transcribes audio via the active ASR or audio model,
  /// falling back to the device speech recognizer when no model is configured.
  Future<String> transcribe() async {
    if (!state.isActive) {
      throw const DictationException('There is no recording to transcribe.');
    }
    _ticker?.cancel();
    _watch.stop();
    state = state.copyWith(phase: DictationPhase.transcribing);

    if (_usingDeviceAsr) {
      try {
        final result = await ref
            .read(deviceAsrServiceProvider)
            .stopListening();
        return result.isNotEmpty ? result : _deviceTranscript.trim();
      } on Object catch (error) {
        throw DictationException('Transcription failed: $error');
      } finally {
        _reset();
      }
    }

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
    try {
      if (path == null) {
        throw const DictationException('No audio file was recorded.');
      }
      final file = File(path);
      if (!file.existsSync()) {
        throw const DictationException('Recorded audio file is missing.');
      }
      final bytes = await file.readAsBytes();
      final active = await ref.read(activeModelsProvider.future);
      final sttModelId = _sttModelId(active);
      if (sttModelId == null || sttModelId.trim().isEmpty) {
        throw const DictationException(
          'No Speech recognition or Audio model is assigned in Active Models.',
        );
      }
      final transcript = await ref
          .read(intelligenceEngineProvider)
          .transcribeAudio(
            bytes: bytes,
            mimeType: 'audio/mp4',
            modelId: sttModelId,
          );
      return transcript;
    } on DictationException {
      rethrow;
    } on Object catch (error) {
      throw DictationException('Transcription failed: $error');
    } finally {
      if (path != null) {
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } on Object {
          // Temp files cleaned up by OS.
        }
      }
      _reset();
    }
  }

  /// Starts hands-free dictation using Silero VAD to stop on end of speech,
  /// transcribe, and pass the result to [onTranscript].
  Future<void> startAutoStop({
    required Future<void> Function(String transcript) onTranscript,
    void Function(String message)? onError,
  }) async {
    if (state.isActive) return;
    final epoch = ++_autoEpoch;
    final recorder = _engine;
    final allowed = await recorder.hasPermission();
    if (!allowed) {
      onError?.call('Microphone permission is required for dictation.');
      return;
    }

    final active = await ref.read(activeModelsProvider.future);
    final sttModelId = _sttModelId(active);
    if (sttModelId == null || sttModelId.trim().isEmpty) {
      await _startDeviceAutoStop(
        epoch: epoch,
        onTranscript: onTranscript,
        onError: onError,
      );
      return;
    }

    _usingDeviceAsr = false;
    _vad = SileroVadSession.energyFallback();
    unawaited(
      SileroVadSession.create().then((silero) {
        if (epoch != _autoEpoch || !ref.mounted) {
          silero.dispose();
          return;
        }
        if (silero.usesSilero) {
          final prev = _vad;
          _vad = silero;
          prev?.dispose();
        } else {
          silero.dispose();
        }
      }),
    );
    final turnDetector = TurnDetector(silenceFrameCount: 28);
    final pcmCarry = <int>[];
    final capturedPcm = <int>[];
    var heardSpeech = false;

    _watch
      ..reset()
      ..start();
    state = const DictationState(phase: DictationPhase.listening);

    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: SileroVadSession.sampleRate,
          numChannels: 1,
        ),
      );
      if (epoch != _autoEpoch || !ref.mounted) return;

      const frameBytesCount = SileroVadSession.frameSamples * 2;
      _vadSub = stream.listen((chunk) {
        if (epoch != _autoEpoch || !state.isListening) return;
        pcmCarry.addAll(chunk);
        while (pcmCarry.length >= frameBytesCount) {
          final frameBytes = pcmCarry.sublist(0, frameBytesCount);
          pcmCarry.removeRange(0, frameBytesCount);
          final pcm16 = Int16List.view(Uint8List.fromList(frameBytes).buffer);
          final res = _vad!.processFrame(pcm16);

          final levels = [...state.levels, res.level.clamp(0.12, 1.0)];
          while (levels.length > maxBars) {
            levels.removeAt(0);
          }
          state = state.copyWith(elapsed: _watch.elapsed, levels: levels);

          final signal = turnDetector.accept(res.probability);
          if (signal == TurnSignal.speechStart) {
            heardSpeech = true;
            capturedPcm.addAll(frameBytes);
          } else if (heardSpeech) {
            capturedPcm.addAll(frameBytes);
          }

          final timedOut = !heardSpeech && _watch.elapsed.inSeconds >= 8;
          if (signal == TurnSignal.speechEnd || timedOut) {
            unawaited(
              _finishAutoStop(
                epoch: epoch,
                pcmBytes: List<int>.from(capturedPcm),
                onTranscript: onTranscript,
                onError: onError,
              ),
            );
            break;
          }
        }
      });
    } on Object catch (error) {
      await _cleanupAutoVad();
      _reset();
      onError?.call('Could not start dictation: $error');
    }
  }

  Future<void> _finishAutoStop({
    required int epoch,
    required List<int> pcmBytes,
    required Future<void> Function(String transcript) onTranscript,
    void Function(String message)? onError,
  }) async {
    if (epoch != _autoEpoch) return;
    _autoEpoch++;
    await _cleanupAutoVad();
    try {
      await _engine.stop();
    } on Object {
      // Recorder may already be stopped.
    }
    if (pcmBytes.length < 3200) {
      _reset();
      return;
    }
    state = state.copyWith(phase: DictationPhase.transcribing);
    try {
      final active = await ref.read(activeModelsProvider.future);
      final sttModelId =
          active.executableSelection[AiTaskId.automaticSpeechRecognition] ??
          active.singleModels[ModelCapability.speechRecognition] ??
          active.executableSelection[AiTaskId.audioUnderstanding] ??
          active.singleModels[ModelCapability.audio] ??
          active.multiModel?.modelId;
      if (sttModelId == null || sttModelId.trim().isEmpty) {
        onError?.call(
          'No Speech recognition or Audio model is assigned in Active Models.',
        );
        return;
      }
      final wav = pcm16ToWav(pcmBytes, sampleRate: SileroVadSession.sampleRate);
      final transcript = (await ref
          .read(intelligenceEngineProvider)
          .transcribeAudio(
            bytes: wav,
            mimeType: 'audio/wav',
            modelId: sttModelId,
          )).trim();
      if (transcript.isNotEmpty) {
        await onTranscript(transcript);
      }
    } on Object catch (error) {
      onError?.call('Transcription failed: $error');
    } finally {
      _reset();
    }
  }

  Future<void> _startDeviceAutoStop({
    required int epoch,
    required Future<void> Function(String transcript) onTranscript,
    void Function(String message)? onError,
  }) async {
    _usingDeviceAsr = true;
    _deviceTranscript = '';
    _deviceSoundLevel = 0.18;
    _watch
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (epoch != _autoEpoch || !state.isListening) return;
      _tickDeviceAsr();
      if (_deviceTranscript.isEmpty && _watch.elapsed.inSeconds >= 8) {
        unawaited(
          _finishDeviceAutoStop(
            epoch: epoch,
            onTranscript: onTranscript,
            onError: onError,
          ),
        );
      }
    });
    state = const DictationState(phase: DictationPhase.listening);

    try {
      await ref
          .read(deviceAsrServiceProvider)
          .startListening(
            pauseFor: const Duration(seconds: 2),
            onSoundLevel: (level) => _deviceSoundLevel = level,
            onResult: (words, isFinal) {
              if (epoch != _autoEpoch || !state.isListening) return;
              if (words.isNotEmpty) _deviceTranscript = words;
              if (isFinal) {
                unawaited(
                  _finishDeviceAutoStop(
                    epoch: epoch,
                    onTranscript: onTranscript,
                    onError: onError,
                  ),
                );
              }
            },
            onStatus: (status) {
              if (epoch != _autoEpoch || !state.isListening) return;
              if ((status == 'done' || status == 'notListening') &&
                  _deviceTranscript.isNotEmpty) {
                unawaited(
                  _finishDeviceAutoStop(
                    epoch: epoch,
                    onTranscript: onTranscript,
                    onError: onError,
                  ),
                );
              }
            },
            onError: (message) {
              if (epoch != _autoEpoch) return;
              _autoEpoch++;
              _reset();
              onError?.call('Transcription failed: $message');
            },
          );
    } on Object catch (error) {
      _reset();
      onError?.call('Could not start dictation: $error');
    }
  }

  Future<void> _finishDeviceAutoStop({
    required int epoch,
    required Future<void> Function(String transcript) onTranscript,
    void Function(String message)? onError,
  }) async {
    if (epoch != _autoEpoch) return;
    _autoEpoch++;
    _ticker?.cancel();
    _watch.stop();
    state = state.copyWith(phase: DictationPhase.transcribing);
    try {
      final stopped = await ref.read(deviceAsrServiceProvider).stopListening();
      final transcript = (stopped.isNotEmpty ? stopped : _deviceTranscript)
          .trim();
      if (transcript.isNotEmpty) {
        await onTranscript(transcript);
      }
    } on Object catch (error) {
      onError?.call('Transcription failed: $error');
    } finally {
      _reset();
    }
  }

  Future<void> _cleanupAutoVad() async {
    await _vadSub?.cancel();
    _vadSub = null;
    _vad?.dispose();
    _vad = null;
  }

  Future<void> discard() async {
    if (!state.isActive) return;
    _autoEpoch++;
    await _cleanupAutoVad();
    _ticker?.cancel();
    _watch.stop();
    if (_usingDeviceAsr) {
      try {
        await ref.read(deviceAsrServiceProvider).cancelListening();
      } on Object {
        // Cancelling device ASR is best-effort.
      }
    } else {
      try {
        await _engine.cancel();
      } on Object {
        // Cancelling is best-effort; file is cleaned up below.
      }
    }
    await _discardFile();
    _reset();
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _usingDeviceAsr = false;
    _deviceTranscript = '';
    _watch
      ..stop()
      ..reset();
    state = const DictationState();
  }

  static String? _sttModelId(ActiveModelsState active) =>
      active.executableSelection[AiTaskId.automaticSpeechRecognition] ??
      active.singleModels[ModelCapability.speechRecognition] ??
      active.executableSelection[AiTaskId.audioUnderstanding] ??
      active.singleModels[ModelCapability.audio] ??
      active.multiModel?.modelId;

  Future<void> _discardFile() async {
    final path = _path;
    _path = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object {
      // Temp files cleaned up by OS.
    }
  }
}

final dictationProvider = NotifierProvider<DictationNotifier, DictationState>(
  DictationNotifier.new,
);
