import { NavigationBar } from 'expo-navigation-bar';
import { Slot } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import { useEffect } from 'react';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { TamaguiProvider, Theme } from 'tamagui';
import { bootstrapApp } from '@/services';
import config from '../../tamagui.config';
import { BG_DEEPEST } from '../theme';

export default function Layout() {
  useEffect(() => {
    bootstrapApp();
    SystemUI.setBackgroundColorAsync(BG_DEEPEST);
    NavigationBar.setStyle('light');
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
