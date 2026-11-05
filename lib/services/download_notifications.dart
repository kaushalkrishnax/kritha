import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DownloadNotificationAction { pause, resume, cancel }

typedef DownloadNotificationActionHandler = void Function(
  String id,
  DownloadNotificationAction action,
);

/// Snapshot of one active download rendered as a system notification.
class DownloadNotification {
  const DownloadNotification({
    required this.id,
    required this.modelName,
    required this.fileName,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.paused = false,
  });

  final String id;
  final String modelName;
  final String fileName;
  final int receivedBytes;
  final int totalBytes;
  final bool paused;

  int get notificationId => id.hashCode & 0x7fffffff;

  double? get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  DownloadNotification copyWith({
    String? modelName,
    String? fileName,
    int? receivedBytes,
    int? totalBytes,
    bool? paused,
  }) {
    return DownloadNotification(
      id: id,
      modelName: modelName ?? this.modelName,
      fileName: fileName ?? this.fileName,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      paused: paused ?? this.paused,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'notificationId': notificationId,
    'modelName': modelName,
    'fileName': fileName,
    'receivedBytes': receivedBytes,
    'totalBytes': totalBytes,
    'progress': progress,
    'paused': paused,
  };
}

/// Transport used to render persistent download notifications.
abstract interface class DownloadNotificationPlatform {
  Future<void> initialize(DownloadNotificationActionHandler onAction);

  Future<void> show(DownloadNotification notification);

  Future<void> cancel(DownloadNotification notification);
}

class MethodChannelDownloadNotificationPlatform
    implements DownloadNotificationPlatform {
  MethodChannelDownloadNotificationPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kritha/downloads');

  final MethodChannel _channel;
  DownloadNotificationActionHandler? _onAction;

  @override
  Future<void> initialize(DownloadNotificationActionHandler onAction) async {
    _onAction = onAction;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      final arguments = call.arguments;
      if (arguments is! Map) return;
      final id = arguments['id'];
      final action = arguments['action'];
      if (id is! String || action is! String) return;
      DownloadNotificationAction? parsed;
      for (final value in DownloadNotificationAction.values) {
        if (value.name == action) {
          parsed = value;
          break;
        }
      }
      if (parsed == null) return;
      _onAction?.call(id, parsed);
    });
  }

  @override
  Future<void> show(DownloadNotification notification) {
    return _channel.invokeMethod<void>('show', notification.toMap());
  }

  @override
  Future<void> cancel(DownloadNotification notification) {
    return _channel.invokeMethod<void>('cancel', {
      'id': notification.id,
      'notificationId': notification.notificationId,
    });
  }
}

class NoopDownloadNotificationPlatform implements DownloadNotificationPlatform {
  const NoopDownloadNotificationPlatform();

  @override
  Future<void> initialize(DownloadNotificationActionHandler onAction) async {}

  @override
  Future<void> show(DownloadNotification notification) async {}

  @override
  Future<void> cancel(DownloadNotification notification) async {}
}

/// Owns notification state and routes notification actions to real downloads.
class DownloadNotificationCoordinator {
  DownloadNotificationCoordinator(this._platform);

  final DownloadNotificationPlatform _platform;
  final Map<String, _DownloadNotificationEntry> _entries = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _platform.initialize(_handleAction);
  }

  Future<void> register(
    DownloadNotification notification, {
    required VoidCallback onPause,
    required VoidCallback onResume,
    required VoidCallback onCancel,
  }) async {
    await initialize();
    _entries[notification.id] = _DownloadNotificationEntry(
      notification,
      onPause: onPause,
      onResume: onResume,
      onCancel: onCancel,
    );
    await _platform.show(notification);
  }

  Future<void> updateProgress(
    String id, {
    required int receivedBytes,
    required int totalBytes,
  }) async {
    final entry = _entries[id];
    if (entry == null) return;
    final previous = entry.notification;
    if (previous.receivedBytes == receivedBytes &&
        previous.totalBytes == totalBytes) {
      return;
    }
    entry.notification = previous.copyWith(
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
    );
    await _platform.show(entry.notification);
  }

  Future<void> markPaused(String id) async {
    final entry = _entries[id];
    if (entry == null || entry.notification.paused) return;
    entry.notification = entry.notification.copyWith(paused: true);
    await _platform.show(entry.notification);
  }

  Future<void> markResumed(String id) async {
    final entry = _entries[id];
    if (entry == null || !entry.notification.paused) return;
    entry.notification = entry.notification.copyWith(paused: false);
    await _platform.show(entry.notification);
  }

  Future<void> complete(String id) async {
    final entry = _entries.remove(id);
    if (entry == null) return;
    await _platform.cancel(entry.notification);
  }

  Future<void> _handleAction(
    String id,
    DownloadNotificationAction action,
  ) async {
    final entry = _entries[id];
    if (entry == null) return;
    switch (action) {
      case DownloadNotificationAction.pause:
        if (entry.notification.paused) return;
        entry.notification = entry.notification.copyWith(paused: true);
        await _platform.show(entry.notification);
        entry.onPause();
      case DownloadNotificationAction.resume:
        if (!entry.notification.paused) return;
        entry.notification = entry.notification.copyWith(paused: false);
        await _platform.show(entry.notification);
        entry.onResume();
      case DownloadNotificationAction.cancel:
        final removed = _entries.remove(id);
        if (removed == null) return;
        await _platform.cancel(removed.notification);
        removed.onCancel();
    }
  }
}

class _DownloadNotificationEntry {
  _DownloadNotificationEntry(
    this.notification, {
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  DownloadNotification notification;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
}

final downloadNotificationPlatformProvider =
    Provider<DownloadNotificationPlatform>((ref) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return MethodChannelDownloadNotificationPlatform();
      }
      return const NoopDownloadNotificationPlatform();
    });

final downloadNotificationCoordinatorProvider =
    Provider<DownloadNotificationCoordinator>((ref) {
      return DownloadNotificationCoordinator(
        ref.watch(downloadNotificationPlatformProvider),
      );
    });
