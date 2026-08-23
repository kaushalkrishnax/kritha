import re

with open('src/components/chat/interface/ChatInterface.tsx', 'r') as f:
    text = f.read()

# 1. Imports
text = text.replace("import { useLiveTalkLoop } from './useLiveTalkLoop';", "import * as Speech from 'expo-speech';")

# 2. Remove liveTalk instantiation
live_talk_regex = re.compile(r"// sendMessageWithText is declared early.*?const \{ isLiveTalk, toggleLiveTalk, handleStopResponse \} = liveTalk;", re.DOTALL)
text = live_talk_regex.sub("", text)

# 3. Rewrite sendMessageWithText
send_msg_regex = re.compile(r"const sendMessageWithText = useCallback\(.*?^  \},.*?\]\n  \);", re.DOTALL | re.MULTILINE)
new_send_msg = """  const sendMessageWithText = useCallback(
    async (text: string, autoTts = false) => {
      if (!text.trim()) return;

      const userText = text.trim();
      const currentMsgs = messagesRef.current;
      const currentSessionId = sessionIdRef.current;

      const userMessage: ChatMessage = {
        id: `${Date.now()}_user`,
        role: 'user',
        text: userText,
      };

      const assistantMsgId = `${Date.now()}_assistant`;

      const placeholderAssistantMsg: ChatMessage = {
        id: assistantMsgId,
        role: 'assistant',
        text: '',
      };

      dispatch({ type: 'SET_MESSAGES', messages: [...currentMsgs, userMessage, placeholderAssistantMsg] });
      dispatch({ type: 'SET_DRAFT', text: '' });
      dispatch({ type: 'SET_SENDING', value: true });
      dispatch({ type: 'SET_ERROR', error: null });

      if (currentMsgs.length === 0 && currentSessionId) {
        const title = userText.length > 25 ? userText.slice(0, 25) + '...' : userText;
        dbService.updateSessionTitle(currentSessionId, title);
        dispatch({ type: 'SET_SESSIONS', sessions: dbService.getSessions() });
      }

      if (currentSessionId) {
        dbService.addMessage({
          id: userMessage.id,
          session_id: currentSessionId,
          role: userMessage.role,
          text: userMessage.text,
          created_at: Date.now(),
        });
      }

      try {
        let responseText = '';
        if (!selectedModel?.isCloud && selectedModel?.downloaded) {
          responseText = await KrithaNativeModule.generateLocalResponse(userText, selectedModel.id);
        } else {
          responseText = await cloudService.generateStreamingResponse(
            [...currentMsgs, userMessage],
            (chunk) => {
              dispatch({ type: 'STREAM_CHUNK', id: assistantMsgId, chunk });
            }
          );
        }

        if (currentSessionId) {
          dbService.addMessage({
            id: assistantMsgId,
            session_id: currentSessionId,
            role: 'assistant',
            text: responseText,
            created_at: Date.now(),
          });
        }

        dispatch({
          type: 'FINISH_ASSISTANT_STREAM',
          id: assistantMsgId,
          fullText: responseText,
        });

        if (autoTts) {
          dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: true, isPaused: false, msgId: assistantMsgId } });
          Speech.speak(responseText, {
            onDone: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
            onError: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
            onStopped: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
          });
        }
      } catch (err: any) {
        dispatch({ type: 'SET_ERROR', error: err?.message || 'Failed to generate response.' });
      } finally {
        isSendingRef.current = false;
        dispatch({ type: 'SET_SENDING', value: false });
      }
    },
    [dispatch, selectedModel],
  );"""
text = send_msg_regex.sub(new_send_msg, text)

# 4. Remove useEffect sendMessageWithTextRef
text = re.sub(r"  useEffect\(\(\) => \{\n    sendMessageWithTextRef.current = sendMessageWithText;\n  \}, \[sendMessageWithText\]\);\n", "", text)

# 5. Fix handleDictatePress
dictate_regex = re.compile(r"  const handleDictatePress = useCallback\(async \(\) => \{.*?  \}, \[dispatch, draft, isRecording, sendMessageWithText, liveTalk\]\);", re.DOTALL)
new_dictate = """  const handleDictatePress = useCallback(async (autoSend?: boolean | any) => {
    const shouldAutoSend = autoSend === true;
    if (isRecording) {
      try { KrithaNativeModule.stopDictation(); } catch { }
      dispatch({ type: 'SET_RECORDING', value: false });
      setIsProcessing(false);
      return;
    }

    Speech.stop();
    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
    
    dispatch({ type: 'SET_PRE_DICTATION_DRAFT', text: draft });
    dispatch({ type: 'SET_RECORDING', value: true });
    setIsProcessing(false);

    const subPartial = KrithaNativeModule.addListener('onDictationPartial', (event) => {
      if (event.text) dispatch({ type: 'SET_DRAFT', text: event.text });
    });

    try {
      const userText = await KrithaNativeModule.startDictation();
      subPartial.remove();
      dispatch({ type: 'SET_RECORDING', value: false });

      if (userText && userText.trim().length > 0) {
        dispatch({ type: 'SET_DRAFT', text: userText.trim() });
        if (shouldAutoSend) {
          sendMessageWithText(userText.trim(), true);
        }
      } else {
        dispatch({ type: 'SET_DRAFT', text: '' });
      }
    } catch {
      subPartial.remove();
      dispatch({ type: 'SET_RECORDING', value: false });
    }
  }, [dispatch, draft, isRecording, sendMessageWithText]);"""
text = dictate_regex.sub(new_dictate, text)

# 6. Fix handleWakeWordDetected
wake_regex = re.compile(r"  const handleWakeWordDetected = useCallback\(\(\) => \{\n    if \(!isRecordingRef.current && !isSendingRef.current\) \{\n      handleDictatePress\(\);\n    \}\n  \}, \[handleDictatePress\]\);")
text = wake_regex.sub("""  const handleWakeWordDetected = useCallback(() => {
    if (!isRecordingRef.current && !isSendingRef.current) {
      handleDictatePress(true);
    }
  }, [handleDictatePress]);""", text)

# 7. Remove liveTalk from JSX
text = text.replace("ttsMsgId={liveTalk.ttsState.msgId}", "ttsMsgId={state.ttsState.msgId}")
text = text.replace("isTtsSpeaking={liveTalk.ttsState.isSpeaking}", "isTtsSpeaking={state.ttsState.isSpeaking}")
text = text.replace("isTtsPaused={liveTalk.ttsState.isPaused}", "isTtsPaused={state.ttsState.isPaused}")

speaker_press_regex = re.compile(r"onSpeakerPress=\{\(id\) => \{\n                  const msg = messages.find\(\(m\) => m.id === id\);\n                  if \(msg\) liveTalk.handleSpeakerPress\(id, msg.text\);\n                \}\}")
new_speaker_press = """onSpeakerPress={(id) => {
                  const msg = messages.find((m) => m.id === id);
                  if (!msg) return;
                  if (state.ttsState.isSpeaking && state.ttsState.msgId === id) {
                    Speech.stop();
                    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } });
                  } else {
                    Speech.stop();
                    dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: true, isPaused: false, msgId: id } });
                    Speech.speak(msg.text, {
                      onDone: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
                      onError: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
                      onStopped: () => dispatch({ type: 'SET_TTS_STATE', state: { isSpeaking: false, isPaused: false, msgId: null } }),
                    });
                  }
                }}"""
text = speaker_press_regex.sub(new_speaker_press, text)

text = text.replace("isLiveTalk={isLiveTalk}", "isLiveTalk={false}")
text = text.replace("onLiveTalkPress={toggleLiveTalk}", "onLiveTalkPress={() => {}}")
text = text.replace("onStopResponse={handleStopResponse}", "onStopResponse={() => KrithaNativeModule.stopGeneration()}")

with open('src/components/chat/interface/ChatInterface.tsx', 'w') as f:
    f.write(text)

print("Done fixing ChatInterface")
