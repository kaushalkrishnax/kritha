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

        val loaded = LoadedModel(descriptor, compiled, environment)
        val existing = models.putIfAbsent(descriptor.id, loaded)
        if (existing != null) {
            loaded.closeInternal()
            return existing
        }
        return loaded
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

        val loaded = LoadedModel(descriptor, compiled, environment)
        val existing = models.putIfAbsent(descriptor.id, loaded)
        if (existing != null) {
            loaded.closeInternal()
            return existing
        }
        return loaded
    }

    fun unload(id: String) {
        models.remove(id)?.closeInternal()
    }

    fun unloadAll() {
        models.values.forEach { runCatching { it.closeInternal() } }
        models.clear()
    }

    override fun close() = unloadAll()

    inner class LoadedModel internal constructor(
        val descriptor: LiteRTModelDescriptor,
        private val model: CompiledModel,
        private val environment: Environment
    ) : Closeable {

        fun session(
            signature: String,
            inputNames: List<String> = emptyList(),
            outputNames: List<String> = emptyList()
        ): LiteRTSession {
            require(signature.isNotBlank()) { "Session signature cannot be blank" }
            if (inputNames.isNotEmpty()) {
                require(inputNames.distinct().size == inputNames.size) { "Duplicate input names" }
            }
            if (outputNames.isNotEmpty()) {
                require(outputNames.distinct().size == outputNames.size) { "Duplicate output names" }
            }
            return LiteRTSession(model, signature)
        }

        fun positionalSession(): LiteRTSession = LiteRTSession(model, null)

        fun inspect(): LiteRTModelInfo {
            val signature = descriptor.signature
            require(signature.isNotBlank()) { "Descriptor signature is required for inspect()" }
            val inputNames = modelInputNames(signature)
            val outputNames = modelOutputNames(signature)

            return LiteRTModelInfo(
                path = descriptor.path,
                signatures = listOf(
                    LiteRTSignatureInfo(
                        name = signature,
                        inputs = inputNames.map { tensorInfo(it, true, signature) },
                        outputs = outputNames.map { tensorInfo(it, false, signature) }
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
            try {
                require(inputs.size == inputBuffers.size) {
                    "Expected ${inputBuffers.size} inputs, got ${inputs.size}"
                }
                inputs.forEachIndexed { index, input -> write(inputBuffers[index], input.data) }

                val elapsed = measureTimeMillis { model.run(inputBuffers, outputBuffers, signature) }
                val outputNames = modelOutputNames(signature)
                val outputTypes = descriptor.metadata["outputTypes"]
                    ?.split(',')?.map { it.trim() }
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
                return LiteRTRunResult(outputs, elapsed)
            } finally {
                inputBuffers.forEach { runCatching { it.close() } }
                outputBuffers.forEach { runCatching { it.close() } }
            }
        }

        fun runNamed(
            inputs: Map<String, Any>,
            signature: String = descriptor.signature
        ): LiteRTRunResult {
            val inputBuffers = model.createInputBuffers(signature)
            val outputBuffers = model.createOutputBuffers(signature)
            try {
                val names = modelInputNames(signature)
                require(names.size == inputBuffers.size) { "LiteRT signature input count mismatch" }
                names.forEachIndexed { index, name ->
                    val value = inputs[name] ?: error("Missing LiteRT input '$name'")
                    write(inputBuffers[index], value)
                }

                val elapsed = measureTimeMillis { model.run(inputBuffers, outputBuffers, signature) }
                val outputNames = modelOutputNames(signature)
                val outputTypes = descriptor.metadata["outputTypes"]
                    ?.split(',')?.map { it.trim() }
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
                return LiteRTRunResult(outputs, elapsed)
            } finally {
                inputBuffers.forEach { runCatching { it.close() } }
                outputBuffers.forEach { runCatching { it.close() } }
            }
        }

        private fun modelInputNames(signature: String): List<String> = discoverTensorNames(signature, true)
        private fun modelOutputNames(signature: String): List<String> = discoverTensorNames(signature, false)

        private fun discoverTensorNames(signature: String, input: Boolean): List<String> {
            val metadataNames = if (input) {
                descriptor.metadata["inputs"]?.split(',')?.map { it.trim() }
            } else {
                descriptor.metadata["outputs"]?.split(',')?.map { it.trim() }
            }
            return metadataNames?.filter { it.isNotEmpty() }
                ?: run {
                    val kind = if (input) "inputs" else "outputs"
                    error("Model '${descriptor.id}' needs explicit $kind metadata")
                }
        }

        private fun tensorInfo(name: String, input: Boolean, signature: String): LiteRTTensorInfo {
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

        private fun readTyped(buffer: TensorBuffer, type: String): Any = when (type.uppercase()) {
            "FLOAT" -> buffer.readFloat()
            "INT" -> buffer.readInt()
            "INT8" -> buffer.readInt8()
            "INT64" -> buffer.readLong()
            "BOOLEAN" -> buffer.readBoolean()
            else -> error("Unsupported LiteRT output type: $type")
        }

        internal fun closeInternal() {
            models.remove(descriptor.id, this)
            runCatching { model.close() }
            runCatching { environment.close() }
        }

        override fun close() = closeInternal()
    }
}
