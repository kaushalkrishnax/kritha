import Colors from '@/theme';
import Constants from 'expo-constants';
import { Image } from 'expo-image';
import {
  Archive,
  Clock,
  Library,
  MessageCircle,
  MoreHorizontal,
  Pencil,
  Pin,
  Puzzle,
  Search,
  Settings,
  Share,
  ShieldCheck,
  SquarePen,
  Trash2,
} from 'lucide-react-native';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Easing,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native';

import { ContextMenu, ContextMenuItem } from '@/components/ui/ContextMenu';
import { Session as ChatSession } from '@/database';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  ArchivedChatsModal,
  SettingsModal,
  PermissionsChecklistModal,
} from '@/components/chat/modals';
import { useAssistantStore } from '@/store/assistantStore';

export interface ChatSidebarProps {
  sessions: ChatSession[];
  currentSessionId: string | null;
  onSessionSelect: (id: string) => void;
  onNewSession: () => void;
  onSessionDelete?: (id: string) => void;
  onSessionRename?: (id: string, newTitle: string) => void;
  onSessionPin?: (id: string) => void;
  onSessionArchive?: (id: string) => void;
  onSessionShare?: (id: string) => void;
  onClose?: () => void;
}

export function ChatSidebar({
  sessions,
  currentSessionId,
  onSessionSelect,
  onNewSession,
  onSessionDelete,
  onSessionRename,
  onSessionPin,
  onSessionArchive,
  onSessionShare,
  onClose,
}: ChatSidebarProps) {
  const userName = useAssistantStore((s) => s.userName);
  const initials = useMemo(() => {
    return (
      userName
        .trim()
        .split(/\s+/)
        .map((w) => w[0])
        .join('')
        .toUpperCase()
        .slice(0, 2) || 'YN'
    );
  }, [userName]);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [settingsModalVisible, setSettingsModalVisible] = useState(false);
  const [archivedModalVisible, setArchivedModalVisible] = useState(false);
  const [permissionsModalVisible, setPermissionsModalVisible] = useState(false);
  const insets = useSafeAreaInsets();

  const rowRefs = useRef<{ [key: string]: any }>({});
  const [menuState, setMenuState] = useState<{
    sessionId: string;
    anchor: { x: number; y: number; width: number; height: number };
  } | null>(null);

  const handleEditSubmit = useCallback(
    (id: string) => {
      if (editTitle.trim() && onSessionRename) {
        onSessionRename(id, editTitle.trim());
      }
      setEditingId(null);
    },
    [editTitle, onSessionRename],
  );

  const handleLongPress = useCallback((id: string, touchX: number) => {
    const ref = rowRefs.current[id];
    if (ref && ref.measure) {
      ref.measure(
        (
          x: number,
          y: number,
          width: number,
          height: number,
          pageX: number,
          pageY: number,
        ) => {
          setMenuState({
            sessionId: id,
            anchor: { x: touchX, y: pageY, width, height },
          });
        },
      );
    }
  }, []);

  const activeSession = useMemo(
    () => sessions.find((s) => s.id === menuState?.sessionId),
    [sessions, menuState?.sessionId],
  );

  const menuItems = useMemo<ContextMenuItem[]>(() => {
    if (!activeSession) return [];
    const isPinned = Boolean(activeSession.pinned);
    const isArchived = Boolean(activeSession.archived);

    return [
      {
        id: 'share',
        label: 'Share',
        icon: <Share size={20} color={Colors.textPrimary} />,
      },
      {
        id: 'rename',
        label: 'Rename',
        icon: <Pencil size={20} color={Colors.textPrimary} />,
      },
      { id: 'sep1', label: '', isSeparator: true },
      {
        id: 'pin',
        label: isPinned ? 'Unpin chat' : 'Pin chat',
        icon: <Pin size={20} color={Colors.textPrimary} />,
      },
      {
        id: 'archive',
        label: isArchived ? 'Unarchive' : 'Archive',
        icon: <Archive size={20} color={Colors.textPrimary} />,
      },
      { id: 'sep2', label: '', isSeparator: true },
      {
        id: 'delete',
        label: 'Delete',
        destructive: true,
        icon: <Trash2 size={20} color={Colors.warning} />,
      },
    ];
  }, [activeSession]);

  const handleMenuSelect = useCallback(
    (actionId: string) => {
      const id = menuState?.sessionId;
      if (!id) return;
      setMenuState(null);

      switch (actionId) {
        case 'rename':
          setEditingId(id);
          const session = sessions.find((s) => s.id === id);
          if (session) setEditTitle(session.title);
          break;
        case 'delete':
          onSessionDelete?.(id);
          break;
        case 'share':
          onSessionShare?.(id);
          break;
        case 'pin':
          onSessionPin?.(id);
          break;
        case 'archive':
          onSessionArchive?.(id);
          break;
      }
    },
    [
      menuState?.sessionId,
      sessions,
      onSessionDelete,
      onSessionShare,
      onSessionPin,
      onSessionArchive,
    ],
  );

  // Separate pinned and unpinned sessions
  const activeSessions = sessions.filter((s) => !s.archived);
  const pinnedSessions = activeSessions.filter((s) => s.pinned);
  const recentSessions = activeSessions.filter((s) => !s.pinned);

  const renderSessionRow = (s: ChatSession, isPinnedSection: boolean) => {
    const isSelected = s.id === currentSessionId;
    return (
      <TouchableOpacity
        key={s.id}
        ref={(el) => {
          rowRefs.current[s.id] = el;
        }}
        style={[styles.historyRow, isSelected && styles.historyRowSelected]}
        onPress={() => onSessionSelect(s.id)}
        onLongPress={(e) => handleLongPress(s.id, e.nativeEvent.pageX)}
        delayLongPress={400}
        disabled={editingId === s.id}
      >
        {isPinnedSection && (
          <MessageCircle
            size={18}
            color={Colors.textPrimary}
            style={styles.pinnedIcon}
          />
        )}
        {editingId === s.id ? (
          <TextInput
            style={[
              styles.historyText,
              styles.historyTextSelected,
              { padding: 0, margin: 0 },
            ]}
            value={editTitle}
            onChangeText={setEditTitle}
            onSubmitEditing={() => handleEditSubmit(s.id)}
            onBlur={() => handleEditSubmit(s.id)}
            autoFocus
            returnKeyType="done"
          />
        ) : (
          <Text
            style={[
              styles.historyText,
              isSelected && styles.historyTextSelected,
            ]}
            numberOfLines={1}
          >
            {s.title}
          </Text>
        )}
      </TouchableOpacity>
    );
  };

  // Slide animation
  const slideAnim = useRef(new Animated.Value(-320)).current;
  const backdropOpacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        easing: Easing.out(Easing.poly(4)),
        useNativeDriver: true,
      }),
      Animated.timing(backdropOpacity, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();
  }, [slideAnim, backdropOpacity]);

  const handleClose = useCallback(() => {
    Animated.parallel([
      Animated.timing(slideAnim, {
        toValue: -320,
        duration: 250,
        easing: Easing.in(Easing.poly(4)),
        useNativeDriver: true,
      }),
      Animated.timing(backdropOpacity, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true,
      }),
    ]).start(() => {
      onClose?.();
    });
  }, [slideAnim, backdropOpacity, onClose]);

  const versionName = Constants.expoConfig?.version || '0.1.0';

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
      <TouchableWithoutFeedback onPress={handleClose}>
        <Animated.View
          style={[styles.backdrop, { opacity: backdropOpacity }]}
        />
      </TouchableWithoutFeedback>

      <Animated.View
        style={[
          styles.sidebar,
          {
            paddingTop: 12,
            transform: [{ translateX: slideAnim }],
          },
        ]}
      >
        <View style={styles.headerRow}>
          <Image
            source={require('@/../assets/images/icon.png')}
            style={styles.headerLogo}
          />
          <Text style={styles.headerVersion}>Kritha v{versionName}</Text>
          <View style={{ flex: 1 }} />
          <TouchableOpacity style={styles.headerIconBtn}>
            <Search size={20} color={Colors.textPrimary} />
          </TouchableOpacity>
        </View>

        <ScrollView
          style={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.topActions}>
            <TouchableOpacity style={styles.actionRow} onPress={onNewSession}>
              <SquarePen size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>New chat</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.actionRow}>
              <Library size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Library</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionRow}
              onPress={() => setArchivedModalVisible(true)}
            >
              <Archive size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Archived Chats</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.actionRow}>
              <Clock size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Scheduled</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionRow}
              onPress={() => setPermissionsModalVisible(true)}
            >
              <ShieldCheck size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Permissions</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.actionRow}>
              <MoreHorizontal size={20} color={Colors.textPrimary} />
              <Text style={styles.actionText}>More</Text>
            </TouchableOpacity>
          </View>

          {pinnedSessions.length > 0 && (
            <View style={styles.sectionContainer}>
              <Text style={styles.sectionTitle}>Pinned</Text>
              {pinnedSessions.map((s) => renderSessionRow(s, true))}
            </View>
          )}

          <View style={styles.sectionContainer}>
            <Text style={styles.sectionTitle}>Recents</Text>
            {recentSessions.map((s) => renderSessionRow(s, false))}
          </View>
        </ScrollView>

        <View
          style={[
            styles.bottomAccount,
            { paddingBottom: Math.max(insets.bottom, 16) },
          ]}
        >
          <View style={styles.accountDivider} />
          <View style={styles.accountRow}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{initials}</Text>
            </View>
            <View style={styles.accountInfo}>
              <Text style={styles.accountName}>{userName}</Text>
            </View>
            <TouchableOpacity
              style={styles.storeBtn}
              onPress={() => setSettingsModalVisible(true)}
            >
              <Settings size={20} color={Colors.textMuted} />
            </TouchableOpacity>
          </View>
        </View>

        <ContextMenu
          visible={menuState !== null}
          anchor={menuState?.anchor || null}
          items={menuItems}
          onSelect={handleMenuSelect}
          onDismiss={() => setMenuState(null)}
        />

        <SettingsModal
          visible={settingsModalVisible}
          onClose={() => setSettingsModalVisible(false)}
        />

        <ArchivedChatsModal
          visible={archivedModalVisible}
          onClose={() => setArchivedModalVisible(false)}
        />

        <PermissionsChecklistModal
          visible={permissionsModalVisible}
          onClose={() => setPermissionsModalVisible(false)}
        />
      </Animated.View>
    </View>
  );
}

export default ChatSidebar;

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    zIndex: 999,
  },
  sidebar: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    width: 320,
    backgroundColor: Colors.bgDeepest,
    zIndex: 1000,
    elevation: 12,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 10,
  },
  headerLogo: {
    width: 28,
    height: 28,
    borderRadius: 6,
    marginRight: 10,
  },
  headerVersion: {
    color: Colors.textPrimary,
    fontSize: 18,
    fontWeight: '600',
  },
  headerIconBtn: {
    padding: 6,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.05)',
  },
  scrollContent: {
    flex: 1,
    paddingHorizontal: 12,
  },
  topActions: {
    marginTop: 8,
    marginBottom: 16,
    gap: 4,
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    gap: 12,
    borderRadius: 8,
  },
  actionText: {
    color: Colors.textPrimary,
    fontSize: 16,
    fontWeight: '500',
  },
  sectionContainer: {
    marginBottom: 20,
  },
  sectionTitle: {
    color: Colors.textMuted,
    fontSize: 14,
    fontWeight: '500',
    paddingHorizontal: 12,
    marginBottom: 8,
  },
  historyRow: {
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 2,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  historyRowSelected: {
    backgroundColor: Colors.borderFaint,
  },
  pinnedIcon: {
    marginRight: -2,
  },
  historyText: {
    color: Colors.textSecondary,
    fontSize: 16,
    flex: 1,
  },
  historyTextSelected: {
    color: Colors.textPrimary,
    fontWeight: '500',
  },
  bottomAccount: {
    marginTop: 'auto',
  },
  accountDivider: {
    height: 1,
    backgroundColor: Colors.borderFaint,
    marginBottom: 12,
    marginHorizontal: 4,
  },
  accountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    gap: 12,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.accentBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: Colors.textOnAccent,
    fontSize: 14,
    fontWeight: '700',
  },
  accountInfo: {
    flex: 1,
  },
  accountName: {
    color: Colors.textPrimary,
    fontSize: 16,
    fontWeight: '500',
  },
  accountPlan: {
    color: Colors.textMuted,
    fontSize: 13,
  },
  storeBtn: {
    padding: 8,
  },
});
