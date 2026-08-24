import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Brain, ChevronDown, ChevronUp } from 'lucide-react-native';
import Colors from '@/theme';

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
          <Brain size={14} color={Colors.accentLightBlue} />
          <Text style={styles.thinkingHeaderText}>
            {isThinkingActive ? 'Thinking…' : 'Thought process'}
          </Text>
        </View>
        {collapsed ? (
          <ChevronDown size={14} color={Colors.textMuted} />
        ) : (
          <ChevronUp size={14} color={Colors.textMuted} />
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
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.assistantBubbleBorder,
    overflow: 'hidden',
  },
  thinkingHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 10,
    paddingVertical: 7,
    backgroundColor: 'rgba(26,115,232,0.08)',
  },
  thinkingHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  thinkingHeaderText: {
    fontSize: 12,
    fontWeight: '600',
    color: Colors.accentLightBlue,
  },
  thinkingBody: {
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(26,115,232,0.15)',
    borderLeftWidth: 3,
    borderLeftColor: Colors.thinkingBorder,
  },
  thinkingText: {
    fontSize: 12.5,
    lineHeight: 18,
    color: Colors.textDimmed,
    fontStyle: 'italic',
  },
});
