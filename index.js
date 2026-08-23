import React from 'react';
import { AppRegistry } from 'react-native';
import 'expo-router/entry';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AssistantOverlay } from './src/components/chat/overlay';

function AssistantOverlayRoot() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <AssistantOverlay />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

AppRegistry.registerComponent('AssistantOverlay', () => AssistantOverlayRoot);

