import { getConversationContext } from '@/services/conversation-context.service';
import { useAssistantStore } from '@/store/assistantStore';
import { submitText } from '@modules/kritha/src';
import { createPcmLiveStream, type PcmLiveStreamHandle } from 'react-native-sherpa-onnx/audio';
import { getModelPath, ModelCategory } from 'react-native-sherpa-onnx/download';
import { createStreamingSTT, createSTT, type StreamingSttEngine, type SttStream, type SttEngine } from 'react-native-sherpa-onnx/stt';
import { createStreamingTTS, type StreamingTtsEngine, type TtsStreamController } from 'react-native-sherpa-onnx/tts';

// ---------------------------------------------------------------------------
// VoiceEngineManager — single JS-side manager for STT & TTS via sherpa-onnx.
//
// This is the **only** authority for mic / speaker state.  It drives:
//   • canonicalState  (LISTENING / SPEAKING / IDLE)
//   • micOwner / isMicAvailable
//   • isTtsSpeaking / isTtsPaused / currentTtsMsgId
//   • liveTalkState
//   • transcript / draftText
// ---------------------------------------------------------------------------

class VoiceEngineManager {
  // ---- engines (lazy-init, long-lived until destroy()) ----
  private sttEngine: StreamingSttEngine | SttEngine | null = null;
  private isOfflineStt = false;
  private offlineSamplesBuffer: number[] = [];
  private ttsEngine: StreamingTtsEngine | null = null;

  // ---- active session handles ----
  private sttStream: SttStream | null = null;
  private pcmStream: PcmLiveStreamHandle | null = null;
  private pcmUnsub: (() => void) | null = null;          // onData unsubscribe
  private ttsController: TtsStreamController | null = null;
  private totalGeneratedSamples = 0;
  private ttsStartTimeMs = 0;

  // ---- init guards ----
  private isInitializingStt = false;
  private isInitializingTts = false;

  // ---- runtime flags ----
  private _isListening = false;
  private _isSpeaking = false;

  // ======================= helpers ==========================

  private get store() {
    return useAssistantStore.getState();
  }

  /** Whether we are currently in a live-talk session. */
  private get isLiveTalkActive(): boolean {
    return this.store.isLiveTalk;
  }

  // ======================= STT engine =======================

  /**
   * Lazily initialise the streaming STT recognizer.
   * Throws if no model is selected or the model isn't downloaded.
   */
  async initSTT(): Promise<void> {
    if (this.sttEngine || this.isInitializingStt) return;
    this.isInitializingStt = true;
    try {
      const selectedModelId = this.store.selectedSttModelId;
      if (!selectedModelId) throw new Error('No STT model selected');

      const modelPath = await getModelPath(ModelCategory.Stt, selectedModelId);
      if (!modelPath) throw new Error('STT model not downloaded');

      if (selectedModelId.includes('moonshine') || selectedModelId.includes('sense-voice')) {
        this.isOfflineStt = true;
        this.sttEngine = await createSTT({
          modelPath: { type: 'file', path: modelPath },
        });
      } else {
        this.isOfflineStt = false;
        this.sttEngine = await createStreamingSTT({
          modelPath: { type: 'file', path: modelPath },
          modelType: 'auto',
        });
      }
      console.log('[VoiceEngine] STT engine initialized');
    } finally {
      this.isInitializingStt = false;
    }
  }

  // ======================= TTS engine =======================

  /**
   * Lazily initialise the streaming TTS engine + PCM player.
   * Throws if no model is selected or the model isn't downloaded.
   */
  async initTTS(): Promise<void> {
    if (this.ttsEngine || this.isInitializingTts) return;
    this.isInitializingTts = true;
    try {
      const selectedModelId = this.store.selectedTtsModelId;
      if (!selectedModelId) throw new Error('No TTS model selected');

      const modelPath = await getModelPath(ModelCategory.Tts, selectedModelId);
      if (!modelPath) throw new Error('TTS model not downloaded');

      this.ttsEngine = await createStreamingTTS({
        modelPath: { type: 'file', path: modelPath },
        modelType: 'auto',
      });

      const { sampleRate } = await this.ttsEngine.getModelInfo();
      await this.ttsEngine.startPcmPlayer(sampleRate, 1);
      console.log('[VoiceEngine] TTS engine initialized');
    } finally {
      this.isInitializingTts = false;
    }
  }

  // ======================= STT: start / stop ================

  /**
   * Begin streaming STT from the device microphone.
   *
   * - Sets `canonicalState` → `'LISTENING'`
   * - Updates `micOwner` → `'STT'`
   * - In live-talk mode also sets `liveTalkState` → `'LISTENING'`
   *
   * Re-throws init errors so callers can open the model picker.
   */
  async startListening(): Promise<void> {
    // Guard: already listening
    if (this._isListening) return;

    // Ensure engine is ready (will throw on missing model)
    if (!this.sttEngine) await this.initSTT();
    if (!this.sttEngine) throw new Error('STT engine failed to initialize');

    try {
      // Clean up any leftover session

      this._isListening = true;

      if (!this.isOfflineStt) {
        this.sttStream = await (this.sttEngine as StreamingSttEngine).createStream();
      } else {
        this.offlineSamplesBuffer = [];
      }
      this.pcmStream = createPcmLiveStream({ sampleRate: 16000, channelCount: 1 });

      // Update store — UI will react immediately
      this.store.setCanonicalState('LISTENING');
      this.store.setMicState('STT', true, 0);
      if (this.isLiveTalkActive) {
        this.store.setLiveTalkState('LISTENING');
      }

      // Subscribe to PCM data
      this.pcmUnsub = this.pcmStream.onData(async (samples, sampleRate) => {
        if (!this._isListening) return;
        if (!this.isOfflineStt && !this.sttStream) return;
        try {
          
          let sumSquares = 0;
          for (let i = 0; i < samples.length; i++) {
            sumSquares += samples[i] * samples[i];
          }
          const rms = Math.sqrt(sumSquares / samples.length);
          const scaledRms = Math.min(12, rms * 50);

          // Only update volume state if changed significantly (threshold 0.5)
          // This prevents excessive state updates during audio processing
          const prevVolume = this.store.volumeRms;
          if (Math.abs(scaledRms - prevVolume) > 0.5) {
            this.store.setMicState('STT', true, scaledRms);
          }

          let result = { text: '' };
          let isEndpoint = false;
          
          if (this.isOfflineStt) {
            // Push samples to buffer for offline processing later
            for (let i = 0; i < samples.length; i++) {
              this.offlineSamplesBuffer.push(samples[i]);
            }
          } else {
            const res = await this.sttStream!.processAudioChunk(samples, sampleRate);
            result = res.result;
            isEndpoint = res.isEndpoint;
          }

          if (result.text) {
            const lowerText = result.text.toLowerCase();
            this.store.setTranscript(lowerText);
            if (this.isLiveTalkActive) {
              this.store.setDraftText(lowerText);
            }
          }

          if (isEndpoint && result.text) {
            const text = result.text.toLowerCase();
            if (this.sttStream) await this.sttStream.reset();
            
            if (this.isLiveTalkActive) {
              this.store.setTranscript('');
              this.store.setDraftText('');
              submitText(text, {
                origin: 'LIVE_TALK',
                ...(this.store.chatSessionId && { chatSessionId: this.store.chatSessionId }),
                history: getConversationContext(),
              });
              this.stopListening();
            } else {
              // Manual dictation: don't auto-stop on endpoint, just keep going or wait for user to hit stop.
              // Actually, user said: "when the user stops send to intelligence pipeline... however on the live mode it should be oppsoite".
              // In dictation mode, we don't auto submit. We just keep text in draftText.
            }
          }

        } catch (e) {
          console.error('[VoiceEngine] Error processing audio chunk', e);
        }
      });

      await this.pcmStream.start();
    } catch (e) {
      this._isListening = false;
      this.store.setCanonicalState('IDLE');
      this.store.setMicState('NONE', true, 0);
      if (this.isLiveTalkActive) {
        this.store.setLiveTalkState('IDLE');
      }
      throw e;
    }
  }

  /**
   * Stop streaming STT.
   *
   * - Sets `canonicalState` → `'IDLE'` (unless live-talk is active and TTS will take over)
   * - Resets `micOwner` → `'NONE'`
   */
  async stopListening(forceImmediate = false): Promise<void> {
    if (!this._isListening) return;

    try {
      if (!this.isLiveTalkActive && !forceImmediate) {
        // Go into TRANSCRIBING state briefly for UX
        this.store.setCanonicalState('TRANSCRIBING');
        // Give it a tiny delay to simulate processing so user sees the UI change
        await new Promise(r => setTimeout(r, 400));
        
        // Ensure final text is in draftText
        let text = this.store.transcript;
        if (this.isOfflineStt && this.offlineSamplesBuffer.length > 0) {
          try {
            const res = await (this.sttEngine as SttEngine).transcribeSamples(this.offlineSamplesBuffer, 16000);
            text = res.text;
          } catch(e) {
            console.warn('Offline STT error', e);
          }
        }
        
        if (text) {
          this.store.setDraftText(text);
          this.store.setTranscript('');
        }
      } else {
        // Live talk stop logic
        let text = this.store.transcript;
        if (this.isOfflineStt && this.offlineSamplesBuffer.length > 0) {
          try {
            const res = await (this.sttEngine as SttEngine).transcribeSamples(this.offlineSamplesBuffer, 16000);
            text = res.text;
          } catch(e) {
            console.warn('Offline STT error', e);
          }
        }
        if (text) {
          this.store.setTranscript('');
          this.store.setDraftText('');
          submitText(text, {
            origin: 'LIVE_TALK',
            ...(this.store.chatSessionId && { chatSessionId: this.store.chatSessionId }),
            history: getConversationContext(),
          });
        }
      }

      if (this.pcmUnsub) {
        this.pcmUnsub();
        this.pcmUnsub = null;
      }
      if (this.pcmStream) {
        await this.pcmStream.stop();
        this.pcmStream = null;
      }
      if (this.sttStream) {
        await this.sttStream.release();
        this.sttStream = null;
      }
    } catch (e) {
      console.warn('[VoiceEngine] cleanup error', e);
    } finally {
      this._isListening = false;
      this.store.setMicState('NONE', true, 0);
      
      const current = this.store.canonicalState;
      if (current === 'LISTENING' || current === 'TRANSCRIBING') {
        this.store.setCanonicalState('IDLE');
      }
    }
  }

  // ======================= TTS: play / stop =================

  /**
   * Play TTS for the given text.
   *
   * - Stops any currently playing TTS first
   * - Sets `isTtsSpeaking: true`, `canonicalState: 'SPEAKING'`
   * - On completion, resets to IDLE (or restarts STT if live-talk)
   *
   * @param text     The text to speak
   * @param msgId    Optional message ID for tracking which bubble is active
   */
  async playTTS(text: string, msgId?: string | null): Promise<void> {
    if (!text?.trim()) return;

    // Stop any running TTS first
    if (this._isSpeaking) {
      await this.stopTTS();
    }

    // Stop any running STT — can't listen while speaking
    if (this._isListening) {
      await this.stopListening();
    }

    // Ensure TTS engine is ready (will throw on missing model)
    if (!this.ttsEngine) await this.initTTS();
    if (!this.ttsEngine) throw new Error('TTS engine failed to initialize');

    this._isSpeaking = true;

    // Update store — UI reacts immediately
    this.store.setTtsState(true, false, msgId);
    this.totalGeneratedSamples = 0;
    this.ttsStartTimeMs = Date.now();
    this.store.setCanonicalState('SPEAKING');
    if (this.isLiveTalkActive) {
      this.store.setLiveTalkState('SPEAKING');
    }

    try {
      this.ttsController = await this.ttsEngine.generateSpeechStream(
        text,
        undefined,
        {
          onChunk: async (chunk) => {
            if (this.ttsEngine && this._isSpeaking) {
              this.totalGeneratedSamples += chunk.samples.length;
              await this.ttsEngine.writePcmChunk(chunk.samples);
            }
          },
          onEnd: async () => {
            if (this.ttsEngine) {
               try {
                 const { sampleRate } = await this.ttsEngine.getModelInfo();
                 const totalDurationMs = (this.totalGeneratedSamples / sampleRate) * 1000;
                 const elapsedMs = Date.now() - this.ttsStartTimeMs;
                 const remainingTimeMs = totalDurationMs - elapsedMs;

                 if (remainingTimeMs > 0 && this._isSpeaking) {
                   setTimeout(() => {
                     if (this._isSpeaking) this.onTtsFinished();
                   }, remainingTimeMs);
                 } else {
                   this.onTtsFinished();
                 }
               } catch (e) {
                 this.onTtsFinished();
               }
            } else {
              this.onTtsFinished();
            }
          },
          onError: (err) => {
            console.error('[VoiceEngine] TTS stream error', err);
            this.onTtsFinished();
          },
        },
      );
    } catch (e) {
      console.error('[VoiceEngine] Failed to start TTS', e);
      this.onTtsFinished();
      throw e;
    }
  }

  /**
   * Called when TTS finishes (either onEnd or onError).
   * Handles the live-talk loop: after speaking, restart STT automatically.
   */
  private onTtsFinished(): void {
    this._isSpeaking = false;
    this.ttsController = null;

    this.store.setTtsState(false, false, null);
    this.store.setCanonicalState('IDLE');

    // Live-talk loop: automatically restart listening after speaking
    if (this.isLiveTalkActive) {
      this.store.setLiveTalkState('IDLE');
      // Small delay to let audio system release, then restart STT
      setTimeout(() => {
        if (this.isLiveTalkActive) {
          this.startListening().catch((e) => {
            console.warn('[VoiceEngine] Failed to restart STT after TTS in live talk', e);
          });
        }
      }, 200);
    }
  }

  /**
   * Stop TTS playback immediately.
   */
  async stopTTS(): Promise<void> {
    if (!this._isSpeaking && !this.ttsController) return;

    this._isSpeaking = false;

    try {
      if (this.ttsController) {
        await this.ttsController.cancel();
        this.ttsController = null;
      }
    } catch (e) {
      console.warn('[VoiceEngine] Error stopping TTS', e);
      this.ttsController = null;
    }

    this.store.setTtsState(false, false, null);
    this.store.setCanonicalState('IDLE');
    if (this.isLiveTalkActive) {
      this.store.setLiveTalkState('IDLE');
    }
  }

  // ======================= lifecycle ========================

  /** Whether STT is currently active. */
  get isListening(): boolean {
    return this._isListening;
  }

  /** Whether TTS is currently playing. */
  get isSpeaking(): boolean {
    return this._isSpeaking;
  }

  /**
   * Destroy all engines and release native resources.
   * Call when switching models or unmounting.
   */
  async destroy(): Promise<void> {
    await this.stopListening();
    await this.stopTTS();

    if (this.ttsEngine) {
      try {
        await this.ttsEngine.stopPcmPlayer();
        await this.ttsEngine.destroy();
      } catch (e) {
        console.warn('[VoiceEngine] Error destroying TTS engine', e);
      }
      this.ttsEngine = null;
    }

    if (this.sttEngine) {
      try {
        await this.sttEngine.destroy();
      } catch (e) {
        console.warn('[VoiceEngine] Error destroying STT engine', e);
      }
      this.sttEngine = null;
    }
  }
}

export const VoiceEngine = new VoiceEngineManager();
