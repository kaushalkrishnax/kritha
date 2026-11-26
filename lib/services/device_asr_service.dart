import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DeviceAsrException implements Exception {
  const DeviceAsrException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pure-Dart wrapper around the platform speech recognizer.
///
/// Serialises access: a second [startListening] call cancels any active session
/// before starting the new one, so callers never need to call [cancelListening]
/// themselves between turns.
class DeviceAsrService {
  DeviceAsrService([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String _latestTranscript = '';

  // Per-session callbacks dispatched from the global initialize callbacks.
  void Function(String, bool)? _onResult;
  void Function(String)? _onError;
  void Function(String)? _onStatus;

  Future<bool> ensureInitialized() async {
    if (_initialized && _speech.isAvailable) return true;
    _initialized = await _speech.initialize(
      onError: (e) => _onError?.call(e.errorMsg),
      onStatus: (s) => _onStatus?.call(s),
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    void Function(String message)? onError,
    void Function(String status)? onStatus,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ready = await ensureInitialized();
    if (!ready) {
      throw const DeviceAsrException(
        'Device speech recognition is unavailable on this device.',
      );
    }

    // Cancel any in-progress session before starting a fresh one.
    if (_speech.isListening) {
      _clearCallbacks();
      await _speech.cancel();
    }

    _latestTranscript = '';
    _onResult = onResult;
    _onError = onError;
    _onStatus = onStatus;

    await _speech.listen(
      onResult: (r) {
        final words = r.recognizedWords.trim();
        if (words.isNotEmpty) _latestTranscript = words;
        _onResult?.call(words, r.finalResult);
      },
      onSoundLevelChange: onSoundLevel == null
          ? null
          : (l) => onSoundLevel(_normalizeLevel(l)),
      listenOptions: SpeechListenOptions(
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<String> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      // Brief wait for the platform to deliver the final result.
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    _clearCallbacks();
    return _latestTranscript.trim();
  }

  Future<void> cancelListening() async {
    _clearCallbacks();
    _latestTranscript = '';
    if (_speech.isListening) await _speech.cancel();
  }

  void _clearCallbacks() {
    _onResult = null;
    _onError = null;
    _onStatus = null;
  }

  // Android reports RMS dB in roughly [-2, 10]; iOS in [-50, 0].
  static double _normalizeLevel(double raw) =>
      raw < 0 ? ((raw + 50) / 50).clamp(0.12, 1.0) : ((raw + 2) / 12).clamp(0.12, 1.0);
}

final deviceAsrServiceProvider = Provider<DeviceAsrService>(
  (ref) => DeviceAsrService(),
);
