export type DownloadState = {
  modelId: string;
  progress: number;
  downloadedMb: number;
  totalMb: number;
  speed: number;
  active: boolean;
  paused: boolean;
  error?: string;
};

export type ModelRecord = {
  id: string;
  name: string;
  provider: string;
  downloaded?: boolean;
  isCloud?: boolean;
  totalMb?: number;
  remoteUrl: string;
  localPath: string;
};
