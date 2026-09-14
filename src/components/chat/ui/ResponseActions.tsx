import {
  Check,
  Copy,
  EllipsisVertical,
  Pause,
  Play,
  Share2,
  Volume2,
} from 'lucide-react-native';
import { useState } from 'react';
import { Share, StyleSheet, TouchableOpacity, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { Colors, IconSizes, Radius } from '@/theme';
import { stubAction } from '@/utils';

export interface ResponseActionsProps {
  msgId?: string;
  textToCopy: string;
  isTtsSpeaking?: boolean;
  isTtsPaused?: boolean;
  onSpeakerPress?: (msgId?: string) => void;
  style?: object;
}

export function ResponseActions({
  msgId,
  textToCopy,
  isTtsSpeaking = false,
  isTtsPaused = false,
  onSpeakerPress,
  style,
}: ResponseActionsProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    if (!textToCopy) return;
    await Clipboard.setStringAsync(textToCopy);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShare = async () => {
    if (!textToCopy) return;
    try {
      await Share.share({ message: textToCopy });
    } catch (e) {
      console.error('Share error:', e);
    }
  };

  const handleMore = () => {
    stubAction('ResponseActions.handleMore');
  };

  return (
    <View style={[styles.actionsRow, style]}>
      <TouchableOpacity
        style={styles.actionIconBtn}
        activeOpacity={0.8}
        onPress={handleCopy}
      >
        {copied ? (
          <Check size={IconSizes.base} color={Colors.success} />
        ) : (
          <Copy size={IconSizes.base} color={Colors.iconMuted} />
        )}
      </TouchableOpacity>

      {onSpeakerPress && (
        <TouchableOpacity
          style={[
            styles.actionIconBtn,
            (isTtsSpeaking || isTtsPaused) && styles.speakerActive,
          ]}
          activeOpacity={0.8}
          onPress={() => onSpeakerPress(msgId)}
        >
          {isTtsSpeaking ? (
            <Pause
              fill={Colors.iconMuted}
              size={IconSizes.base}
              color="transparent"
            />
          ) : isTtsPaused ? (
            <Play size={IconSizes.base} color={Colors.iconMuted} />
          ) : (
            <Volume2 size={IconSizes.base} color={Colors.iconMuted} />
          )}
        </TouchableOpacity>
      )}

      <TouchableOpacity
        style={styles.actionIconBtn}
        activeOpacity={0.8}
        onPress={handleShare}
      >
        <Share2 size={IconSizes.base} color={Colors.iconMuted} />
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.actionIconBtn}
        activeOpacity={0.8}
        onPress={handleMore}
      >
        <EllipsisVertical size={IconSizes.base} color={Colors.iconMuted} />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-start',
    marginTop: 12,
    gap: 2,
  },
  actionIconBtn: {
    padding: 8,
    borderRadius: Radius.lg,
  },
  speakerActive: {
    backgroundColor: Colors.ttsActiveBg,
  },
});
