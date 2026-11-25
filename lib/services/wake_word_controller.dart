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

/// Owns native wake-word event handling and the shared activation path used by
/// both the focused chat screen and the background overlay.
class WakeWordCoordinator {
  WakeWordCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<Map<String, Object?>>? _subscription;
  bool _activating = false;

  void attach() {
    unawaited(_ensureStartedOnLaunch());
    _subscription = WakeWordBridge.events.listen((event) {
      if (event['type'] == 'detected') {
        unawaited(activateConfiguredMode());
      }
    });

    _ref.listen(dictationProvider, (prev, next) {
      if (prev?.isActive == true &&
          next.isIdle &&
          !_ref.read(liveTalkProvider).active) {
        unawaited(WakeWordBridge.resumeListening());
      }
    });
    _ref.listen(liveTalkProvider, (prev, next) {
      if (prev?.active == true &&
          !next.active &&
          _ref.read(dictationProvider).isIdle) {
        unawaited(WakeWordBridge.resumeListening());
      }
    });

    final router = _ref.read(routerProvider);
    void syncMainChatActive() {
      final path = router.routerDelegate.currentConfiguration.uri.path;
      unawaited(WakeWordBridge.setMainChatActive(path == '/chat'));
    }

    syncMainChatActive();
    router.routerDelegate.addListener(syncMainChatActive);

    _ref.onDispose(() {
      router.routerDelegate.removeListener(syncMainChatActive);
      _subscription?.cancel();
    });
  }

  /// Starts the configured wake-word action. Called for every detection,
  /// including the overlay's own mount so it never waits for a manual tap.
  Future<void> activateConfiguredMode() async {
    if (_activating) return;
    _activating = true;
    try {
      if (_ref.read(dictationProvider).isActive ||
          _ref.read(liveTalkProvider).active) {
        return;
      }
      await WakeWordBridge.pauseListening();
      final mode = await _ref
          .read(wakeWordModeProvider.notifier)
          .readSavedMode();
      // Ensure providers and the widget tree are settled when launched from
      // the external overlay activity.
      await WidgetsBinding.instance.endOfFrame;
      if (mode == WakeWordMode.liveTalk) {
        await _ref.read(liveTalkProvider.notifier).start();
      } else {
        await _ref.read(dictationProvider.notifier).startAutoStop(
          onTranscript: (transcript) async {
            await _ref.read(chatControllerProvider.notifier).send(transcript);
          },
        );
      }
    } finally {
      _activating = false;
    }
  }

  Future<void> _ensureStartedOnLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wanted = prefs.getBool('kritha.wake_word.enabled') ?? false;
      if (!wanted) return;
      if (!await WakeWordBridge.isAvailable() ||
          await WakeWordBridge.isRunning()) {
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
}

/// Coordinates native wake-word detections and auto-starts the service on
/// launch. The same coordinator is used by the overlay activity.
final wakeWordCoordinatorProvider = Provider<WakeWordCoordinator>((ref) {
  final coordinator = WakeWordCoordinator(ref)..attach();
  return coordinator;
});
