package expo.modules.kritha.onnx

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.OnnxRuntimeProviderRegistration
import expo.modules.kritha.runtime.asr.AsrProvider
import expo.modules.kritha.runtime.vad.VadProvider

class OnnxRuntimeProvider : OnnxRuntimeProviderRegistration {
    override val id: RuntimeId = RuntimeId.ONNX

    override fun isAvailable(): Boolean = true

    override fun initialize(context: android.content.Context) {
    }

    override fun vad(): VadProvider = SileroVad()

    override fun asr(): AsrProvider = MoonshineAsr()
}
