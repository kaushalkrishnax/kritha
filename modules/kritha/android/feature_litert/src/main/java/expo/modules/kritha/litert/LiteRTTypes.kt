package expo.modules.kritha.litert

import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel

enum class LiteRTTask {
    TEXT_TO_TEXT,
    SPEECH_TO_TEXT,
    ASR,
    TEXT_TO_SPEECH,
    TTS
}

enum class LiteRTDevice {
    CPU, GPU, NPU
}

data class LiteRTModelDescriptor(
    val id: String,
    val path: String,
    val task: LiteRTTask,
    val architecture: String? = null,
    val signature: String = "",
    val tokenizerPath: String? = null,
    val metadata: Map<String, String> = emptyMap()
)

data class LiteRTExecutionOptions(
    val device: LiteRTDevice = LiteRTDevice.CPU,
    val cpuThreads: Int? = null,
    val xnnpackFlags: Int? = null,
    val xnnpackWeightCachePath: String? = null,
    val gpuPrecision: LiteRTGpuPrecision = LiteRTGpuPrecision.DEFAULT,
    val gpuConstantTensorSharing: Boolean? = null,
    val gpuInfiniteFloatCapping: Boolean? = null,
    val gpuAllowSrcQuantizedFcConvOps: Boolean? = null,
    val gpuBufferStorageType: LiteRTGpuBufferStorage = LiteRTGpuBufferStorage.DEFAULT,
    val gpuPreferTextureWeights: Boolean? = null,
    val gpuSerializationDir: String? = null,
    val gpuModelCacheKey: String? = null,
    val gpuSerializeProgramCache: Boolean? = null,
    val gpuSerializeExternalTensors: Boolean? = null,
    val gpuExternalTensorsMode: Boolean? = null,
    val gpuExternalTensorPattern: String? = null,
    val gpuBackend: LiteRTGpuBackend = LiteRTGpuBackend.AUTOMATIC,
    val gpuPriority: LiteRTGpuPriority = LiteRTGpuPriority.DEFAULT,
    val gpuCommandBufferPreparationSteps: Int? = null,
    val npuHighPerformance: Boolean = false
)

enum class LiteRTGpuPrecision { DEFAULT, FP16, FP32, FP16_WITH_FP32_ACCUM }
enum class LiteRTGpuBufferStorage { DEFAULT, BUFFER, TEXTURE_2D }
enum class LiteRTGpuBackend { AUTOMATIC, OPENCL, OPENGL }
enum class LiteRTGpuPriority { DEFAULT, LOW, NORMAL, HIGH }

data class LiteRTTensorInfo(
    val name: String,
    val type: String,
    val shape: List<Int>,
    val strides: List<Int> = emptyList(),
    val signature: String = ""
)

data class LiteRTSignatureInfo(
    val name: String,
    val inputs: List<LiteRTTensorInfo>,
    val outputs: List<LiteRTTensorInfo>
)

data class LiteRTModelInfo(
    val path: String,
    val signatures: List<LiteRTSignatureInfo>
)

data class LiteRTTensorInput(
    val name: String,
    val data: Any,
    val signature: String = ""
)

data class LiteRTTensorOutput(
    val name: String,
    val data: Any,
    val signature: String = ""
)

data class LiteRTRunResult(
    val outputs: List<LiteRTTensorOutput>,
    val elapsedMs: Long
)

internal fun LiteRTExecutionOptions.toCompiledOptions(): CompiledModel.Options {
    val accelerator = when (device) {
        LiteRTDevice.CPU -> Accelerator.CPU
        LiteRTDevice.GPU -> Accelerator.GPU
        LiteRTDevice.NPU -> Accelerator.NPU
    }
    val options = CompiledModel.Options(Accelerator.CPU, accelerator)
    cpuThreads?.let {
        options.cpuOptions = CompiledModel.CpuOptions(
            numThreads = it,
            xnnPackFlags = xnnpackFlags,
            xnnPackWeightCachePath = xnnpackWeightCachePath
        )
    }
    options.gpuOptions = CompiledModel.GpuOptions(
        constantTensorSharing = gpuConstantTensorSharing,
        infiniteFloatCapping = gpuInfiniteFloatCapping,
        allowSrcQuantizedFcConvOps = gpuAllowSrcQuantizedFcConvOps,
        precision = when (gpuPrecision) {
            LiteRTGpuPrecision.DEFAULT -> CompiledModel.GpuOptions.Precision.DEFAULT
            LiteRTGpuPrecision.FP16 -> CompiledModel.GpuOptions.Precision.FP16
            LiteRTGpuPrecision.FP32 -> CompiledModel.GpuOptions.Precision.FP32
            LiteRTGpuPrecision.FP16_WITH_FP32_ACCUM -> CompiledModel.GpuOptions.Precision.FP16_WITH_FP32_ACCUM
        },
        bufferStorageType = when (gpuBufferStorageType) {
            LiteRTGpuBufferStorage.DEFAULT -> CompiledModel.GpuOptions.BufferStorageType.DEFAULT
            LiteRTGpuBufferStorage.BUFFER -> CompiledModel.GpuOptions.BufferStorageType.BUFFER
            LiteRTGpuBufferStorage.TEXTURE_2D -> CompiledModel.GpuOptions.BufferStorageType.TEXTURE_2D
        },
        preferTextureWeights = gpuPreferTextureWeights,
        serializationDir = gpuSerializationDir,
        modelCacheKey = gpuModelCacheKey,
        serializeProgramCache = gpuSerializeProgramCache,
        serializeExternalTensors = gpuSerializeExternalTensors,
        externalTensorsMode = gpuExternalTensorsMode,
        externalTensorPattern = gpuExternalTensorPattern,
        backend = when (gpuBackend) {
            LiteRTGpuBackend.AUTOMATIC -> CompiledModel.GpuOptions.Backend.AUTOMATIC
            LiteRTGpuBackend.OPENCL -> CompiledModel.GpuOptions.Backend.OPENCL
            LiteRTGpuBackend.OPENGL -> CompiledModel.GpuOptions.Backend.OPENGL
        },
        priority = when (gpuPriority) {
            LiteRTGpuPriority.DEFAULT -> CompiledModel.GpuOptions.Priority.DEFAULT
            LiteRTGpuPriority.LOW -> CompiledModel.GpuOptions.Priority.LOW
            LiteRTGpuPriority.NORMAL -> CompiledModel.GpuOptions.Priority.NORMAL
            LiteRTGpuPriority.HIGH -> CompiledModel.GpuOptions.Priority.HIGH
        },
        numStepsOfCommandBufferPreparations = gpuCommandBufferPreparationSteps
    )
    return options
}
