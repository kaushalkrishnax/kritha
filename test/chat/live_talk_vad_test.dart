import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/services/silero_vad_service.dart';
import 'package:kritha/services/wake_word_controller.dart';

void main() {
  test('TurnDetector fires speechStart and speechEnd with hysteresis', () {
    final detector = TurnDetector(
      speechThreshold: 0.5,
      silenceThreshold: 0.35,
      silenceFrameCount: 3,
      maxSpeechFrames: 50,
    );

    expect(detector.accept(0.1), TurnSignal.none);
    expect(detector.accept(0.8), TurnSignal.speechStart);
    expect(detector.inSpeech, isTrue);

    // Mid-threshold keeps speech active without cutting off.
    expect(detector.accept(0.42), TurnSignal.none);
    expect(detector.inSpeech, isTrue);

    // Silence frames trigger speechEnd after silenceFrameCount.
    expect(detector.accept(0.1), TurnSignal.none);
    expect(detector.accept(0.2), TurnSignal.none);
    expect(detector.accept(0.1), TurnSignal.speechEnd);
    expect(detector.inSpeech, isFalse);
  });

  test('pcm16ToWav writes valid 44-byte RIFF/WAVE header', () {
    final wav = pcm16ToWav(Uint8List.fromList([1, 2, 3, 4]), sampleRate: 16000);
    expect(wav.length, 48);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  });

  test('WakeWordMode round-trips by name', () {
    expect(WakeWordMode.fromName('liveTalk'), WakeWordMode.liveTalk);
    expect(WakeWordMode.fromName('dictate'), WakeWordMode.dictate);
    expect(WakeWordMode.fromName(null), WakeWordMode.dictate);
  });
}
