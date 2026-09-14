import { Menu, Radio, SquarePen } from 'lucide-react-native';
import { StyleSheet, TouchableOpacity, View } from 'react-native';
import { useWakeword } from '@/hooks';
import { Colors, IconSizes, Radius, Spacing } from '@/theme';

export interface ChatHeaderProps {
  sidebarOpen?: boolean;
  setSidebarOpen?: (open: boolean) => void;
  modelName?: string;
  onMenu?: () => void;
  onModelSelectClick?: () => void;
  onNewSession?: () => void;
}

export function ChatHeader({
  sidebarOpen,
  setSidebarOpen,
  onMenu,
  onNewSession,
}: ChatHeaderProps) {
  const { isEnabled, toggle } = useWakeword();
  const handleToggleSidebar = () => {
    if (setSidebarOpen) {
      setSidebarOpen(!sidebarOpen);
    } else if (onMenu) {
      onMenu();
    }
  };

  return (
    <View style={styles.header}>
      <View style={styles.roundedSection}>
        <TouchableOpacity onPress={handleToggleSidebar} style={styles.iconBtn}>
          <Menu size={IconSizes.lg} color={Colors.textSecondary} />
        </TouchableOpacity>
      </View>

      <View style={styles.roundedSection}>
        {onNewSession && (
          <TouchableOpacity onPress={onNewSession} style={styles.iconBtn}>
            <SquarePen size={IconSizes.lg} color={Colors.textSecondary} />
          </TouchableOpacity>
        )}
        <TouchableOpacity onPress={toggle} style={styles.iconBtn}>
          <Radio
            size={IconSizes.lg}
            color={isEnabled ? Colors.success : Colors.warning}
          />
        </TouchableOpacity>
      </View>
    </View>
  );
}

export default ChatHeader;

const styles = StyleSheet.create({
  header: {
    height: 60,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    backgroundColor: 'transparent',
  },
  roundedSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    borderWidth: 1,
    borderColor: Colors.borderSubtle,
    borderRadius: Radius.full,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    backgroundColor: Colors.bgSecondary,
  },
  iconBtn: {
    padding: Spacing.sm,
    borderRadius: Radius.lg,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: Radius.sm,
  },
});
