import { bootstrapApp } from '@/services';
import { NavigationBar } from 'expo-navigation-bar';
import { Slot } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { TamaguiProvider, Theme } from 'tamagui';
import config from '../../tamagui.config';
import { BG_DEEPEST } from '../theme';

SplashScreen.preventAutoHideAsync().catch(() => {});

export default function Layout() {
  useEffect(() => {
    async function prepare() {
      try {
        await bootstrapApp();
        await SystemUI.setBackgroundColorAsync(BG_DEEPEST);
        NavigationBar.setStyle('light');
      } catch (e) {
        console.warn('App bootstrap error:', e);
      } finally {
        await SplashScreen.hideAsync().catch(() => {});
      }
    }
    prepare();
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
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
    </GestureHandlerRootView>
  );
}
