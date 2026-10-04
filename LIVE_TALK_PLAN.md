# Live Talk — Implementation Plan (as built)

Real-time, interruptible voice conversation runtime for Android.

Status: **Phases 1–10 implemented**. Verified: `:kritha`, `:feature_onnx`, `:app`
Kotlin compile, `tsc --noEmit`, `expo lint`. Remaining: Phase 11 device/performance
testing and the follow-ups listed in §11.

Architecture decisions (approved): fully native loop, Moonshine-tiny ONNX ASR,
Silero VAD in `feature_onnx`.

---

## 1. Runtime Architecture (built)

```
AudioRecord (VOICE_COMMUNICATION, 16 kHz mono PCM16)
  → AudioProcessor (AndroidAudioProcessor | WebRtcAudioProcessor)
  → SileroVad (feature_onnx, 512-sample / 32 ms frames)
  → TurnDetector (rule-based, hysteresis)
  → MoonshineAsr (feature_onnx)
  → IntelligenceProvider (local LiteRT-LM | cloud Gemini SSE)
  → LiveTalkTtsManager (StreamingTextChunker in stream mode)
  → StreamingPcmPlayer (AudioTrack, low-latency)
```

The whole loop runs inside `liveTalk/LiveTalkSession.kt`. No PCM crosses the
RN bridge; JS receives only semantic events. Barge-in: VAD keeps running during
THINKING/SPEAKING/PROCESSING; `speech_start` cancels the LLM call, synthesis
job, chunk queue and flushes the AudioTrack in one step.

## 2. Native Files (base module `:kritha`)

| File | Responsibility |
|---|---|
| `liveTalk/LiveTalkSession.kt` | Session core: capture thread, state machine, turn pipeline, barge-in, audio focus, latency metrics, pre-roll |
| `liveTalk/LiveTalkState.kt` | State enum (`idle…paused`) + coded `LiveTalkException` |
| `liveTalk/LiveTalkConfig.kt` | VAD/turn thresholds (pre-existing) |
| `liveTalk/AudioProcessor.kt`, `AndroidAudioProcessor.kt`, `AecDetector.kt` | AEC/NS abstraction (pre-existing, now wired) |
| `liveTalk/WebRtcAudioProcessor.kt` | `STUB:` WebRTC APM, `loadLibrary("webrtc_apm")`-guarded, falls back with coded error |
| `liveTalk/TurnDetector.kt` | Rule-based turn detection (spec §6) |
| `liveTalk/IntelligenceProvider.kt` | Interface + `LocalIntelligenceProvider` (LiteRT-LM) + `CloudIntelligenceProvider` (Gemini `streamGenerateContent` SSE) |
| `liveTalk/LiveTalkTtsManager.kt` | TTS modes, `StreamingTextChunker`, hard interrupt |
| `runtime/vad/VadProvider.kt`, `runtime/asr/AsrProvider.kt` | Runtime capability interfaces (`RuntimeProvider.vad()/asr()`) |
| `runtime/ModelDownloader.kt` | Shared HTTP downloader (Range resume + progress) |
| `SpeechModelBridge.kt` | VAD/STT artifact catalog, download, on-disk store (`filesDir/models/speech`) |

`feature_onnx` (dynamic feature): `OnnxRuntimeProvider` (real), `SileroVad`,
`MoonshineAsr`, `com.microsoft.onnxruntime:onnxruntime-android:1.20.0`.

## 3. Session State Machine

Native-owned (`LiveTalkSession`), mirrored to JS via `state` events:

```
IDLE → LISTENING → USER_SPEAKING → PROCESSING → THINKING → SPEAKING → LISTENING
SPEAKING/THINKING/PROCESSING → (speech_start) → INTERRUPTED → USER_SPEAKING
```

`LiveTalkPhase` in `src/constants/canonicalStates.ts` carries the full set;
`assistantRuntime.service.ts` remains the only JS phase writer (RULES §4.1 +
§1.5 carve-out).

## 4. JS API (built)

`modules/kritha/src` exports `KrithaLiveTalk`:

```typescript
start(config: LiveTalkStartConfig): Promise<void>
stop(): Promise<void>
interrupt(): void
pause(): void
resume(): void
setContext(messages): void
isActive(): boolean
addListener((event: LiveTalkEvent) => void)
```

`LiveTalkStartConfig`: `{ intelligence: { kind, modelId, modelPath?, device?, apiKey? },
context: [{role, content}], tts: { enabled, mode, voice? }, sttModelId?, vad?: {...},
forceWebRtcAec? }`.

Events (single channel `onLiveTalkEvent`, typed payload): `session_started`
(aec backend, ttsMode), `session_stopped`, `state`, `speech_started/ended`,
`transcription_started/completed`, `thinking_started`, `assistant_text`,
`thinking_completed`, `tts_started/stopped`, `interrupted`, `audio_level`
(~10 Hz), `latency` (spec §18 metrics), `error` (coded).

`src/services/liveTalk.service.ts` owns the native subscription + imperative
handles; `assistantRuntime.service.ts` verbs (`startLiveTalk`, `stopLiveTalk`,
`pauseLiveTalk`, `resumeLiveTalk`, `interruptLiveTalk`) build config from
stores (model selection, API key, TTS mode, STT model), persist per-turn
messages, and re-sync native context after each completed turn.

## 5. Configuration

- TTS mode: `voice.store.liveTalkTtsMode` — `'disabled' | 'after_generation' | 'stream'`
  (persisted; single field, no contradictory flags). Default `'stream'`.
- STT model: `voice.store.selectedSttModelId` — default `'moonshine-tiny-onnx'`
  (replaces the Nemotron LiteRT stubs in `speechModels.ts` / native catalog).
- VAD thresholds: overridable per session via `vad` config; defaults in
  `LiveTalkConfig.kt` (0.5/0.35, ~700 ms silence, 30 s absolute timeout).

## 6. Model Packaging

| Component | Delivery |
|---|---|
| ONNX Runtime + Silero VAD + Moonshine ASR | `feature_onnx` dynamic feature (GloballyDynamic) |
| Silero VAD model | `SpeechModelBridge` artifact `silero-vad` (auto-downloaded with any STT model) |
| Moonshine Tiny | `SpeechModelBridge` artifact `moonshine-tiny-onnx` |
| TTS models | existing `TtsModuleBridge` downloads |
| LiteRT / LiteRT-LM | existing `feature_litert` / `feature_litertlm` |

`downloadVoiceModel` / `listVoiceModels` / `deleteVoiceModel` in
`KrithaModule.kt` now route STT ids to `SpeechModelBridge` (TTS unchanged).
Missing model → reject/event with code `MODEL_MISSING` → JS opens the voice
model modal; missing runtime → `RUNTIME_MISSING` error event.

## 7. Error Handling (coded)

`LiveTalkException` codes surfaced through `error` events / promise rejections:
`MIC_PERMISSION_DENIED`, `AUDIO_INIT_FAILED`, `AEC_UNAVAILABLE`,
`WEBRTC_INIT_FAILED`, `VAD_FAILURE`, `ASR_FAILURE`, `INTELLIGENCE_FAILURE`,
`MODEL_MISSING`, `RUNTIME_MISSING`, `AUDIO_FOCUS_LOST`. Every failure path
returns the session to `IDLE` and releases mic, focus, player and model
handles. Audio focus: permanent loss stops the session; transient loss
interrupts speech.

## 8. Latency Metrics (emitted as `latency` events)

- `speech_end_to_asr_ms`
- `asr_to_first_llm_ms`
- `first_llm_to_first_audio_ms`
- `interrupt_to_audio_stop_ms`

## 9. RULES.md Compliance

- §1.5 added: Live Talk native-loop exception (JS still owns session control,
  intelligence selection, canonical context, persistence; native owns turn
  timing + real-time audio and reports semantic events only).
- §9.1: the Live Talk JS-facing native contract is documented in
  `KrithaModule.kt` above the Live Talk functions.
- `WebRtcAudioProcessor` carries the required `// STUB:` marker (§10.1).

## 10. Performance Rules Honored

Mic opened once per session; no PCM over the bridge; growable utterance buffer
with pre-roll ring (no churn); one AEC pipeline; TTS engine released between
utterances (`releaseActiveTts`); inference on native threads/coroutines; audio
level events throttled to ~10 Hz.

## 11. Follow-ups (before/during Phase 11 device testing)

1. ~~Verify artifact URLs~~ Done: Silero from
   `snakers4/silero-vad/.../src/silero_vad/data/silero_vad.onnx`; Moonshine from
   `moonshine-ai/moonshine` `onnx/merged/tiny/quantized/` + CTranslate2
   `vocabulary.json` (JSON array indexed by token id; BOS=1/EOS=2 confirmed).
2. **Verify Moonshine decoder I/O names on-device** (`input_ids`,
   `encoder_hidden_states`, `past_key_values.*`/`present.*`,
   `use_cache_branch`) against the exported `decoder_model_merged.onnx`.
3. **WebRTC APM**: build `libwebrtc_apm` (far-end reference from the playback
   stream) and wire `WebRtcAudioProcessor`; selection logic already in place
   (`forceWebRtcAec` config + automatic fallback when hardware AEC is absent).
4. **Acceptance matrix** (spec §20): AEC on/off, WebRTC fallback, volume
   low/high, background noise, barge-in while TTS active — using the emitted
   latency metrics for the four key timings.
5. After feature changes, rebuild + redeploy dynamic features:
   `bun run gd:build && bun run gd:deploy`.

## 12. Session Lifecycle Integration

- **Wake word → Live Talk**: `SpeechCoordinator.handleWakeWordDetected` routes
  into `assistantRuntime.startLiveTalk()`; mic arbitration with the wake-word
  service happens natively (`pauseForStt`/`resumeFromStt` inside
  `KrithaModule.startLiveTalkSession`/`stopLiveTalkSession`).
- **App background**: the session has no foreground service, so
  `liveTalkService.enableBackgroundStop` stops it to a clean `IDLE` when the
  app backgrounds (spec §17) instead of dying mid-capture.
- **User control**: Settings → "Live Talk Speech" selects the TTS mode
  (`stream` / `after_generation` / `off`), persisted in
  `voice.store.liveTalkTtsMode`.
