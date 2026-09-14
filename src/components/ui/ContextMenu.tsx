import {
    Animated,
    Modal,
    Pressable,
    StyleSheet,
    Text,
    useWindowDimensions,
    View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import React, { useEffect, useMemo, useState } from 'react';
import { Colors, Radius, Typography } from '@/theme';

export interface ContextMenuItem {
  id: string;
  label: string;
  icon?: React.ReactNode;
  destructive?: boolean;
  disabled?: boolean;
  isSeparator?: boolean;
}

export type ContextMenuAlign = 'left' | 'right' | 'auto';

export interface ContextMenuProps {
  visible: boolean;
  anchor: { x: number; y: number; width?: number; height?: number } | null;
  items: ContextMenuItem[];
  header?: React.ReactNode;
  align?: ContextMenuAlign;
  targetHeight?: number;
  onSelect: (id: string) => void;
  onDismiss: () => void;
}

const MENU_WIDTH = 200;
const ITEM_HEIGHT = 52;
const VERTICAL_GAP = 8;

export function ContextMenu({
  visible,
  anchor,
  items,
  header,
  align = 'auto',
  targetHeight,
  onSelect,
  onDismiss,
}: ContextMenuProps) {
  const [opacity] = useState(() => new Animated.Value(0));
  const [scale] = useState(() => new Animated.Value(0.95));

  const { width: screenWidth, height: screenHeight } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  const menuPosition = useMemo(() => {
    if (!visible || !anchor) return { top: 0, left: 0 };

    const elementHeight = targetHeight ?? anchor.height ?? 0;

    // Horizontal placement based on align prop
    let left: number;
    if (align === 'left') {
      left = insets.left + 12;
    } else if (align === 'right') {
      left = screenWidth - insets.right - MENU_WIDTH - 12;
    } else {
      // 'auto': align based on anchor touch X position, clamped within safe margins
      left = anchor.x;
      if (left + MENU_WIDTH > screenWidth - insets.right - 12) {
        left = screenWidth - insets.right - MENU_WIDTH - 12;
      }
      if (left < insets.left + 12) {
        left = insets.left + 12;
      }
    }

    // Accurate estimate of menu height
    const headerHeight = header ? 42 : 0;
    const estimatedHeight = items.length * ITEM_HEIGHT + 8 + headerHeight + 2;

    // Vertical placement based on trigger element height (default below, flip above if overflowing bottom)
    let top = anchor.y + elementHeight + VERTICAL_GAP;
    if (top + estimatedHeight > screenHeight - insets.bottom - 24) {
      top = anchor.y - estimatedHeight - VERTICAL_GAP;
      if (top < insets.top + 16) {
        top = insets.top + 16;
      }
    }

    return { top, left };
  }, [
    visible,
    anchor,
    align,
    targetHeight,
    screenWidth,
    screenHeight,
    insets.left,
    insets.right,
    insets.top,
    insets.bottom,
    items.length,
    header,
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
          {header && <View style={styles.headerContainer}>{header}</View>}
          {items.map((item, index) => {
            if (item.isSeparator) {
              return <View key={`sep-${index}`} style={styles.separator} />;
            }

            const isFirst = index === 0;
            const isLast = index === items.length - 1;

            return (
              <Pressable
                key={item.id}
                accessibilityRole="menuitem"
                accessibilityLabel={item.label}
                accessibilityState={{ disabled: item.disabled }}
                style={({ pressed }) => [
                  styles.menuItem,
                  isFirst && styles.firstMenuItem,
                  isLast && styles.lastMenuItem,
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
    backgroundColor: 'transparent',
  },
  menuContainer: {
    position: 'absolute',
    width: MENU_WIDTH,
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.xl,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.5,
    shadowRadius: 24,
    elevation: 16,
  },
  headerContainer: {
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 8,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    height: ITEM_HEIGHT,
    width: '100%',
  },
  firstMenuItem: {
    paddingTop: 4,
    height: ITEM_HEIGHT + 4,
  },
  lastMenuItem: {
    paddingBottom: 4,
    height: ITEM_HEIGHT + 4,
  },
  menuItemPressed: {
    backgroundColor: 'rgba(255, 255, 255, 0.09)',
  },
  menuItemDisabled: {
    opacity: 0.5,
  },
  iconContainer: {
    width: 26,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 16,
  },
  menuItemText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeMd,
    fontWeight: '600',
    textAlign: 'left',
  },
  menuItemTextDestructive: {
    color: Colors.warning,
  },
  menuItemTextDisabled: {
    color: Colors.textMuted,
  },
  separator: {
    height: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
    marginVertical: 4,
  },
});
