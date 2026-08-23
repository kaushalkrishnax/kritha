import { View, StyleSheet, Platform } from 'react-native';
import {
  EnrichedMarkdownText,
  MarkdownStyle,
} from 'react-native-enriched-markdown';
import Colors from '@/theme';

export interface MarkdownRendererProps {
  content: string;
}

export function MarkdownRenderer({ content }: MarkdownRendererProps) {
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={content}
        markdownStyle={markdownStyle}
        selectable
      />
    </View>
  );
}

export default MarkdownRenderer;

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
});

const markdownStyle: MarkdownStyle = {
  paragraph: {
    color: Colors.textPrimary,
    fontSize: 15,
    lineHeight: 22,
    marginTop: 2,
    marginBottom: 4,
  },
  h1: {
    color: Colors.textOnAccent,
    fontSize: 20,
    fontWeight: '700',
    marginTop: 8,
    marginBottom: 4,
  },
  h2: {
    color: Colors.textPrimary,
    fontSize: 18,
    fontWeight: '700',
    marginTop: 6,
    marginBottom: 4,
  },
  h3: {
    color: Colors.textPrimary,
    fontSize: 16,
    fontWeight: '600',
    marginTop: 4,
    marginBottom: 2,
  },
  strong: {
    color: Colors.textOnAccent,
    fontWeight: 'bold',
  },
  em: {
    color: Colors.textSecondary,
    fontStyle: 'italic',
  },
  link: {
    color: Colors.accentLightBlue,
    underline: true,
  },
  code: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 13.5,
    color: Colors.accentSky,
    backgroundColor: Colors.bgElevated,
  },
  codeBlock: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 13,
    color: Colors.textSecondary,
    backgroundColor: Colors.bgInput,
    borderColor: Colors.bgElevated,
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    marginTop: 6,
    marginBottom: 6,
  },
  blockquote: {
    borderColor: Colors.borderAccent,
    borderWidth: 3,
    backgroundColor: 'rgba(30, 41, 59, 0.5)',
    borderRadius: 4,
    padding: 8,
    marginTop: 4,
    marginBottom: 4,
  },
  list: {
    color: Colors.textPrimary,
    fontSize: 15,
    lineHeight: 22,
    bulletColor: Colors.borderAccent,
    markerColor: Colors.accentLightBlue,
    marginTop: 2,
    marginBottom: 4,
  },
  table: {
    borderColor: Colors.borderStrong,
    borderWidth: 1,
    borderRadius: 6,
    headerBackgroundColor: Colors.bgElevated,
    headerTextColor: Colors.textOnAccent,
    rowEvenBackgroundColor: 'transparent',
    rowOddBackgroundColor: 'rgba(30, 41, 59, 0.3)',
  },
  math: {
    color: Colors.textPrimary,
    fontSize: 15,
    marginTop: 4,
    marginBottom: 4,
  },
  inlineMath: {
    color: Colors.textPrimary,
  },
};
