import { Brain, ChevronDown, ChevronUp } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { Colors, IconSizes, Radius, Spacing, Typography } from '@/theme';

export interface ThinkingBlockProps {
  thinking: string;
  isThinkingActive: boolean;
}

export function ThinkingBlock({
  thinking,
  isThinkingActive,
}: ThinkingBlockProps) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <View style={styles.thinkingContainer}>
      <TouchableOpacity
        style={styles.thinkingHeader}
        activeOpacity={0.7}
        onPress={() => setCollapsed((prev) => !prev)}
      >
        <View style={styles.thinkingHeaderLeft}>
          <Brain size={IconSizes.xs} color={Colors.accentLightBlue} />
          <Text style={styles.thinkingHeaderText}>
            {isThinkingActive ? 'Thinking…' : 'Thought process'}
          </Text>
        </View>
        {collapsed ? (
          <ChevronDown size={IconSizes.xs} color={Colors.textMuted} />
        ) : (
          <ChevronUp size={IconSizes.xs} color={Colors.textMuted} />
        )}
      </TouchableOpacity>

      {!collapsed && (
        <View style={styles.thinkingBody}>
          <Text style={styles.thinkingText}>{thinking}</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  thinkingContainer: {
    marginBottom: Spacing.md,
    backgroundColor: Colors.thinkingBg,
    borderRadius: Radius.base,
    borderWidth: 1,
    borderColor: Colors.assistantBubbleBorder,
    overflow: 'hidden',
  },
  thinkingHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    backgroundColor: 'rgba(26,115,232,0.08)',
  },
  thinkingHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  thinkingHeaderText: {
    fontSize: Typography.sizeSm,
    fontWeight: '600',
    color: Colors.accentLightBlue,
  },
  thinkingBody: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: 'rgba(26,115,232,0.15)',
    borderLeftWidth: 3,
    borderLeftColor: Colors.thinkingBorder,
  },
  thinkingText: {
    fontSize: Typography.sizeSm,
    lineHeight: 20,
    color: Colors.textDimmed,
    fontStyle: 'italic',
  },
});
