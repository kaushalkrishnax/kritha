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

export default function Layout() {
  useEffect(() => {
    SystemUI.setBackgroundColorAsync(BG_DEEPEST);

    try {
      NavigationBar.setStyle('light');
    } catch {}
    
  }, []);

  return (
    <TamaguiProvider config={config} defaultTheme="dark">
      <Theme name="dark">
        <SafeAreaProvider>
          <KeyboardProvider statusBarTranslucent navigationBarTranslucent>
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

