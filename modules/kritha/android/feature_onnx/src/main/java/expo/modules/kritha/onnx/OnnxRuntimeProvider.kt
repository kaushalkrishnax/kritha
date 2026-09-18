package expo.modules.kritha.onnx

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.OnnxRuntimeProviderRegistration

class OnnxRuntimeProvider : OnnxRuntimeProviderRegistration {
    override val id: RuntimeId = RuntimeId.ONNX
    
    override fun isAvailable(): Boolean = true

    override fun initialize(context: android.content.Context) {
        // Scaffolded
    }
}
