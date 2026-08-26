import { chatApi } from '@/services/chat.service';
import { useAssistantStore } from '@/store/assistantStore';
import Colors from '@/theme';
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

type ArchivedChatsModalProps = {
  visible: boolean;
  onClose: () => void;
};

export function ArchivedChatsModal({
  visible,
  onClose,
}: ArchivedChatsModalProps) {
  const sessions = useAssistantStore((s) => s.sessions);
  const archivedSessions = sessions.filter((s) => s.archived);
  const insets = useSafeAreaInsets();

  const handleRestore = (id: string) => {
    chatApi.archiveChat(id, false);
  };

  const handleDelete = (id: string) => {
    chatApi.deleteChat(id);
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
                  <X size={20} color={Colors.textMuted} />
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
                          <ArchiveRestore size={18} color={Colors.textMuted} />
                        </TouchableOpacity>
                        <TouchableOpacity
                          onPress={() => handleDelete(session.id)}
                          style={styles.actionBtn}
                        >
                          <Trash2 size={18} color={Colors.error} />
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
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  content: {
    backgroundColor: Colors.bgSurface,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
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
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  closeBtn: {
    padding: 4,
  },
  scrollArea: {
    padding: 16,
  },
  emptyText: {
    color: Colors.textMuted,
    fontSize: 16,
    textAlign: 'center',
    marginTop: 40,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.borderSubtle,
  },
  sessionTitle: {
    color: Colors.textPrimary,
    fontSize: 16,
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
