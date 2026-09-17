package expo.modules.kritha.litert

import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.TensorBuffer
import java.io.Closeable

class LiteRTSession internal constructor(
    private val model: CompiledModel,
    private val signature: String?
) : Closeable {

    private var closed = false
    private fun checkOpen() {
        check(!closed) { "LiteRT session is closed" }
    }

    fun createInputBuffer(name: String): TensorBuffer {
        checkOpen()
        return if (signature.isNullOrBlank()) {
            error("Named input buffers require a signature")
        } else {
            model.createInputBuffer(name, signature)
        }
    }

    fun createOutputBuffer(name: String): TensorBuffer {
        checkOpen()
        return if (signature.isNullOrBlank()) {
            error("Named output buffers require a signature")
        } else {
            model.createOutputBuffer(name, signature)
        }
    }

    fun createInputBuffers(): List<TensorBuffer> {
        checkOpen()
        return if (signature.isNullOrBlank()) {
            model.createInputBuffers()
        } else {
            model.createInputBuffers(signature)
        }
    }

    fun createOutputBuffers(): List<TensorBuffer> {
        checkOpen()
        return if (signature.isNullOrBlank()) {
            model.createOutputBuffers()
        } else {
            model.createOutputBuffers(signature)
        }
    }

    fun run(
        inputs: List<TensorBuffer>,
        outputs: List<TensorBuffer>
    ) {
        checkOpen()
        if (signature.isNullOrBlank()) {
            model.run(inputs, outputs)
        } else {
            model.run(inputs, outputs, signature)
        }
    }

    fun runNamed(
        inputs: Map<String, TensorBuffer>,
        outputs: Map<String, TensorBuffer>,
        inputNames: List<String>,
        outputNames: List<String>
    ) {
        checkOpen()
        require(!signature.isNullOrBlank()) { "Named runs require a signature" }
        val orderedInputs = inputNames.map { inputs[it] ?: error("Missing input buffer '$it'") }
        val orderedOutputs = outputNames.map { outputs[it] ?: error("Missing output buffer '$it'") }
        model.run(orderedInputs, orderedOutputs, signature)
    }

    override fun close() {
        if (closed) return
        closed = true
    }
}
