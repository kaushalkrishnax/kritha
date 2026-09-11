import re

with open("src/components/chat/modals/SettingsModal.tsx", "r") as f:
    content = f.read()

new_section = """
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Voice Models</Text>
                <Text style={styles.sectionDesc}>Download and select TTS & STT models.</Text>
                <TouchableOpacity 
                  style={[styles.saveBtn, { marginTop: 10, backgroundColor: Colors.borderStrong }]}
                  onPress={() => {
                    onClose();
                    useAssistantStore.getState().setVoiceModalOpen(true);
                  }}
                >
                  <Text style={[styles.saveBtnText, { color: Colors.textOnAccent }]}>Manage Voice Models</Text>
                </TouchableOpacity>
              </View>

              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Custom Instructions</Text>
"""

content = content.replace(
"""              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Custom Instructions</Text>""", new_section)

with open("src/components/chat/modals/SettingsModal.tsx", "w") as f:
    f.write(content)
