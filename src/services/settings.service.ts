import { STORAGE_KEYS } from '@/constants';
import { mmkvStorage, secureStorage } from '@/services';
import { DeviceType, useSettingsStore } from '@/store';

class SettingsService {
  async loadSettings(): Promise<{ userName: string; apiKey: string; customInstructions: string }> {
    const store = useSettingsStore.getState();
    const storeName = store.userName;
    const initialName = (storeName && storeName !== 'Your Name' ? storeName : '') || 'Your Name';
    
    const storedKey = await this.readApiKey();
    const apiKey = storedKey || '';

    return {
      userName: initialName,
      apiKey,
      customInstructions: store.customInstructions || '',
    };
  }

  setUserName(name: string): void {
    useSettingsStore.getState().setUserName(name);
  }

  setCustomInstructions(instructions: string): void {
    useSettingsStore.getState().setCustomInstructions(instructions);
  }

  setDeviceType(device: DeviceType): void {
    useSettingsStore.getState().setDeviceType(device);
  }

  async saveApiKey(apiKey: string): Promise<void> {
    if (!apiKey.trim()) {
      await secureStorage.removeItem(STORAGE_KEYS.geminiApiKey);
    } else {
      await secureStorage.setItem(STORAGE_KEYS.geminiApiKey, apiKey);
    }
  }

  async readApiKey(): Promise<string | null> {
    return await secureStorage.getItem(STORAGE_KEYS.geminiApiKey);
  }

  markPermissionsOnboardingSeen(): void {
    mmkvStorage.setItem(STORAGE_KEYS.permissionsOnboardingSeen, 'true');
  }

  hasSeenPermissionsOnboarding(): boolean {
    return mmkvStorage.getItem(STORAGE_KEYS.permissionsOnboardingSeen) === 'true';
  }
}

export const settingsService = new SettingsService();
