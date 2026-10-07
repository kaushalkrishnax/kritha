import * as Application from 'expo-application';
import Constants from 'expo-constants';
import * as Linking from 'expo-linking';
import { Platform } from 'react-native';

import { useUpdateStore } from '@/stores';

const REGISTRY_BASE_URL = 'https://kritha-registry.kaushalkrishnax.workers.dev';
const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;

export class UpdateService {
  static async checkForUpdates(): Promise<void> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return;
    }

    const { appUpdate, checkForAppUpdate } = useUpdateStore.getState();

    if (appUpdate.checkInProgress) return;

    const lastChecked = appUpdate.lastChecked;
    if (lastChecked && Date.now() - lastChecked < CHECK_INTERVAL_MS) {
      return;
    }

    await checkForAppUpdate();
  }

  static async checkAppUpdateFromRegistry(): Promise<void> {
    const { appUpdate, setAppUpdateAvailable } = useUpdateStore.getState();

    if (appUpdate.checkInProgress) return;

    const currentVersion = this.getCurrentVersion();
    const arch = await this.getDeviceArchitecture();

    try {
      useUpdateStore.getState().setCheckInProgress(true);

      const response = await fetch(`${REGISTRY_BASE_URL}/check`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: currentVersion, arch, platform: Platform.OS }),
      });

      if (!response.ok) {
        throw new Error(`Registry check failed: ${response.status}`);
      }

      const data = await response.json();

      if (data.updateAvailable) {
        let releaseNotes: string | undefined;
        if (data.changelog) {
          const entries = Object.entries(data.changelog) as [string, string[]][];
          releaseNotes = entries.flatMap(([section, items]) =>
            [`**${section}**`, ...items.map((i: string) => `* ${i}`)]
          ).join('\n');
        }

        setAppUpdateAvailable({
          latestVersion: data.latestVersion,
          releaseUrl: data.releaseUrl,
          releaseNotes,
          publishedAt: data.publishedAt,
          severity: data.severity,
        });
      } else {
        useUpdateStore.getState().setCheckInProgress(false);
      }
    } catch (error) {
      console.warn('Update check failed:', error);
      useUpdateStore.getState().setCheckInProgress(false);
    }
  }

  static getCurrentVersion(): string {
    return (
      Application.nativeApplicationVersion ??
      Application.nativeBuildVersion ??
      Constants.expoConfig?.version ??
      '0.0.0'
    );
  }

  static async getDeviceArchitecture(): Promise<string> {
    const { NativeModules } = await import('react-native');
    const platformConstants = NativeModules.PlatformConstants as { SupportedAbis?: string[] } | undefined;
    const supportedAbis = platformConstants?.SupportedAbis ?? [];
    return supportedAbis[0] ?? 'arm64-v8a';
  }

  static openReleaseUrl(): void {
    const { appUpdate } = useUpdateStore.getState();
    if (appUpdate.info?.releaseUrl) {
      Linking.openURL(appUpdate.info.releaseUrl);
    }
  }

  static markUpdateSeen(): void {
    const { appUpdate, markAppUpdateSeen } = useUpdateStore.getState();
    if (appUpdate.info?.latestVersion) {
      markAppUpdateSeen(appUpdate.info.latestVersion);
    }
  }

  static dismissUpdate(): void {
    useUpdateStore.getState().dismissAppUpdate();
  }
}

export const updateService = UpdateService;