import React, { useState } from 'react';
import { View, TouchableOpacity, Share, StyleSheet } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import {
  ThumbsUp,
  ThumbsDown,
  Copy,
  Check,
  Share2,
  Maximize2,
  Volume2,
  Pause,
  Play,
} from 'lucide-react-native';
import Colors from '@/theme';

export interface ResponseActionsProps {
  msgId?: string;
  textToCopy: string;
  isTtsSpeaking?: boolean;
  isTtsPaused?: boolean;
  onSpeakerPress?: (msgId?: string) => void;
  onExpandPress?: () => void;
  showExpandButton?: boolean;
  style?: object;
}

export function ResponseActions({
  msgId,
  textToCopy,
  isTtsSpeaking = false,
  isTtsPaused = false,
  onSpeakerPress,
  onExpandPress,
  showExpandButton = false,
  style,
}: ResponseActionsProps) {
  const [copied, setCopied] = useState(false);
  const [feedback, setFeedback] = useState<'like' | 'dislike' | null>(null);

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

  const toggleLike = () => {
    setFeedback((prev) => (prev === 'like' ? null : 'like'));
  };

  const toggleDislike = () => {
    setFeedback((prev) => (prev === 'dislike' ? null : 'dislike'));
  };

  return (
    <View style={[styles.actionsRow, style]}>
      <View style={styles.actionsLeft}>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={toggleLike}
        >
          <ThumbsUp
            size={18}
            color={feedback === 'like' ? Colors.accentSky : Colors.iconMuted}
            fill={
              feedback === 'like' ? 'rgba(56, 189, 248, 0.2)' : 'transparent'
            }
          />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={toggleDislike}
        >
          <ThumbsDown
            size={18}
            color={feedback === 'dislike' ? Colors.error : Colors.iconMuted}
            fill={
              feedback === 'dislike'
                ? 'rgba(248, 113, 113, 0.2)'
                : 'transparent'
            }
          />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={handleCopy}
        >
          {copied ? (
            <Check size={18} color={Colors.success} />
          ) : (
            <Copy size={18} color={Colors.iconMuted} />
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionIconBtn}
          activeOpacity={0.7}
          onPress={handleShare}
        >
          <Share2 size={18} color={Colors.iconMuted} />
        </TouchableOpacity>
      </View>

      <View style={styles.actionsRight}>
        {showExpandButton && onExpandPress && (
          <TouchableOpacity
            style={styles.actionIconBtn}
            activeOpacity={0.8}
            onPress={onExpandPress}
          >
            <Maximize2 size={18} color={Colors.iconMuted} />
          </TouchableOpacity>
        )}

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
              <Pause fill={Colors.iconMuted} size={20} color="transparent" />
            ) : isTtsPaused ? (
              <Play size={20} color={Colors.iconMuted} />
            ) : (
              <Volume2 size={20} color={Colors.iconMuted} />
            )}
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 10,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: Colors.borderFaint,
  },
  actionsLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  actionsRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  actionIconBtn: {
    padding: 8,
    borderRadius: 20,
  },
  speakerActive: {
    backgroundColor: Colors.ttsActiveBg,
  },
});
