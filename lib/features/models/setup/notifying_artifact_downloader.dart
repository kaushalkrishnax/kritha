import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/download_notifications.dart';
import '../catalogue/catalogue_providers.dart';
import 'model_artifact_storage.dart';

/// Wraps a downloader so every transfer owns a synchronized system notification.
class NotifyingArtifactDownloader implements ModelArtifactDownloader {
  const NotifyingArtifactDownloader(this._delegate, this._coordinator);

  final ModelArtifactDownloader _delegate;
  final DownloadNotificationCoordinator _coordinator;

  @override
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    final id = '$repositoryId::$destinationPath';
    NotifyingArtifactDownload? download;
    final inner = _delegate.start(
      repositoryId: repositoryId,
      revision: revision,
      path: path,
      destinationPath: destinationPath,
      onProgress: (received, total) {
        download?.updateProgress(received, total);
        onProgress(received, total);
      },
    );
    download = NotifyingArtifactDownload(
      inner: inner,
      coordinator: _coordinator,
      notification: DownloadNotification(
        id: id,
        modelName: repositoryId,
        fileName: path,
      ),
    );
    final notifying = download;
    notifying.attach();
    return notifying;
  }
}

class NotifyingArtifactDownload implements ModelArtifactDownload {
  NotifyingArtifactDownload({
    required this.inner,
    required this.coordinator,
    required this.notification,
  });

  final ModelArtifactDownload inner;
  final DownloadNotificationCoordinator coordinator;
  final DownloadNotification notification;
  int _received = 0;
  int _total = 0;

  /// Lets the owning controller mirror notification actions into row state.
  void Function()? pauseHandler;
  void Function()? resumeHandler;

  void attach() {
    unawaited(
      coordinator.register(
        notification,
        onPause: () {
          if (pauseHandler != null) {
            pauseHandler!();
          } else {
            inner.pause();
          }
        },
        onResume: () {
          if (resumeHandler != null) {
            resumeHandler!();
          } else {
            inner.resume();
          }
        },
        onCancel: inner.cancel,
      ),
    );
    unawaited(
      inner.done.then<void>(
        (_) => coordinator.complete(notification.id),
        onError: (Object _, StackTrace _) =>
            coordinator.complete(notification.id),
      ),
    );
  }

  void updateProgress(int received, int total) {
    _received = received;
    if (total > 0) _total = total;
    unawaited(
      coordinator.updateProgress(
        notification.id,
        receivedBytes: _received,
        totalBytes: _total,
      ),
    );
  }

  @override
  Future<void> get done => inner.done;

  @override
  bool get isPaused => inner.isPaused;

  @override
  void pause() {
    inner.pause();
    unawaited(coordinator.markPaused(notification.id));
  }

  @override
  void resume() {
    inner.resume();
    unawaited(coordinator.markResumed(notification.id));
  }

  @override
  void cancel() {
    inner.cancel();
    unawaited(coordinator.complete(notification.id));
  }
}

final modelArtifactDownloaderProvider = Provider<ModelArtifactDownloader>((
  ref,
) {
  return NotifyingArtifactDownloader(
    HubArtifactDownloader(ref.watch(huggingFaceHubClientProvider)),
    ref.watch(downloadNotificationCoordinatorProvider),
  );
});
