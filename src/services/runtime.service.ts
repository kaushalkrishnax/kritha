import {
  canInstallPackages,
  installRuntime,
  listRuntimes,
  addRuntimeInstallProgressListener,
  openInstallPermissionSettings,
  RuntimeInfo,
  RuntimeInstallProgressEvent,
  RuntimeInstallResult,
} from '@modules/kritha/src';

export type { RuntimeInfo, RuntimeInstallProgressEvent, RuntimeInstallResult };

export type RuntimeIdInput = string | string[];

export async function getRuntimes(): Promise<RuntimeInfo[]> {
  return await listRuntimes();
}

export async function installRuntimes(
  runtimeIds: RuntimeIdInput,
): Promise<RuntimeInstallResult[]> {
  return await installRuntime(runtimeIds);
}

export function canInstallRuntimeFeatures(): boolean {
  return canInstallPackages();
}

export function openRuntimeInstallPermissionSettings(): boolean {
  return openInstallPermissionSettings();
}

export function subscribeRuntimeInstallProgress(
  listener: (event: RuntimeInstallProgressEvent) => void,
): () => void {
  const sub = addRuntimeInstallProgressListener(listener);
  return () => sub.remove();
}
