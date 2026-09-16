package expo.modules.kritha.litert

import android.content.Context
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.Environment
import com.google.ai.edge.litert.TensorBuffer
import com.google.ai.edge.litert.TensorType
import java.io.Closeable
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.system.measureTimeMillis

/**
 * Small, task-agnostic LiteRT runtime.
 *
 * The class deliberately does not try to infer model semantics from tensor names.
 * It exposes LiteRT's real signature/tensor contract and lets task adapters own
 * preprocessing, decoding and postprocessing.
 */
class LiteRTRuntime(private val context: Context) : Closeable {
    private val models = ConcurrentHashMap<String, LoadedModel>()

    fun load(
        descriptor: LiteRTModelDescriptor,
        options: LiteRTExecutionOptions = LiteRTExecutionOptions()
    ): LoadedModel {
        models[descriptor.id]?.let { return it }

        val file = File(descriptor.path)
        require(file.isFile) { "LiteRT model not found: ${file.absolutePath}" }

        val environment = Environment.create()
        val compiled = try {
            CompiledModel.create(
                file.absolutePath,
                options.toCompiledOptions(),
                environment
            )
        } catch (t: Throwable) {
            environment.close()
            throw t
        }

        return LoadedModel(descriptor, compiled).also {
            models[descriptor.id] = it
        }
    }

    fun loadAsset(
        descriptor: LiteRTModelDescriptor,
        assetPath: String,
        options: LiteRTExecutionOptions = LiteRTExecutionOptions()
    ): LoadedModel {
        models[descriptor.id]?.let { return it }
        val environment = Environment.create()
        val compiled = try {
            CompiledModel.create(
                context.assets,
                assetPath,
                options.toCompiledOptions(),
                environment
            )
        } catch (t: Throwable) {
            environment.close()
            throw t
        }
        return LoadedModel(descriptor, compiled).also {
            models[descriptor.id] = it
        }
    }

    fun get(id: String): LoadedModel =
        models[id] ?: error("LiteRT model is not loaded: $id")

    fun unload(id: String) {
        models.remove(id)?.close()
    }

    fun unloadAll() {
        models.values.forEach { runCatching { it.close() } }
        models.clear()
    }

    override fun close() = unloadAll()

    inner class LoadedModel internal constructor(
        val descriptor: LiteRTModelDescriptor,
        private val model: CompiledModel
    ) : Closeable {

        fun inspect(): LiteRTModelInfo {
            val signature = descriptor.signature
            val inputNames = modelInputNames(signature)
            val outputNames = modelOutputNames(signature)

            return LiteRTModelInfo(
                path = descriptor.path,
                signatures = listOf(
                    LiteRTSignatureInfo(
                        name = signature,
                        inputs = inputNames.map {
                            tensorInfo(it, true, signature)
                        },
                        outputs = outputNames.map {
                            tensorInfo(it, false, signature)
                        }
                    )
                )
            )
        }

        fun run(
            inputs: List<LiteRTTensorInput>,
            signature: String = descriptor.signature
        ): LiteRTRunResult {
            val inputBuffers = model.createInputBuffers(signature)
            val outputBuffers = model.createOutputBuffers(signature)

            require(inputs.size == inputBuffers.size) {
                "Expected ${inputBuffers.size} inputs, got ${inputs.size}"
            }

            inputs.forEachIndexed { index, input ->
                write(inputBuffers[index], input.data)
            }

            var elapsed = 0L
            elapsed = measureTimeMillis {
                model.run(inputBuffers, outputBuffers, signature)
            }

            val outputNames = modelOutputNames(signature)
            val outputTypes = descriptor.metadata["outputTypes"]
                ?.split(',')
                ?.map { it.trim() }
                ?: error("Model '${descriptor.id}' needs outputTypes metadata")
            require(outputTypes.size == outputBuffers.size) {
                "outputTypes count ${outputTypes.size} does not match ${outputBuffers.size} outputs"
            }
            val outputs = outputBuffers.mapIndexed { index, buffer ->
                LiteRTTensorOutput(
                    name = outputNames.getOrNull(index) ?: "output_$index",
                    data = readTyped(buffer, outputTypes[index]),
                    signature = signature
                )
            }

            inputBuffers.forEach { runCatching { it.close() } }
            outputBuffers.forEach { runCatching { it.close() } }

            return LiteRTRunResult(outputs, elapsed)
        }

        fun runNamed(
            inputs: Map<String, Any>,
            signature: String = descriptor.signature
        ): LiteRTRunResult {
            val inputBuffers = model.createInputBuffers(signature)
            val outputBuffers = model.createOutputBuffers(signature)
            val names = modelInputNames(signature)

            require(names.size == inputBuffers.size) {
                "LiteRT signature input count mismatch"
            }

            names.forEachIndexed { index, name ->
                val value = inputs[name]
                    ?: error("Missing LiteRT input '$name'")
                write(inputBuffers[index], value)
            }

            val elapsed = measureTimeMillis {
                model.run(inputBuffers, outputBuffers, signature)
            }

            val outputNames = modelOutputNames(signature)
            val outputTypes = descriptor.metadata["outputTypes"]
                ?.split(',')
                ?.map { it.trim() }
                ?: error("Model '${descriptor.id}' needs outputTypes metadata")
            require(outputTypes.size == outputBuffers.size) {
                "outputTypes count ${outputTypes.size} does not match ${outputBuffers.size} outputs"
            }
            val outputs = outputBuffers.mapIndexed { index, buffer ->
                LiteRTTensorOutput(
                    outputNames.getOrNull(index) ?: "output_$index",
                    readTyped(buffer, outputTypes[index]),
                    signature
                )
            }

            inputBuffers.forEach { runCatching { it.close() } }
            outputBuffers.forEach { runCatching { it.close() } }

            return LiteRTRunResult(outputs, elapsed)
        }

        private fun modelInputNames(signature: String): List<String> =
            discoverTensorNames(signature, true)

        private fun modelOutputNames(signature: String): List<String> =
            discoverTensorNames(signature, false)

        /*
         * CompiledModel exposes name-based buffer creation but not a public
         * get-all-names method in the current Kotlin API. The model descriptor
         * therefore supplies names for task adapters. For the generic path,
         * use the signature's conventional metadata when available.
         */
        private fun discoverTensorNames(signature: String, input: Boolean): List<String> {
            val metadataNames = if (input) {
                descriptor.metadata["inputs"]?.split(',')?.map { it.trim() }
            } else {
                descriptor.metadata["outputs"]?.split(',')?.map { it.trim() }
            }
            return metadataNames?.filter { it.isNotEmpty() }
                ?: error(
                    "Model '${descriptor.id}' needs explicit ${if (input) "inputs" else "outputs"} " +
                        "metadata. LiteRT does not expose arbitrary semantic tensor names through " +
                        "this API; use ModelDescriptor.metadata."
                )
        }

        private fun tensorInfo(
            name: String,
            input: Boolean,
            signature: String
        ): LiteRTTensorInfo {
            val type: TensorType = if (input) {
                model.getInputTensorType(name, signature)
            } else {
                model.getOutputTensorType(name, signature)
            }
            return LiteRTTensorInfo(
                name = name,
                type = type.elementType.name,
                shape = type.layout?.dimensions ?: emptyList(),
                strides = type.layout?.strides ?: emptyList(),
                signature = signature
            )
        }

        private fun write(buffer: TensorBuffer, data: Any) {
            when (data) {
                is FloatArray -> buffer.writeFloat(data)
                is IntArray -> buffer.writeInt(data)
                is LongArray -> buffer.writeLong(data)
                is ByteArray -> buffer.writeInt8(data)
                is BooleanArray -> buffer.writeBoolean(data)
                else -> error("Unsupported LiteRT tensor data type: ${data::class.java.name}")
            }
        }

        private fun readTyped(buffer: TensorBuffer, type: String): Any =
            when (type.uppercase()) {
                "FLOAT" -> buffer.readFloat()
                "INT" -> buffer.readInt()
                "INT8" -> buffer.readInt8()
                "INT64" -> buffer.readLong()
                "BOOLEAN" -> buffer.readBoolean()
                else -> error("Unsupported LiteRT output type: $type")
            }

        override fun close() {
            models.remove(descriptor.id, this)
            model.close()
        }
    }
}
