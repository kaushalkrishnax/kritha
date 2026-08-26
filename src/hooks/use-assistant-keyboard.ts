import { useAnimatedStyle } from 'react-native-reanimated';
import { useReanimatedKeyboardAnimation } from 'react-native-keyboard-controller';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export function useAssistantKeyboard() {
  const insets = useSafeAreaInsets();
  const keyboard = useReanimatedKeyboardAnimation();

  return useAnimatedStyle(
    () => {
      const keyboardHeight = Math.abs(keyboard.height.value);

      const bottomPadding =
        keyboardHeight > 0
          ? keyboardHeight
          : Math.max(insets.bottom, 16);

      return {
        paddingBottom: bottomPadding,
      };
    },
    [insets.bottom],
  );
}