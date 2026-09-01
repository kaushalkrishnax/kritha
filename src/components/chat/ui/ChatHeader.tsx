import Colors from '@/theme';
import { ChevronDown, Menu, Radio, SquarePen } from 'lucide-react-native';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export interface ChatHeaderProps {
  sidebarOpen?: boolean;
  setSidebarOpen?: (open: boolean) => void;
  isWakeWordOn?: boolean;
  onWakeWordToggle?: () => void;
  modelName?: string;
  onMenu?: () => void;
  onModelSelectClick?: () => void;
  onNewSession?: () => void;
}

export function ChatHeader({
  sidebarOpen,
  setSidebarOpen,
  isWakeWordOn = true,
  onWakeWordToggle,
  modelName = 'Select Model',
  onMenu,
  onModelSelectClick,
  onNewSession,
}: ChatHeaderProps) {
  const handleToggleSidebar = () => {
    if (setSidebarOpen) {
      setSidebarOpen(!sidebarOpen);
    } else if (onMenu) {
      onMenu();
    }
  };

  return (
    <View style={styles.header}>
      <View style={styles.leftSection}>
        <TouchableOpacity onPress={handleToggleSidebar} style={styles.iconBtn}>
          <Menu size={24} color={Colors.textMuted} />
        </TouchableOpacity>

        <TouchableOpacity onPress={onModelSelectClick} style={styles.modelBtn}>
          <Text style={styles.modelBtnText}>{modelName}</Text>
          <ChevronDown size={18} color={Colors.textMuted} />
        </TouchableOpacity>
      </View>

      <View style={styles.rightSection}>
        {onNewSession && (
          <TouchableOpacity onPress={onNewSession} style={styles.iconBtn}>
            <SquarePen size={20} color={Colors.textSecondary} />
          </TouchableOpacity>
        )}
        <TouchableOpacity onPress={onWakeWordToggle} style={styles.iconBtn}>
          <Radio
            size={20}
            color={isWakeWordOn ? Colors.success : Colors.warning}
          />
        </TouchableOpacity>
      </View>
    </View>
  );
}

export default ChatHeader;

const styles = StyleSheet.create({
  header: {
    height: 58,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.bgElevated,
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  modelBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    backgroundColor: Colors.bgElevated,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  modelBtnText: {
    fontSize: 14,
    fontWeight: '700',
    color: Colors.textSecondary,
  },
  iconBtn: {
    padding: 8,
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
});
