import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

enum TurnSignal { none, speechStart, speechEnd }

/// Rule-based hysteresis turn detector over 16 kHz / 512-sample (32 ms) frames.
class TurnDetector {
  TurnDetector({
    this.speechThreshold = 0.50,
    this.silenceThreshold = 0.35,
    this.silenceFrameCount = 24,
    this.maxSpeechFrames = 625,
  });

  final double speechThreshold;
  final double silenceThreshold;
  final int silenceFrameCount;
  final int maxSpeechFrames;

  bool _inSpeech = false;
  int _silentFrames = 0;
  int _speechFrames = 0;

  bool get inSpeech => _inSpeech;
  int get speechFrames => _speechFrames;

  TurnSignal accept(double probability) {
    if (probability >= speechThreshold) {
      _silentFrames = 0;
      _speechFrames += 1;
      if (!_inSpeech) {
        _inSpeech = true;
        return TurnSignal.speechStart;
      }
      if (_speechFrames >= maxSpeechFrames) {
        reset();
        return TurnSignal.speechEnd;
      }
      return TurnSignal.none;
    }
    if (probability <= silenceThreshold) {
      if (!_inSpeech) return TurnSignal.none;
      _speechFrames += 1;
      _silentFrames += 1;
      if (_silentFrames >= silenceFrameCount ||
          _speechFrames >= maxSpeechFrames) {
        reset();
        return TurnSignal.speechEnd;
      }
      return TurnSignal.none;
    }
    if (_inSpeech) {
      _speechFrames += 1;
      if (_speechFrames >= maxSpeechFrames) {
        reset();
        return TurnSignal.speechEnd;
      }
    }
    return TurnSignal.none;
  }

  void reset() {
    _inSpeech = false;
    _silentFrames = 0;
    _speechFrames = 0;
  }
}

/// Silero VAD wrapper via sherpa_onnx with RMS energy fallback when offline.
class SileroVadSession {
  SileroVadSession._(this._vad);

  /// Instant RMS-energy VAD session that requires zero model loading.
  factory SileroVadSession.energyFallback() => SileroVadSession._(null);

  static const int sampleRate = 16000;
  static const int frameSamples = 512;
  static const String _assetPath = 'assets/models/silero_vad.onnx';

  static bool _bindingsInitialized = false;
  static String? _cachedModelPath;

  final sherpa.VoiceActivityDetector? _vad;

  bool get usesSilero => _vad != null;

  static Future<SileroVadSession> create() async {
    try {
      if (!_bindingsInitialized) {
        sherpa.initBindings();
        _bindingsInitialized = true;
      }
      final modelPath = await _ensureModelFile();
      if (modelPath != null) {
        final config = sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: modelPath,
            threshold: 0.5,
            minSilenceDuration: 0.35,
            minSpeechDuration: 0.10,
            windowSize: frameSamples,
            maxSpeechDuration: 30.0,
          ),
          sampleRate: sampleRate,
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        );
        final vad = sherpa.VoiceActivityDetector(
          config: config,
          bufferSizeInSeconds: 30,
        );
        return SileroVadSession._(vad);
      }
    } on Object {
      // Fall back to RMS energy detection if Silero ONNX cannot be loaded.
    }
    return SileroVadSession._(null);
  }

  static Future<String?> _ensureModelFile() async {
    final cached = _cachedModelPath;
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
      '${dir.path}/models/speech/silero-vad-v5/silero_vad.onnx',
    );
    if (target.existsSync() && target.lengthSync() > 100000) {
      _cachedModelPath = target.path;
      return target.path;
    }
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    _cachedModelPath = target.path;
    return target.path;
  }

  /// Processes one 512-sample PCM16 frame and returns (probability, rmsLevel 0..1).
  ({double probability, double level}) processFrame(Int16List pcm16) {
    var sumSq = 0.0;
    final floats = Float32List(pcm16.length);
    for (var i = 0; i < pcm16.length; i++) {
      final sample = pcm16[i] / 32768.0;
      floats[i] = sample;
      sumSq += sample * sample;
    }
    final rms = math.sqrt(sumSq / pcm16.length);
    // Non-linear boost so normal conversational speech reaches 0.65..1.0.
    final level = math.pow((rms * 14.0).clamp(0.0, 1.0), 0.65).toDouble();

    final vad = _vad;
    if (vad == null) {
      final prob = rms >= 0.025 ? 0.85 : (rms >= 0.014 ? 0.42 : 0.1);
      return (probability: prob, level: level);
    }

    vad.acceptWaveform(floats);
    final detected = vad.isDetected();
    while (!vad.isEmpty()) {
      vad.pop();
    }
    return (probability: detected ? 0.9 : 0.1, level: level);
  }

  void reset() {
    _vad?.reset();
  }

  void dispose() {
    _vad?.free();
  }
}

/// Wraps raw mono PCM16 samples into a standard RIFF WAV byte buffer.
Uint8List pcm16ToWav(List<int> pcmBytes, {int sampleRate = 16000}) {
  final dataLength = pcmBytes.length;
  final byteRate = sampleRate * 2;
  final header = ByteData(44)
    ..setUint8(0, 0x52)
    ..setUint8(1, 0x49)
    ..setUint8(2, 0x46)
    ..setUint8(3, 0x46)
    ..setUint32(4, 36 + dataLength, Endian.little)
    ..setUint8(8, 0x57)
    ..setUint8(9, 0x41)
    ..setUint8(10, 0x56)
    ..setUint8(11, 0x45)
    ..setUint8(12, 0x66)
    ..setUint8(13, 0x6D)
    ..setUint8(14, 0x74)
    ..setUint8(15, 0x20)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint8(36, 0x64)
    ..setUint8(37, 0x61)
    ..setUint8(38, 0x74)
    ..setUint8(39, 0x61)
    ..setUint32(40, dataLength, Endian.little);
  return Uint8List(44 + dataLength)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + dataLength, pcmBytes);
}
