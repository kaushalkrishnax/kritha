import { TamaguiProvider, Theme } from 'tamagui';
import { Slot } from 'expo-router';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import * as SecureStore from 'expo-secure-store';
import { NavigationBar } from 'expo-navigation-bar';
import config from '../../tamagui.config';
import { BG_DEEPEST } from '../theme';
import { cloudService } from '../services/cloud.service';
import KrithaNativeModule from '../../modules/kritha/src/KrithaModule';

export default function Layout() {
  useEffect(() => {
    SystemUI.setBackgroundColorAsync(BG_DEEPEST);

    // Set nav bar style imperatively — avoids crash when activity is gone
    try {
      NavigationBar.setStyle('light');
    } catch {}

    SecureStore.getItemAsync('GEMINI_API_KEY')
      .then((key) => {
        const finalKey = key || process.env.EXPO_PUBLIC_GEMINI_API_KEY || '';
        if (finalKey) {
          cloudService.setApiKey(finalKey);
          KrithaNativeModule.setCloudApiKey(finalKey);
        }
      })
      .catch(console.error);
  }, []);

  return (
    <TamaguiProvider config={config} defaultTheme="dark">
      <Theme name="dark">
        <SafeAreaProvider>
          <StatusBar style="light" />
          <SafeAreaView edges={['top']} style={{ flex: 1 }}>
            <Slot />
          </SafeAreaView>
        </SafeAreaProvider>
      </Theme>
    </TamaguiProvider>
  );
}

