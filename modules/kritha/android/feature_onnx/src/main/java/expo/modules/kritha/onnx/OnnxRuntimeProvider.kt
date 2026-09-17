package expo.modules.kritha.onnx

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.RuntimeProvider

class OnnxRuntimeProvider : RuntimeProvider {
    override val id: RuntimeId = RuntimeId.ONNX
    
    override fun isAvailable(): Boolean = true

    override fun initialize(context: android.content.Context) {
        // Scaffolded
    }
}
