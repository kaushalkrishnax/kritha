import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
} from 'react-native';
import {
  X,
  Search,
  Key,
  Check,
  Pencil,
  Trash2,
} from 'lucide-react-native';
import { useState, useCallback, useEffect } from 'react';
import * as SecureStore from 'expo-secure-store';
import Colors from '@/theme';
import { cloudService } from '@/services/cloud.service';
import KrithaNativeModule from '../../../../modules/kritha/src/KrithaModule';

import { ChatSession } from '@/services/db.service';

export interface ChatSidebarProps {
  sessions: ChatSession[];
  currentSessionId: string | null;
  onSessionSelect: (id: string) => void;
  onNewSession: () => void;
  onSessionDelete?: (id: string) => void;
  onSessionRename?: (id: string, newTitle: string) => void;
  onClose?: () => void;
}

export function ChatSidebar({
  sessions,
  currentSessionId,
  onSessionSelect,
  onNewSession,
  onSessionDelete,
  onSessionRename,
  onClose,
}: ChatSidebarProps) {
  const [apiKey, setApiKey] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState('');

  useEffect(() => {
    SecureStore.getItemAsync('GEMINI_API_KEY')
      .then((key) => {
        if (key) setApiKey(key);
      })
      .catch(console.error);
  }, []);

  const handleApiKeyChange = useCallback((text: string) => {
    setApiKey(text);
    cloudService.setApiKey(text);
    if (KrithaNativeModule.setCloudApiKey) {
      KrithaNativeModule.setCloudApiKey(text);
    }
    SecureStore.setItemAsync('GEMINI_API_KEY', text).catch(console.error);
  }, []);

  const handleEditSubmit = useCallback(
    (id: string) => {
      if (editTitle.trim() && onSessionRename) {
        onSessionRename(id, editTitle.trim());
      }
      setEditingId(null);
    },
    [editTitle, onSessionRename],
  );

  return (
    <View style={styles.sidebar}>
      {/* Top Header with Close [X] Button inside Sidebar */}
      <View style={styles.header}>
        <View style={styles.headerTitleRow}>
          <View style={styles.activeDot} />
          <Text style={styles.timeText}>Kritha AI</Text>
        </View>
        {onClose && (
          <TouchableOpacity
            onPress={onClose}
            style={styles.closeBtn}
            activeOpacity={0.7}
          >
            <X size={18} color="#F1F5F9" />
          </TouchableOpacity>
        )}
      </View>

      {/* Search row */}
      <View style={styles.searchBox}>
        <Search size={18} color={Colors.textDimmed} />
        <Text style={styles.searchPlaceholder}>Search models & chats</Text>
      </View>

      {/* API Key Configuration Card */}
      <View style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Cloud Configuration</Text>
        <View style={styles.apiKeyInputContainer}>
          <Key size={16} color={Colors.textMuted} />
          <TextInput
            style={styles.apiKeyInput}
            placeholder="Gemini API Key"
            placeholderTextColor="#64748B"
            value={apiKey}
            onChangeText={handleApiKeyChange}
            secureTextEntry
            autoCapitalize="none"
            autoCorrect={false}
          />
        </View>
      </View>

      {/* History section */}
      <ScrollView style={styles.historyList}>
        <Text style={styles.sectionTitle}>Chat History</Text>
        {sessions.map((s) => (
          <TouchableOpacity
            key={s.id}
            style={[
              styles.historyRow,
              s.id === currentSessionId && styles.historyRowSelected,
            ]}
            onPress={() => onSessionSelect(s.id)}
            disabled={editingId === s.id}
          >
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
                  s.id === currentSessionId && styles.historyTextSelected,
                ]}
                numberOfLines={1}
              >
                {s.title}
              </Text>
            )}

            <View style={styles.rowActions}>
              {editingId === s.id ? (
                <TouchableOpacity
                  onPress={() => handleEditSubmit(s.id)}
                  style={styles.actionBtn}
                >
                  <Check size={18} color={Colors.success} />
                </TouchableOpacity>
              ) : (
                <>
                  <TouchableOpacity
                    onPress={() => {
                      setEditingId(s.id);
                      setEditTitle(s.title);
                    }}
                    style={styles.actionBtn}
                  >
                    <Pencil size={16} color={Colors.textMuted} />
                  </TouchableOpacity>
                  {onSessionDelete && (
                    <TouchableOpacity
                      onPress={() => onSessionDelete(s.id)}
                      style={styles.actionBtn}
                    >
                      <Trash2
                        size={16}
                        color={Colors.textMuted}
                      />
                    </TouchableOpacity>
                  )}
                </>
              )}
            </View>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

export default ChatSidebar;

const styles = StyleSheet.create({
  sidebar: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: Colors.bgSurface,
    padding: 16,
    zIndex: 1000,
    elevation: 12,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  headerTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  timeText: {
    color: Colors.textPrimary,
    fontSize: 16,
    fontWeight: '700',
  },
  activeDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.success,
  },
  closeBtn: {
    padding: 6,
    borderRadius: 8,
    backgroundColor: Colors.borderStrong,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.bgInput,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 8,
    marginBottom: 16,
  },
  searchPlaceholder: {
    color: Colors.textDimmed,
    fontSize: 14,
  },
  sectionCard: {
    marginBottom: 16,
  },
  sectionTitle: {
    color: Colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  apiKeyInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.bgInput,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 8,
  },
  apiKeyInput: {
    flex: 1,
    color: Colors.textPrimary,
    fontSize: 13,
  },
  historyList: {
    flex: 1,
  },
  historyRow: {
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 4,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  historyRowSelected: {
    backgroundColor: '#1E3A8A',
  },
  historyText: {
    color: Colors.textMuted,
    fontSize: 13,
    flex: 1,
  },
  historyTextSelected: {
    color: Colors.textOnAccent,
    fontWeight: '600',
  },
  rowActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  actionBtn: {
    padding: 6,
  },
});
