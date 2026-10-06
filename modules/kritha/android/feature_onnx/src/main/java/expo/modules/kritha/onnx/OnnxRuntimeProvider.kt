package expo.modules.kritha.onnx

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.OnnxRuntimeProviderRegistration
import expo.modules.kritha.runtime.asr.AsrProvider
import expo.modules.kritha.runtime.vad.VadProvider
import expo.modules.kritha.runtime.tts.TtsProvider

class OnnxRuntimeProvider : OnnxRuntimeProviderRegistration {
    override val id: RuntimeId = RuntimeId.ONNX

    override fun isAvailable(): Boolean = true

    override fun initialize(context: android.content.Context) {
    }

    private val ttsProvider by lazy { SherpaTtsProvider() }

    /**
     * VAD and ASR instances are cheap wrappers around native handles: return
     * a fresh instance per call so every consumer (dictation, Live Talk) owns
     * its loaded state. A shared instance would let one consumer's
     * release() unload the model under another consumer's feet, which
     * previously broke dictation right after a Live Talk session.
     */
    override fun vad(): VadProvider = SileroVad()

    override fun asr(): AsrProvider = SherpaAsr()

    /**
     * TTS keeps a single shared instance on purpose: the provider caches the
     * loaded model internally and heals itself by reloading on demand, so
     * sharing avoids re-loading the model for every utterance.
     */
    override fun tts(): TtsProvider = ttsProvider
}
