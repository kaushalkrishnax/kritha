import { Brain, ChevronDown, ChevronUp } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Colors, IconSizes, Radius, Typography } from '@/theme';

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
    marginBottom: 10,
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
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: Colors.thinkingBg,
  },
  thinkingHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  thinkingHeaderText: {
    fontSize: Typography.sizeSm,
    fontWeight: '600',
    color: Colors.accentLightBlue,
  },
  thinkingBody: {
    paddingHorizontal: 12,
    paddingVertical: 10,
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
