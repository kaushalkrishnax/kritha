import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/services/device_tts_service.dart';

class _FakeDeviceTtsDriver implements DeviceTtsDriver {
  final List<String> spoken = [];
  bool stopped = false;
  Completer<void>? currentSpeak;

  @override
  Future<void> configure() async {}

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    final gate = Completer<void>();
    currentSpeak = gate;
    await gate.future;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    final gate = currentSpeak;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('speaks chunks sequentially without dropping active speech', () async {
    final driver = _FakeDeviceTtsDriver();
    var firstAudio = 0;
    var completed = 0;
    final session = DeviceTtsSession(
      driver: driver,
      onFirstAudio: () => firstAudio++,
      onCompleted: () => completed++,
    );

    session.addText('One.');
    session.addText('Two.');
    final done = session.finish();

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(driver.spoken, ['One.']);
    expect(firstAudio, 1);
    expect(completed, 0);

    driver.currentSpeak!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(driver.spoken, ['One.', 'Two.']);

    driver.currentSpeak!.complete();
    await done;
    expect(completed, 1);
  });

  test('cancel stops current speech and skips remaining chunks', () async {
    final driver = _FakeDeviceTtsDriver();
    final session = DeviceTtsSession(driver: driver);

    session.addText('One.');
    session.addText('Two.');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await session.cancel();
    expect(driver.stopped, isTrue);
    expect(driver.spoken, ['One.']);
  });
}
