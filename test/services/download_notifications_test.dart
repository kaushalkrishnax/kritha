import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/setup/model_artifact_storage.dart';
import 'package:kritha/features/models/setup/notifying_artifact_downloader.dart';
import 'package:kritha/services/download_notifications.dart';

void main() {
  group('DownloadNotificationCoordinator', () {
    late _FakeNotificationPlatform platform;
    late DownloadNotificationCoordinator coordinator;
    late int paused;
    late int resumed;
    late int cancelled;

    setUp(() {
      platform = _FakeNotificationPlatform();
      coordinator = DownloadNotificationCoordinator(platform);
      paused = 0;
      resumed = 0;
      cancelled = 0;
    });

    Future<void> register(String id) {
      return coordinator.register(
        DownloadNotification(
          id: id,
          modelName: 'Model $id',
          fileName: '$id.bin',
        ),
        onPause: () => paused++,
        onResume: () => resumed++,
        onCancel: () => cancelled++,
      );
    }

    test('shows initial state and synchronizes progress', () async {
      await register('a');

      expect(platform.shown, hasLength(1));
      expect(platform.shown.single.modelName, 'Model a');
      expect(platform.shown.single.fileName, 'a.bin');
      expect(platform.shown.single.progress, isNull);

      await coordinator.updateProgress('a', receivedBytes: 50, totalBytes: 200);

      expect(platform.shown.last.progress, 0.25);
      expect(platform.shown.last.receivedBytes, 50);
      expect(platform.shown.last.totalBytes, 200);
    });

    test('pause and resume actions control the download', () async {
      await register('a');

      platform.dispatch('a', DownloadNotificationAction.pause);
      await _flush();

      expect(paused, 1);
      expect(platform.shown.last.paused, isTrue);

      platform.dispatch('a', DownloadNotificationAction.resume);
      await _flush();

      expect(resumed, 1);
      expect(platform.shown.last.paused, isFalse);
    });

    test(
      'cancel action cancels the download and clears its notification',
      () async {
        await register('a');

        platform.dispatch('a', DownloadNotificationAction.cancel);
        await _flush();

        expect(cancelled, 1);
        expect(platform.cancelled, contains('a'));

        await coordinator.updateProgress(
          'a',
          receivedBytes: 10,
          totalBytes: 10,
        );
        expect(platform.shown, hasLength(1));
      },
    );

    test('tracks multiple simultaneous downloads independently', () async {
      await register('a');
      await register('b');

      await coordinator.updateProgress('a', receivedBytes: 1, totalBytes: 4);
      await coordinator.updateProgress('b', receivedBytes: 3, totalBytes: 4);

      final latest = {
        for (final item in platform.shown) item.id: item.progress,
      };
      expect(latest['a'], 0.25);
      expect(latest['b'], 0.75);

      await coordinator.complete('a');
      expect(platform.cancelled, ['a']);

      await coordinator.updateProgress('b', receivedBytes: 4, totalBytes: 4);
      expect(platform.shown.last.id, 'b');
      expect(platform.shown.last.progress, 1.0);
    });

    test('completing a download removes its notification', () async {
      await register('a');

      await coordinator.complete('a');

      expect(platform.cancelled, ['a']);
      await coordinator.updateProgress('a', receivedBytes: 1, totalBytes: 2);
      expect(platform.shown, hasLength(1));
    });
  });

  group('NotifyingArtifactDownloader', () {
    late _FakeNotificationPlatform platform;
    late DownloadNotificationCoordinator coordinator;

    setUp(() {
      platform = _FakeNotificationPlatform();
      coordinator = DownloadNotificationCoordinator(platform);
    });

    test(
      'forwards progress, pause, resume and cancel to the transfer',
      () async {
        final inner = _FakeDownload();
        final downloader = NotifyingArtifactDownloader(
          _FakeDownloader(inner),
          coordinator,
        );

        final download = downloader.start(
          repositoryId: 'acme/model',
          revision: 'main',
          path: 'weights/model.safetensors',
          destinationPath: '/tmp/model.safetensors',
          onProgress: (received, total) {},
        );
        await _flush();

        expect(platform.shown.single.modelName, 'acme/model');
        expect(platform.shown.single.fileName, 'weights/model.safetensors');

        inner.reportProgress(50, 100);
        await _flush();
        expect(platform.shown.last.progress, 0.5);

        platform.dispatch(
          'acme/model::/tmp/model.safetensors',
          DownloadNotificationAction.pause,
        );
        await _flush();
        expect(inner.pauseCalls, 1);
        expect(platform.shown.last.paused, isTrue);

        platform.dispatch(
          'acme/model::/tmp/model.safetensors',
          DownloadNotificationAction.resume,
        );
        await _flush();
        expect(inner.resumeCalls, 1);
        expect(platform.shown.last.paused, isFalse);

        platform.dispatch(
          'acme/model::/tmp/model.safetensors',
          DownloadNotificationAction.cancel,
        );
        await _flush();
        expect(inner.cancelCalls, 1);
        expect(
          platform.cancelled,
          contains('acme/model::/tmp/model.safetensors'),
        );
        expect(download.isPaused, inner.isPaused);
      },
    );

    test(
      'notification actions delegate to the owning controller when bound',
      () async {
        final inner = _FakeDownload();
        final downloader = NotifyingArtifactDownloader(
          _FakeDownloader(inner),
          coordinator,
        );

        final download = downloader.start(
          repositoryId: 'acme/bound',
          revision: 'main',
          path: 'bound.bin',
          destinationPath: '/tmp/bound.bin',
          onProgress: (_, _) {},
        ) as NotifyingArtifactDownload;
        var pauses = 0;
        var resumes = 0;
        download.pauseHandler = () => pauses++;
        download.resumeHandler = () => resumes++;
        await _flush();

        platform.dispatch(
          'acme/bound::/tmp/bound.bin',
          DownloadNotificationAction.pause,
        );
        await _flush();
        expect(pauses, 1);
        expect(inner.pauseCalls, 0);

        platform.dispatch(
          'acme/bound::/tmp/bound.bin',
          DownloadNotificationAction.resume,
        );
        await _flush();
        expect(resumes, 1);
        expect(inner.resumeCalls, 0);
      },
    );

    test('keeps separate notifications for parallel downloads', () async {
      final first = _FakeDownload();
      final second = _FakeDownload();
      final downloader = NotifyingArtifactDownloader(
        _FakeDownloader(first, second),
        coordinator,
      );

      downloader.start(
        repositoryId: 'acme/first',
        revision: 'main',
        path: 'first.bin',
        destinationPath: '/tmp/first.bin',
        onProgress: (_, _) {},
      );
      downloader.start(
        repositoryId: 'acme/second',
        revision: 'main',
        path: 'second.bin',
        destinationPath: '/tmp/second.bin',
        onProgress: (_, _) {},
      );
      await _flush();

      expect(platform.shown.map((item) => item.modelName), [
        'acme/first',
        'acme/second',
      ]);
      expect(
        platform.shown.map((item) => item.notificationId).toSet(),
        hasLength(2),
      );
    });
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeNotificationPlatform implements DownloadNotificationPlatform {
  DownloadNotificationActionHandler? _handler;
  final List<DownloadNotification> shown = [];
  final List<String> cancelled = [];

  @override
  Future<void> initialize(DownloadNotificationActionHandler onAction) async {
    _handler = onAction;
  }

  void dispatch(String id, DownloadNotificationAction action) {
    _handler?.call(id, action);
  }

  @override
  Future<void> show(DownloadNotification notification) async {
    shown.add(notification);
  }

  @override
  Future<void> cancel(DownloadNotification notification) async {
    cancelled.add(notification.id);
  }
}

class _FakeDownloader implements ModelArtifactDownloader {
  _FakeDownloader(this._first, [this._second]);

  final _FakeDownload _first;
  final _FakeDownload? _second;
  int _calls = 0;

  @override
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    final download = _calls == 0 ? _first : _second ?? _first;
    _calls++;
    download.onProgress = onProgress;
    return download;
  }
}

class _FakeDownload implements ModelArtifactDownload {
  final Completer<void> _done = Completer<void>();
  void Function(int received, int total)? onProgress;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int cancelCalls = 0;
  bool _paused = false;

  void reportProgress(int received, int total) =>
      onProgress?.call(received, total);

  @override
  Future<void> get done => _done.future;

  @override
  bool get isPaused => _paused;

  @override
  void pause() {
    pauseCalls++;
    _paused = true;
  }

  @override
  void resume() {
    resumeCalls++;
    _paused = false;
  }

  @override
  void cancel() {
    cancelCalls++;
    if (!_done.isCompleted) _done.complete();
  }
}
