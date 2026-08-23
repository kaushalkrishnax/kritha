export type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
};

export type ModelRecord = {
  id: string;
  name: string;
  provider: string;
  totalMb?: number;
  downloadedMb?: number;
  downloaded: boolean;
  isCloud?: boolean;
};

export type DownloadState = {
  modelId: string;
  progress: number;
  downloadedMb: number;
  totalMb: number;
  speed: number;
  active: boolean;
  paused: boolean;
};
