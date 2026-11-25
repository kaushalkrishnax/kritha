import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/router.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/dictation_controller.dart';
import '../features/chat/live_talk_controller.dart';
import 'wake_word_bridge.dart';

enum WakeWordMode {
  dictate('Dictate & send', 'Transcribes one question using Silero VAD and sends it'),
  liveTalk('Live Talk', 'Starts continuous hands-free voice conversation');

  const WakeWordMode(this.label, this.description);

  final String label;
  final String description;

  static WakeWordMode fromName(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return WakeWordMode.dictate;
  }
}

class WakeWordSettingsNotifier extends Notifier<WakeWordMode> {
  static const preferenceKey = 'kritha.wake_word.mode';
  Future<WakeWordMode>? _restoreFuture;

  @override
  WakeWordMode build() {
    _restoreFuture = _restore();
    return WakeWordMode.dictate;
  }

  Future<WakeWordMode> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = WakeWordMode.fromName(prefs.getString(preferenceKey));
    if (ref.mounted) state = saved;
    return saved;
  }

  Future<WakeWordMode> readSavedMode() async {
    final pending = _restoreFuture;
    if (pending != null) return pending;
    return _restore();
  }

  Future<void> setMode(WakeWordMode mode) async {
    state = mode;
    _restoreFuture = Future.value(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, mode.name);
  }
}

final wakeWordModeProvider =
    NotifierProvider<WakeWordSettingsNotifier, WakeWordMode>(
      WakeWordSettingsNotifier.new,
    );

/// Coordinates native wake-word detections and auto-starts the service on launch.
final wakeWordCoordinatorProvider = Provider<void>((ref) {
  StreamSubscription<Map<String, Object?>>? sub;
  var handling = false;

  Future<void> ensureStartedOnLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wanted = prefs.getBool('kritha.wake_word.enabled') ?? false;
      if (!wanted) return;
      if (!await WakeWordBridge.isAvailable() || await WakeWordBridge.isRunning()) {
        return;
      }
      final mic = await Permission.microphone.status;
      final notif = await Permission.notification.status;
      if (mic.isGranted && notif.isGranted) {
        await WakeWordBridge.start();
      }
    } on Object {
      // Non-Android platforms or missing permissions skip background start.
    }
  }

  unawaited(ensureStartedOnLaunch());

  Future<void> handleDetection() async {
    if (handling) return;
    handling = true;
    try {
      await WakeWordBridge.pauseListening();
      final mode = await ref.read(wakeWordModeProvider.notifier).readSavedMode();
      // Ensure widget tree / providers are settled when launched in KrithaOverlay.
      await WidgetsBinding.instance.endOfFrame;
      if (mode == WakeWordMode.liveTalk) {
        await ref.read(liveTalkProvider.notifier).start();
      } else {
        await ref.read(dictationProvider.notifier).startAutoStop(
          onTranscript: (transcript) async {
            await ref.read(chatControllerProvider.notifier).send(transcript);
          },
        );
      }
    } finally {
      handling = false;
    }
  }

  sub = WakeWordBridge.events.listen((event) {
    if (event['type'] == 'detected') {
      unawaited(handleDetection());
    }
  });

  // Resume wake-word mic listening once Dictation and Live Talk both go idle.
  ref.listen(dictationProvider, (prev, next) {
    if (prev?.isActive == true &&
        next.isIdle &&
        !ref.read(liveTalkProvider).active) {
      unawaited(WakeWordBridge.resumeListening());
    }
  });
  ref.listen(liveTalkProvider, (prev, next) {
    if (prev?.active == true &&
        !next.active &&
        ref.read(dictationProvider).isIdle) {
      unawaited(WakeWordBridge.resumeListening());
    }
  });

  final router = ref.read(routerProvider);
  void syncMainChatActive() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    unawaited(WakeWordBridge.setMainChatActive(path == '/chat'));
  }

  syncMainChatActive();
  router.routerDelegate.addListener(syncMainChatActive);

  ref.onDispose(() {
    router.routerDelegate.removeListener(syncMainChatActive);
    sub?.cancel();
  });
});
