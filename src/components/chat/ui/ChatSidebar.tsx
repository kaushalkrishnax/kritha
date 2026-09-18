import { Image } from 'expo-image';
import {
  Archive,
  Library,
  MessageCircle,
  MoreHorizontal,
  Pencil,
  Pin,
  Puzzle,
  Search,
  Settings,
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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Constants from 'expo-constants';
import {
  ArchivedChatsModal,
  ExtensionsRuntimesModal,
  PermissionsChecklistModal,
  SettingsModal,
} from '@/components/chat/modals';
import { ContextMenu, ContextMenuItem } from '@/components/ui/ContextMenu';
import { Session as ChatSession } from '@/database';
import { useSettingsStore } from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';
import { stubAction } from '@/utils';

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
  const userName = useSettingsStore((s) => s.userName);
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
  const [extensionsRuntimesModalVisible, setExtensionsRuntimesModalVisible] =
    useState(false);
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

    return [
      {
        id: 'pin',
        label: isPinned ? 'Unpin' : 'Pin',
        icon: <Pin size={IconSizes.md} color={Colors.textPrimary} />,
      },
      {
        id: 'rename',
        label: 'Rename',
        icon: <Pencil size={IconSizes.md} color={Colors.textPrimary} />,
      },
      {
        id: 'delete',
        label: 'Delete',
        destructive: true,
        icon: <Trash2 size={IconSizes.md} color={Colors.error} />,
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
        activeOpacity={0.7}
        style={[styles.historyRow, isSelected && styles.historyRowSelected]}
        onPress={() => onSessionSelect(s.id)}
        onLongPress={(e) => handleLongPress(s.id, e.nativeEvent.pageX)}
        delayLongPress={400}
        disabled={editingId === s.id}
      >
        {isPinnedSection && (
          <MessageCircle
            size={IconSizes.base}
            color={isSelected ? Colors.textPrimary : Colors.textMuted}
            style={styles.pinnedIcon}
          />
        )}
        {editingId === s.id ? (
          <TextInput
            style={[styles.historyText, { padding: 0, margin: 0 }]}
            value={editTitle}
            onChangeText={setEditTitle}
            onSubmitEditing={() => handleEditSubmit(s.id)}
            onBlur={() => handleEditSubmit(s.id)}
            autoFocus
            returnKeyType="done"
          />
        ) : (
          <Text style={[styles.historyText]} numberOfLines={1}>
            {s.title}
          </Text>
        )}
      </TouchableOpacity>
    );
  };

  const [slideAnim] = useState(() => new Animated.Value(-330));
  const [backdropOpacity] = useState(() => new Animated.Value(0));

  useEffect(() => {
    Animated.parallel([
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 280,
        easing: Easing.out(Easing.poly(4)),
        useNativeDriver: true,
      }),
      Animated.timing(backdropOpacity, {
        toValue: 1,
        duration: 280,
        useNativeDriver: true,
      }),
    ]).start();
  }, [slideAnim, backdropOpacity]);

  const handleClose = useCallback(() => {
    Animated.parallel([
      Animated.timing(slideAnim, {
        toValue: -330,
        duration: 240,
        easing: Easing.in(Easing.poly(4)),
        useNativeDriver: true,
      }),
      Animated.timing(backdropOpacity, {
        toValue: 0,
        duration: 240,
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
            transform: [{ translateX: slideAnim }],
          },
        ]}
      >
        <View style={styles.headerRow}>
          <Image
            source={require('@/../assets/images/icon.png')}
            style={styles.headerLogo}
          />
          <Text style={styles.headerTitle}>Kritha</Text>
          <Text style={styles.headerVersion}>v{versionName}</Text>
          <View style={{ flex: 1 }} />
          <TouchableOpacity
            style={styles.headerSearchBtn}
            activeOpacity={0.7}
            onPress={() => stubAction('ChatSidebar.Search')}
          >
            <Search size={IconSizes.md} color={Colors.textPrimary} />
          </TouchableOpacity>
        </View>

        <ScrollView showsVerticalScrollIndicator={false}>
          <View style={styles.topActions}>
            <TouchableOpacity
              style={styles.actionRow}
              activeOpacity={0.7}
              onPress={onNewSession}
            >
              <SquarePen size={IconSizes.md} color={Colors.textPrimary} />
              <Text style={styles.actionText}>New chat</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.actionRow} activeOpacity={0.7}>
              <Library size={IconSizes.md} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Library</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionRow}
              activeOpacity={0.7}
              onPress={() => setArchivedModalVisible(true)}
            >
              <Archive size={IconSizes.md} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Archived Chats</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionRow}
              activeOpacity={0.7}
              onPress={() => setExtensionsRuntimesModalVisible(true)}
            >
              <Puzzle size={IconSizes.md} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Extensions & Runtimes</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionRow}
              activeOpacity={0.7}
              onPress={() => setPermissionsModalVisible(true)}
            >
              <ShieldCheck size={IconSizes.md} color={Colors.textPrimary} />
              <Text style={styles.actionText}>Permissions</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.actionRow} activeOpacity={0.7}>
              <MoreHorizontal size={IconSizes.md} color={Colors.textPrimary} />
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
              <Text style={styles.accountName} numberOfLines={1}>
                {userName}
              </Text>
            </View>
            <TouchableOpacity
              style={styles.settingsBtn}
              activeOpacity={0.7}
              onPress={() => setSettingsModalVisible(true)}
            >
              <Settings size={IconSizes.md} color={Colors.iconMuted} />
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

        <ExtensionsRuntimesModal
          visible={extensionsRuntimesModalVisible}
          onClose={() => setExtensionsRuntimesModalVisible(false)}
        />
      </Animated.View>
    </View>
  );
}

export default ChatSidebar;

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: Colors.bgScrim,
    zIndex: 999,
  },
  sidebar: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    width: '78%',
    backgroundColor: Colors.bgDeepest,
    borderRightWidth: 1,
    borderRightColor: Colors.borderSubtle,
    zIndex: 1000,
    elevation: 12,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingBottom: 12,
    paddingTop: 4,
  },
  headerLogo: {
    width: 30,
    height: 30,
    borderRadius: Radius.sm,
    marginRight: 10,
  },
  headerTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.size2xl,
    fontWeight: '700',
    letterSpacing: -0.3,
  },
  headerVersion: {
    color: Colors.textMuted,
    fontSize: Typography.sizeXs,
    fontWeight: '500',
    marginLeft: 6,
    marginTop: 4,
  },
  headerSearchBtn: {
    width: 44,
    height: 44,
    padding: 22,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    borderRadius: Radius.full,
    backgroundColor: Colors.bgSecondary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  topActions: {
    marginTop: 10,
    marginBottom: 16,
    gap: 30,
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    gap: 14,
  },
  actionText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeMd,
    fontWeight: '600',
  },
  sectionContainer: {
    marginBottom: 10,
  },
  sectionTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeLg,
    fontWeight: '600',
    paddingHorizontal: 24,
    marginTop: 14,
    marginBottom: 8,
  },
  historyRow: {
    paddingVertical: 16,
    paddingHorizontal: 24,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  historyRowSelected: {
    backgroundColor: Colors.bgPrimary,
  },
  pinnedIcon: {
    marginRight: -2,
  },
  historyText: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeMd,
    flex: 1,
  },
  bottomAccount: {
    marginTop: 'auto',
  },
  accountDivider: {
    height: 1,
    backgroundColor: Colors.borderFaint,
    marginBottom: 12,
  },
  accountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    gap: 12,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: Radius.lg,
    backgroundColor: Colors.accentBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: Colors.textOnAccent,
    fontSize: Typography.sizeBase,
    fontWeight: '700',
  },
  accountInfo: {
    flex: 1,
  },
  accountName: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeMd,
    fontWeight: '600',
  },
  settingsBtn: {
    width: 38,
    height: 38,
    borderRadius: Radius.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
