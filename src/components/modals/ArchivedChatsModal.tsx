import { ArchiveRestore, Trash2, X } from 'lucide-react-native';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ChatSessionService } from '@/services/chat.service';
import { useChatStore } from '@/stores';
import { Colors, IconSizes, Radius, Typography } from '@/theme';

type ArchivedChatsModalProps = {
  visible: boolean;
  onClose: () => void;
};

export function ArchivedChatsModal({
  visible,
  onClose,
}: ArchivedChatsModalProps) {
  const sessions = useChatStore((s) => s.sessions);
  const archivedSessions = sessions.filter((s) => s.archived);
  const insets = useSafeAreaInsets();

  const handleRestore = (id: string) => {
    ChatSessionService.archiveChat(id, false);
  };

  const handleDelete = (id: string) => {
    ChatSessionService.deleteChat(id);
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <TouchableWithoutFeedback onPress={onClose}>
        <View style={styles.modalContainer}>
          <TouchableWithoutFeedback>
            <View
              style={[
                styles.content,
                { paddingBottom: Math.max(insets.bottom, 16) },
              ]}
            >
              <View style={styles.header}>
                <Text style={styles.title}>Archived Chats</Text>
                <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
                  <X size={IconSizes.base} color={Colors.textMuted} />
                </TouchableOpacity>
              </View>

              <ScrollView style={styles.scrollArea}>
                {archivedSessions.length === 0 ? (
                  <Text style={styles.emptyText}>No archived chats.</Text>
                ) : (
                  archivedSessions.map((session) => (
                    <View key={session.id} style={styles.row}>
                      <Text style={styles.sessionTitle} numberOfLines={1}>
                        {session.title || 'New Chat'}
                      </Text>
                      <View style={styles.actions}>
                        <TouchableOpacity
                          onPress={() => handleRestore(session.id)}
                          style={styles.actionBtn}
                        >
                          <ArchiveRestore
                            size={IconSizes.base}
                            color={Colors.textMuted}
                          />
                        </TouchableOpacity>
                        <TouchableOpacity
                          onPress={() => handleDelete(session.id)}
                          style={styles.actionBtn}
                        >
                          <Trash2 size={IconSizes.base} color={Colors.error} />
                        </TouchableOpacity>
                      </View>
                    </View>
                  ))
                )}
              </ScrollView>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: Colors.bgScrim,
  },
  content: {
    backgroundColor: Colors.bgSurface,
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    maxHeight: '90%',
    minHeight: '50%',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSubtle,
  },
  title: {
    fontSize: Typography.sizeLg,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  closeBtn: {
    padding: 6,
  },
  scrollArea: {
    padding: 16,
  },
  emptyText: {
    color: Colors.textMuted,
    fontSize: Typography.sizeMd,
    textAlign: 'center',
    marginTop: 40,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.borderSubtle,
  },
  sessionTitle: {
    color: Colors.textPrimary,
    fontSize: Typography.sizeMd,
    fontWeight: '500',
    flex: 1,
    marginRight: 16,
  },
  actions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  actionBtn: {
    padding: 8,
  },
});
