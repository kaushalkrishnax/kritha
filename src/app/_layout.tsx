import { TamaguiProvider, Theme } from 'tamagui';
import { Slot } from 'expo-router';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import { NavigationBar } from 'expo-navigation-bar';
import config from '../../tamagui.config';
import { BG_DEEPEST } from '../theme';

import { useAssistantEventStream } from '../store/useAssistantEventStream';
import * as SecureStore from 'expo-secure-store';
import { setCloudApiKey } from '@modules/kritha/src';

export default function Layout() {
  useAssistantEventStream();

  useEffect(() => {
    SystemUI.setBackgroundColorAsync(BG_DEEPEST);

    try {
      NavigationBar.setStyle('light');
    } catch {}

    const loadSettings = async () => {
      try {
        const storedKey = await SecureStore.getItemAsync('GEMINI_API_KEY');
        if (storedKey) {
          setCloudApiKey(storedKey);
        }
      } catch (err) {
        console.warn('Failed to load startup settings:', err);
      }
    };
    loadSettings();
  }, []);

  return (
    <TamaguiProvider config={config} defaultTheme="dark">
      <Theme name="dark">
        <SafeAreaProvider>
          <KeyboardProvider>
            <StatusBar style="light" />
            <SafeAreaView edges={['top']} style={{ flex: 1 }}>
              <Slot />
            </SafeAreaView>
          </KeyboardProvider>
        </SafeAreaProvider>
      </Theme>
    </TamaguiProvider>
  );
}
