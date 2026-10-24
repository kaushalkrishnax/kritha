import 'package:flutter/services.dart';

/// Narrow Flutter bridge for the native Android wake-word foreground service.
/// The model/inference library remains packaged in the base Android APK.
abstract final class WakeWordBridge {
  static const _method = MethodChannel('com.kritha/wake_word');
  static const _events = EventChannel('com.kritha/wake_word/events');

  static Stream<Map<String, Object?>> get events =>
      _events.receiveBroadcastStream().map(
        (event) => event is Map
            ? Map<String, Object?>.from(event)
            : const <String, Object?>{},
      );

  static Future<bool> isAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isRunning() async {
    try {
      return await _method.invokeMethod<bool>('isRunning') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> start() => _method.invokeMethod<void>('start');

  static Future<void> stop() => _method.invokeMethod<void>('stop');
}
