import 'package:flutter/services.dart';

/// Flutter bridge for native Android wake-word foreground service and overlay.
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

  static Future<void> pauseListening() async {
    try {
      await _method.invokeMethod<void>('pauseListening');
    } on MissingPluginException {
      // Non-Android platforms ignore wake-word mic handoff.
    }
  }

  static Future<void> resumeListening() async {
    try {
      await _method.invokeMethod<void>('resumeListening');
    } on MissingPluginException {
      // Non-Android platforms ignore wake-word mic handoff.
    }
  }

  static Future<bool> canDrawOverlays() async {
    try {
      return await _method.invokeMethod<bool>('canDrawOverlays') ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _method.invokeMethod<void>('requestOverlayPermission');
    } on MissingPluginException {
      // Overlay permission is Android-only.
    }
  }

  static Future<void> dismissOverlay() async {
    try {
      await _method.invokeMethod<void>('dismissOverlay');
    } on MissingPluginException {
      // Overlay dismissal is Android-only.
    }
  }

  static Future<void> openMainApp() async {
    try {
      await _method.invokeMethod<void>('openMainApp');
    } on MissingPluginException {
      // Main app launch is Android-only.
    }
  }

  static Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _method.invokeMethod<void>('setKeepScreenOn', {'enabled': enabled});
    } on MissingPluginException {
      // Screen/wake lock is Android-only.
    }
  }

  static Future<void> setMainChatActive(bool active) async {
    try {
      await _method.invokeMethod<void>('setMainChatActive', {'active': active});
    } on MissingPluginException {
      // Route-aware overlay handoff is Android-only.
    }
  }

  static Future<bool> isDefaultAssistant() async {
    try {
      return await _method.invokeMethod<bool>('isDefaultAssistant') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openAssistantSettings() async {
    try {
      return await _method.invokeMethod<bool>('openAssistantSettings') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
