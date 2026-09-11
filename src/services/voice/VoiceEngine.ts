import { createStreamingSTT, type StreamingSttEngine, type SttStream } from 'react-native-sherpa-onnx/stt';
import { createStreamingTTS, type StreamingTtsEngine, type TtsStreamController } from 'react-native-sherpa-onnx/tts';
import { createPcmLiveStream, type PcmLiveStreamHandle } from 'react-native-sherpa-onnx/audio';
import { getModelPath, ModelCategory } from 'react-native-sherpa-onnx/download';
import { useAssistantStore } from '@/store/assistantStore';
import { dispatchCommand } from '@modules/kritha/src';

class VoiceEngineManager {
  private sttEngine: StreamingSttEngine | null = null;
  private sttStream: SttStream | null = null;
  private pcmStream: PcmLiveStreamHandle | null = null;
  private ttsEngine: StreamingTtsEngine | null = null;
  private ttsController: TtsStreamController | null = null;

  private isInitializingStt = false;
  private isInitializingTts = false;

  async initSTT() {
    if (this.sttEngine || this.isInitializingStt) return;
    this.isInitializingStt = true;
    try {
      const selectedModelId = useAssistantStore.getState().selectedSttModelId;
      if (!selectedModelId) throw new Error('No STT model selected');

      const modelPath = await getModelPath(ModelCategory.Stt, selectedModelId);
      if (!modelPath) throw new Error('STT model not downloaded');

      this.sttEngine = await createStreamingSTT({
        modelPath: { type: 'file', path: modelPath },
        modelType: 'auto',
      });
      console.log('STT engine initialized successfully');
    } catch (e) {
      console.error('Failed to init STT', e);
    } finally {
      this.isInitializingStt = false;
    }
  }

  async initTTS() {
    if (this.ttsEngine || this.isInitializingTts) return;
    this.isInitializingTts = true;
    try {
      const selectedModelId = useAssistantStore.getState().selectedTtsModelId;
      if (!selectedModelId) throw new Error('No TTS model selected');

      const modelPath = await getModelPath(ModelCategory.Tts, selectedModelId);
      if (!modelPath) throw new Error('TTS model not downloaded');

      this.ttsEngine = await createStreamingTTS({
        modelPath: { type: 'file', path: modelPath },
        modelType: 'auto',
      });
      
      const { sampleRate } = await this.ttsEngine.getModelInfo();
      await this.ttsEngine.startPcmPlayer(sampleRate, 1);
      console.log('TTS engine initialized successfully');
    } catch (e) {
      console.error('Failed to init TTS', e);
    } finally {
      this.isInitializingTts = false;
    }
  }

  async startListening() {
    if (!this.sttEngine) await this.initSTT();
    if (!this.sttEngine) {
      console.warn('Cannot start listening, STT engine failed to initialize');
      return;
    }

    try {
      this.sttStream = await this.sttEngine.createStream();
      this.pcmStream = createPcmLiveStream({ sampleRate: 16000, channelCount: 1 });
      
      useAssistantStore.getState().setMicState('STT', true, 0);

      const unsubscribe = this.pcmStream!.onData(async (samples, sampleRate) => {
        if (!this.sttStream) return;
        try {
          const { result, isEndpoint } = await this.sttStream.processAudioChunk(samples, sampleRate);
          if (result.text) {
            useAssistantStore.getState().setTranscript(result.text);
          }
          if (isEndpoint && result.text) {
            const text = result.text;
            await this.sttStream.reset();
            
            dispatchCommand({
              type: 'SUBMIT_TEXT',
              text: text,
              origin: 'MANUAL_DICTATION'
            });
            
            const isLiveTalk = useAssistantStore.getState().isLiveTalk;
            if (!isLiveTalk) {
              this.stopListening();
            }
          }
        } catch (e) {
          console.error('Error processing audio chunk', e);
        }
      });

      await this.pcmStream!.start();
    } catch (e) {
      console.error('Failed to start listening', e);
    }
  }

  async stopListening() {
    try {
      if (this.pcmStream) {
        await this.pcmStream.stop();
        this.pcmStream = null;
      }
      if (this.sttStream) {
        await this.sttStream.release();
        this.sttStream = null;
      }
      useAssistantStore.getState().setMicState('NONE', true, 0);
    } catch (e) {
      console.error('Failed to stop listening', e);
    }
  }

  async playTTS(text: string) {
    if (!this.ttsEngine) await this.initTTS();
    if (!this.ttsEngine) return;

    try {
      useAssistantStore.getState().setTtsState(true, false);
      this.ttsController = await this.ttsEngine.generateSpeechStream(text, undefined, {
        onChunk: async (chunk: any) => {
          if (this.ttsEngine) {
            await this.ttsEngine.writePcmChunk(chunk.samples);
          }
        },
        onEnd: () => {
          useAssistantStore.getState().setTtsState(false, false);
          this.ttsController = null;
        },
        onError: (err: any) => {
          console.error('TTS error', err);
          useAssistantStore.getState().setTtsState(false, false);
        }
      });
    } catch (e) {
      console.error('Failed to play TTS', e);
      useAssistantStore.getState().setTtsState(false, false);
    }
  }

  async stopTTS() {
    if (this.ttsController) {
      await this.ttsController.cancel();
      this.ttsController = null;
    }
    useAssistantStore.getState().setTtsState(false, false);
  }

  async destroy() {
    await this.stopListening();
    await this.stopTTS();
    
    if (this.ttsEngine) {
      await this.ttsEngine.stopPcmPlayer();
      await this.ttsEngine.destroy();
      this.ttsEngine = null;
    }
    
    if (this.sttEngine) {
      await this.sttEngine.destroy();
      this.sttEngine = null;
    }
  }
}

export const VoiceEngine = new VoiceEngineManager();

