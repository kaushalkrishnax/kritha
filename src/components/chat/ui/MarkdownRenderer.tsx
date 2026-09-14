import { useMemo } from 'react';
import { Linking } from 'react-native';
import {
  EnrichedMarkdownText,
  type MarkdownStyle,
} from 'react-native-enriched-markdown';
import { Colors, Typography, IconSizes, Radius } from '@/theme';
export const markdownRendererStyle: MarkdownStyle = {
  paragraph: {
    fontSize: Typography.sizeBase,
    color: Colors.textPrimary,
    lineHeight: Typography.sizeBase * 1.55,
    marginTop: 0,
    marginBottom: Typography.sizeBase,
    textAlign: 'left',
  },

  h1: {
    fontSize: Typography.size3xl,
    fontWeight: 'bold',
    color: Colors.textPrimary,
    lineHeight: Typography.size3xl * 1.2,
    marginTop: Typography.sizeLg,
    marginBottom: Typography.sizeBase,
    textAlign: 'left',
  },

  h2: {
    fontSize: Typography.size2xl,
    fontWeight: 'bold',
    color: Colors.textPrimary,
    lineHeight: Typography.size2xl * 1.25,
    marginTop: Typography.sizeLg,
    marginBottom: Typography.sizeBase,
    textAlign: 'left',
  },

  h3: {
    fontSize: Typography.sizeXl,
    fontWeight: 'bold',
    color: Colors.textPrimary,
    lineHeight: Typography.sizeXl * 1.3,
    marginTop: Typography.sizeMd,
    marginBottom: Typography.sizeXs,
    textAlign: 'left',
  },

  h4: {
    fontSize: Typography.sizeLg,
    fontWeight: '600',
    color: Colors.textPrimary,
    lineHeight: Typography.sizeLg * 1.35,
    marginTop: Typography.sizeMd,
    marginBottom: Typography.sizeXs,
    textAlign: 'left',
  },

  h5: {
    fontSize: Typography.sizeMd,
    fontWeight: '600',
    color: Colors.textPrimary,
    lineHeight: Typography.sizeMd * 1.4,
    marginTop: Typography.sizeBase,
    marginBottom: Typography.sizeXs,
    textAlign: 'left',
  },

  h6: {
    fontSize: Typography.sizeBase,
    fontWeight: '600',
    color: Colors.textSecondary,
    lineHeight: Typography.sizeBase * 1.45,
    marginTop: Typography.sizeBase,
    marginBottom: Typography.sizeXs,
    textAlign: 'left',
  },

  blockquote: {
    fontSize: Typography.sizeBase,
    color: Colors.textSecondary,
    lineHeight: Typography.sizeBase * 1.55,
    marginTop: Typography.sizeXs,
    marginBottom: Typography.sizeBase,
    borderColor: Colors.borderAccent,
    borderWidth: 1,
    gapWidth: Typography.sizeBase,
    backgroundColor: Colors.bgPrimary,
    borderRadius: Radius.sm,
    padding: Typography.sizeBase,
  },

  list: {
    fontSize: Typography.sizeBase,
    color: Colors.textPrimary,
    lineHeight: Typography.sizeBase * 1.55,
    bulletColor: Colors.accentLightBlue,
    bulletSize: IconSizes.xs / 2,
    markerMinWidth: IconSizes.lg,
    markerColor: Colors.accentLightBlue,
    markerFontWeight: '600',
    gapWidth: Typography.sizeBase,
    marginLeft: Typography.sizeLg,
    itemSpacing: Typography.sizeXs,
  },

  code: {
    fontFamily: 'monospace',
    fontSize: Typography.sizeBase,
    color: Colors.accentSky,
    backgroundColor: Colors.bgTertiary,
    borderColor: Colors.borderSubtle,
  },

  codeBlock: {
    fontSize: Typography.sizeBase,
    fontFamily: 'monospace',
    color: Colors.textSecondary,
    backgroundColor: Colors.bgDeepest,
    borderColor: Colors.borderSubtle,
    borderWidth: 1,
    borderRadius: Radius.base,
    padding: Typography.sizeBase,
    marginTop: Typography.sizeBase,
    marginBottom: Typography.sizeMd,

    syntaxColors: {
      keyword: Colors.accentLightBlue,
      operator: Colors.textSecondary,
      punctuation: Colors.textSecondary,
      string: Colors.success,
      number: Colors.accentSky,
      constant: Colors.accentLightBlue,
      comment: Colors.textMuted,
      function: Colors.accentSky,
      type: Colors.accentLightBlue,
      variable: Colors.textSecondary,
      property: Colors.accentSky,
      tag: Colors.accentLightBlue,
      attribute: Colors.accentSky,
      embedded: Colors.textSecondary,
    },
  },

  strong: {
    color: Colors.textPrimary,
    fontWeight: 'bold',
  },

  em: {
    color: Colors.textSecondary,
    fontStyle: 'italic',
  },

  strikethrough: {
    color: Colors.textMuted,
  },

  underline: {
    color: Colors.textPrimary,
  },

  link: {
    color: Colors.accentLightBlue,
    underline: true,
  },

  highlight: {
    color: Colors.textPrimary,
    backgroundColor: Colors.bgTertiary,
  },

  image: {
    aspectRatio: 16 / 9,
    resizeMode: 'contain',
    borderRadius: Radius.base,
    marginTop: Typography.sizeBase,
    marginBottom: Typography.sizeMd,
  },

  inlineImage: {
    size: IconSizes.lg,
  },

  thematicBreak: {
    color: Colors.borderSubtle,
    height: 1,
    marginTop: Typography.sizeMd,
    marginBottom: Typography.sizeMd,
  },

  table: {
    fontSize: Typography.sizeBase,
    color: Colors.textPrimary,
    lineHeight: Typography.sizeBase * 1.45,
    headerBackgroundColor: Colors.bgTertiary,
    headerTextColor: Colors.textPrimary,
    rowEvenBackgroundColor: Colors.bgSurface,
    rowOddBackgroundColor: Colors.bgPrimary,
    borderColor: Colors.borderSubtle,
    borderWidth: 1,
    borderRadius: Radius.sm,
    cellPaddingHorizontal: Typography.sizeBase,
    cellPaddingVertical: Typography.sizeXs,
    horizontalOverflow: 0,
    align: 'left',
  },

  taskList: {
    checkedColor: Colors.accentBlue,
    borderColor: Colors.borderStrong,
    checkmarkColor: Colors.textOnAccent,
    checkboxSize: IconSizes.sm,
    checkboxBorderRadius: Radius.xs,
    checkedTextColor: Colors.textMuted,
    checkedStrikethrough: true,
  },

  math: {
    fontSize: Typography.sizeLg,
    color: Colors.textPrimary,
    backgroundColor: Colors.bgPrimary,
    padding: Typography.sizeMd,
    marginTop: Typography.sizeBase,
    marginBottom: Typography.sizeMd,
    textAlign: 'center',
  },

  inlineMath: {
    color: Colors.accentLightBlue,
  },

  spoiler: {
    color: Colors.textMuted,
    particles: {
      density: Typography.sizeBase,
      speed: Typography.size2xl,
    },
    solid: {
      borderRadius: Radius.sm,
    },
  },

  superscript: {
    fontScale: 0.75,
    baselineOffsetScale: 0.35,
  },

  subscript: {
    fontScale: 0.75,
    baselineOffsetScale: 0.2,
  },
};

export function MarkdownRenderer({ content }: { content: string }) {
  const style = useMemo(() => markdownRendererStyle, []);

  return (
    <EnrichedMarkdownText
      markdown={content}
      flavor="github"
      md4cFlags={{
        underline: true,
        superscript: true,
        subscript: true,
        highlight: true,
        latexMath: true,
      }}

      writingDirection="first-strong"
      streamingAnimation={true}
      streamingConfig={{
        tableMode: 'progressive',
        codeBlockMode: 'progressive',
      }}
      spoilerOverlay="particles"
      markdownStyle={style}
      onLinkPress={({ url }) => Linking.openURL(url)}
    />
  );
}
