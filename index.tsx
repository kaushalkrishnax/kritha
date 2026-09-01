import { AppRegistry } from 'react-native';
import 'expo-router/entry';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { AssistantOverlay } from '@/components/chat/views';
import { useAssistantEventStream } from '@/store/useAssistantEventStream';

function AssistantOverlayRoot() {
  useAssistantEventStream();

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <KeyboardProvider>
          <AssistantOverlay />
        </KeyboardProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

AppRegistry.registerComponent('AssistantOverlay', () => AssistantOverlayRoot);
