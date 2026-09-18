package expo.modules.kritha.litert

import android.content.Context
import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.LiteRTRuntimeProviderRegistration
import expo.modules.kritha.runtime.tts.TtsProvider
import expo.modules.kritha.litert.speech.tts.Tts

class LiteRTRuntimeProvider : LiteRTRuntimeProviderRegistration {
    override val id: RuntimeId = RuntimeId.LITERT
    
    override fun isAvailable(): Boolean = true

    private var liteRtRuntime: LiteRTRuntime? = null
    private var ttsEngine: Tts? = null

    override fun initialize(context: Context) {
        if (liteRtRuntime == null) {
            liteRtRuntime = LiteRTRuntime(context)
            ttsEngine = Tts(liteRtRuntime!!)
        }
    }

    override fun tts(): TtsProvider? = ttsEngine

    override fun inspectModel(descriptor: Any): Map<String, Any?>? {
        val litertDescriptor = descriptor as expo.modules.kritha.litert.LiteRTModelDescriptor
        val info = liteRtRuntime?.load(litertDescriptor)?.inspect() ?: return null
        return mapOf(
            "path" to info.path,
            "signatures" to info.signatures.map { signatureInfo ->
                mapOf(
                    "name" to signatureInfo.name,
                    "inputs" to signatureInfo.inputs.map { tensorInfo(it) },
                    "outputs" to signatureInfo.outputs.map { tensorInfo(it) },
                )
            }
        )
    }

    private fun tensorInfo(info: expo.modules.kritha.litert.LiteRTTensorInfo): Map<String, Any?> =
        mapOf(
            "name" to info.name,
            "type" to info.type,
            "shape" to info.shape,
            "strides" to info.strides,
            "signature" to info.signature,
        )
}
