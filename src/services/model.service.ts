import { File, Paths, type DownloadTask } from 'expo-file-system';
import { MODELS, isCloudModel } from '@/constants';
import { useModelStore } from '@/stores';

class ModelDownloadService {
  private readonly downloadMap = new Map<string, DownloadTask>();

  setSelectedModelId(id: string) {
    useModelStore.getState().setSelectedModelId(id);
  }

  async getDownloadedModelPath(id: string): Promise<string | null> {
    const isCloud = isCloudModel(id);
    if (isCloud) return null;
    const model = MODELS.find((m) => m.id === id);
    if (!model) return null;
    const target = new File(Paths.document, model.localPath);
    return target.exists ? target.uri : null;
  }

  async isModelDownloaded(id: string): Promise<boolean> {
    if (isCloudModel(id)) return true;
    return (await this.getDownloadedModelPath(id)) !== null;
  }

  async startDownload(id: string): Promise<void> {
    const model = MODELS.find((m) => m.id === id);
    if (!model) throw new Error(`Model info not found for id: ${id}`);
    if (isCloudModel(id)) return;
    if (this.downloadMap.has(id)) return;

    const target = new File(Paths.document, model.localPath);
    const startTime = Date.now();
    let lastBytes = 0;
    let lastTime = startTime;

    const store = useModelStore.getState();

    const task = File.createDownloadTask(model.remoteUrl, target, {
      onProgress: ({ bytesWritten, totalBytes }) => {
        const now = Date.now();
        const elapsed = (now - lastTime) / 1000;
        const speed = elapsed > 0 ? (bytesWritten - lastBytes) / elapsed : 0;
        lastBytes = bytesWritten;
        lastTime = now;
        const totalMb = totalBytes > 0 ? totalBytes / (1024 * 1024) : 0;
        const downloadedMb = bytesWritten / (1024 * 1024);

        store.setDownloadState({
          modelId: id,
          progress: totalBytes > 0 ? bytesWritten / totalBytes : 0,
          downloadedMb,
          totalMb,
          speed,
          active: true,
          paused: false,
        });
      },
    });

    this.downloadMap.set(id, task);

    try {
      await task.downloadAsync();
      store.setDownloadState({
        modelId: id,
        progress: 1,
        downloadedMb: target.size / (1024 * 1024),
        totalMb: target.size / (1024 * 1024),
        speed: 0,
        active: false,
        paused: false,
      });
      store.markModelDownloaded(id);
    } finally {
      if (this.downloadMap.get(id) === task) {
        this.downloadMap.delete(id);
      }
    }
  }

  async pauseDownload(id: string): Promise<void> {
    const task = this.downloadMap.get(id);
    if (task?.state === 'active') {
      await task.pauseAsync();
      useModelStore.getState().setDownloadState({ paused: true });
    }
  }

  async resumeDownload(id: string): Promise<void> {
    const task = this.downloadMap.get(id);
    if (task?.state === 'paused') {
      await task.resumeAsync();
      useModelStore.getState().setDownloadState({ paused: false });
    }
  }

  async cancelDownload(id: string): Promise<void> {
    const task = this.downloadMap.get(id);
    if (task) {
      task.cancel();
      if (this.downloadMap.get(id) === task) {
        this.downloadMap.delete(id);
      }
    }

    const model = MODELS.find((m) => m.id === id);
    if (!model) return;

    const target = new File(Paths.document, model.localPath);
    if (target.exists) {
      target.delete();
    }
    useModelStore
      .getState()
      .setDownloadState({ active: false, paused: false, progress: 0 });
  }
}

export const modelDownloadService = new ModelDownloadService();
