import {
  ChatMode,
  LiveTalkPhase,
  MicOwner,
  SttPhase,
  TtsPhase,
} from '@/constants';
import { useAssistantStore } from '@/stores/assistant.store';
import { useChatStore } from '@/stores/chat.store';
import { useModelStore } from '@/stores/model.store';
import { useVoiceStore } from '@/stores/voice.store';
import {
  pauseForStt,
  resumeFromStt,
  SoniqoSpeech,
  SpeechEvent,
} from '@modules/kritha/src';

import { modelDownloadService } from './model.service';

let _initialized = false;
let _isSessionActive = false;

export const SoniqoCoordinator = {
  async init(): Promise<boolean> {
    if (_initialized) return true;
    try {
      const sttModelId = useVoiceStore.getState().selectedSttModelId;
      const ttsModelId = useVoiceStore.getState().selectedTtsModelId;

      const models = await SoniqoSpeech.listVoiceModels();
      const sttDownloaded = models.find((m) => m.id === sttModelId)?.isDownloaded;
      const ttsDownloaded = models.find((m) => m.id === ttsModelId)?.isDownloaded;
      if (!sttDownloaded || !ttsDownloaded) {
        useVoiceStore.getState().setVoiceModalOpen(true);
        return false;
      }

      const modelId = useModelStore.getState().selectedModelId;
      const modelPath =
        await modelDownloadService.getDownloadedModelPath(modelId);

      // We pass the LLM model path and selected voice models to Soniqo
      await SoniqoSpeech.initialize({
        llmModelPath: modelPath ?? undefined,
        llmDevice: 'cpu', // or from settings
        sttModelId: sttModelId ?? undefined,
        ttsModelId: ttsModelId ?? undefined,
      });
      _initialized = true;

      // Listeners to adapt Soniqo events to Kritha's UI state
      SoniqoSpeech.addSpeechStartedListener(() => {
        useAssistantStore.getState().setSttPhase(SttPhase.LISTENING);
      });

      SoniqoSpeech.addSpeechEndedListener(() => {
        useAssistantStore.getState().setSttPhase(SttPhase.TRANSCRIBING);
      });

      SoniqoSpeech.addTranscriptListener((event: SpeechEvent) => {
        if (event.text) {
          useAssistantStore.getState().setTranscript(event.text);
          // Optional: Add it as a user message to chat UI
          const runId =
            useAssistantStore.getState().assistantRunId || 'voice-run';
          const sessionId = useChatStore.getState().chatSessionId;
          if (sessionId) {
            useChatStore.getState().upsertMessage({
              id: Date.now().toString(),
              sessionId,
              role: 'user',
              text: event.text,
              createdAt: Date.now(),
              status: 'sent',
              runId,
            });
          }
        }
      });

      SoniqoSpeech.addResponseCreatedListener((event: SpeechEvent) => {
        useAssistantStore.getState().setTtsPhase(TtsPhase.SPEAKING);
        if (event.text) {
          // Add assistant response to UI
          const runId =
            useAssistantStore.getState().assistantRunId || 'voice-run';
          const sessionId = useChatStore.getState().chatSessionId;
          if (sessionId) {
            useChatStore.getState().upsertMessage({
              id: (Date.now() + 1).toString(),
              sessionId,
              role: 'assistant',
              text: event.text,
              createdAt: Date.now(),
              status: 'sent',
              runId,
            });
          }
        }
      });

      SoniqoSpeech.addResponseInterruptedListener(() => {
        useAssistantStore.getState().setTtsPhase(TtsPhase.IDLE);
      });

      SoniqoSpeech.addResponseDoneListener(() => {
        useAssistantStore.getState().setTtsPhase(TtsPhase.IDLE);
      });

      SoniqoSpeech.addErrorListener((e) => {
        console.error('SoniqoSpeech error:', e);
      });
      return true;
    } catch (e) {
      console.error('Failed to initialize Soniqo', e);
      return false;
    }
  },

  async handleWakeWordDetected() {
    if (_isSessionActive) return;
    try {
      const ready = await this.init();
      if (!ready) {
        return;
      }

      _isSessionActive = true;
      pauseForStt();

      await this.init();

      // Configure tools - example from AssistantToolExecutor
      SoniqoSpeech.addTool('torch', 'Turn flashlight on or off');
      SoniqoSpeech.addTool('mute', 'Mute or unmute device volume');
      SoniqoSpeech.addTool(
        'settings',
        'Open settings. Requires type argument (e.g. wifi, bluetooth, display)',
      );
      SoniqoSpeech.addTool('dialer', 'Open the phone dialer');

      const store = useAssistantStore.getState();
      store.setChatMode(ChatMode.LIVE_TALK);
      store.setLiveTalkPhase(LiveTalkPhase.LISTENING);
      store.setMic(MicOwner.STT);

      const modelId = useModelStore.getState().selectedModelId;
      const modelPath =
        await modelDownloadService.getDownloadedModelPath(modelId);
      await SoniqoSpeech.start(modelPath ?? undefined, 'cpu');
    } catch (e) {
      console.error('Failed to start voice session', e);
      this.endSession();
    }
  },

  async endSession() {
    if (!_isSessionActive) return;
    try {
      await SoniqoSpeech.stop();
    } catch (e) {
      console.error('Failed to stop Soniqo', e);
    } finally {
      _isSessionActive = false;
      const store = useAssistantStore.getState();
      store.setChatMode(ChatMode.TEXTING);
      store.setLiveTalkPhase(null);
      store.setMic(MicOwner.NONE);
      resumeFromStt();
    }
  },
};
