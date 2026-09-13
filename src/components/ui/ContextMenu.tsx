import React, { useEffect, useMemo, useState } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  Pressable,
  Animated,
  useWindowDimensions,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Colors from '@/theme';

export interface ContextMenuItem {
  id: string;
  label: string;
  icon?: React.ReactNode;
  destructive?: boolean;
  disabled?: boolean;
  isSeparator?: boolean;
}

export interface ContextMenuProps {
  visible: boolean;
  anchor: { x: number; y: number; width: number; height: number } | null;
  items: ContextMenuItem[];
  onSelect: (id: string) => void;
  onDismiss: () => void;
}

const MENU_WIDTH = 170;
const MENU_PADDING = 4;
const ITEM_HEIGHT = 40;

export function ContextMenu({
  visible,
  anchor,
  items,
  onSelect,
  onDismiss,
}: ContextMenuProps) {
  const [opacity] = useState(() => new Animated.Value(0));
  const [scale] = useState(() => new Animated.Value(0.95));

  const { width: screenWidth, height: screenHeight } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  const menuPosition = useMemo(() => {
    if (!visible || !anchor) return { top: 0, left: 0 };
    let left = anchor.x;
    let top = anchor.y;

    // Adjust if menu goes off right edge
    if (left + MENU_WIDTH > screenWidth - insets.right - 12) {
      left = screenWidth - insets.right - MENU_WIDTH - 12;
    }

    // Ensure it doesn't go too far left
    if (left < insets.left + 12) {
      left = insets.left + 12;
    }

    // Rough estimate of menu height
    const estimatedHeight = items.length * ITEM_HEIGHT + MENU_PADDING * 2;

    // Adjust if menu goes off bottom edge
    if (top + estimatedHeight > screenHeight - insets.bottom - 24) {
      top = anchor.y + anchor.height - estimatedHeight;
      if (top < insets.top + 16) {
        top = insets.top + 16;
      }
    }

    return { top, left };
  }, [
    visible,
    anchor,
    screenWidth,
    screenHeight,
    insets.left,
    insets.right,
    insets.top,
    insets.bottom,
    items.length,
  ]);

  useEffect(() => {
    if (visible && anchor) {
      Animated.parallel([
        Animated.timing(opacity, {
          toValue: 1,
          duration: 150,
          useNativeDriver: true,
        }),
        Animated.spring(scale, {
          toValue: 1,
          tension: 300,
          friction: 25,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      opacity.setValue(0);
      scale.setValue(0.95);
    }
  }, [visible, anchor, opacity, scale]);

  if (!visible || !anchor) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={onDismiss}
      supportedOrientations={['portrait', 'landscape']}
    >
      <Pressable style={styles.overlay} onPress={onDismiss}>
        <Animated.View
          style={[
            styles.menuContainer,
            {
              top: menuPosition.top,
              left: menuPosition.left,
              opacity,
              transform: [{ scale }],
            },
          ]}
        >
          {items.map((item, index) => {
            if (item.isSeparator) {
              return <View key={`sep-${index}`} style={styles.separator} />;
            }

            return (
              <Pressable
                key={item.id}
                accessibilityRole="menuitem"
                accessibilityLabel={item.label}
                accessibilityState={{ disabled: item.disabled }}
                style={({ pressed }) => [
                  styles.menuItem,
                  pressed && !item.disabled && styles.menuItemPressed,
                  item.disabled && styles.menuItemDisabled,
                ]}
                onPress={() => {
                  if (!item.disabled) {
                    onSelect(item.id);
                  }
                }}
                disabled={item.disabled}
              >
                {item.icon && (
                  <View style={styles.iconContainer}>{item.icon}</View>
                )}
                <Text
                  style={[
                    styles.menuItemText,
                    item.destructive && styles.menuItemTextDestructive,
                    item.disabled && styles.menuItemTextDisabled,
                  ]}
                >
                  {item.label}
                </Text>
              </Pressable>
            );
          })}
        </Animated.View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFill,
    backgroundColor: Colors.bgScrim,
  },
  menuContainer: {
    position: 'absolute',
    width: MENU_WIDTH,
    backgroundColor: Colors.bgElevated,
    borderRadius: 18,
    padding: MENU_PADDING,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.45,
    shadowRadius: 20,
    elevation: 12,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    height: ITEM_HEIGHT,
    borderRadius: 12,
  },
  menuItemPressed: {
    backgroundColor: Colors.borderFaint,
  },
  menuItemDisabled: {
    opacity: 0.5,
  },
  iconContainer: {
    width: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 6,
  },
  menuItemText: {
    color: Colors.textPrimary,
    fontSize: 14,
    fontWeight: '500',
    textAlign: 'center',
  },
  menuItemTextDestructive: {
    color: Colors.warning,
  },
  menuItemTextDisabled: {
    color: Colors.textMuted,
  },
  separator: {
    height: 1,
    backgroundColor: Colors.borderFaint,
    marginVertical: 3,
    marginHorizontal: 4,
  },
});
