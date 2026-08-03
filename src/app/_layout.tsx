import { DarkTheme, DefaultTheme, ThemeProvider } from 'expo-router';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import AppTabs from '@/components/app-tabs';
import { ListeningOverlay } from '@/components/listening-overlay';
import { useWakeWordBootstrap } from '@/hooks/use-wakeword-bootstrap';

export default function TabLayout() {
  const colorScheme = useColorScheme();
  useWakeWordBootstrap();

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AnimatedSplashOverlay />
      <AppTabs />
      <ListeningOverlay />
    </ThemeProvider>
  );
}
