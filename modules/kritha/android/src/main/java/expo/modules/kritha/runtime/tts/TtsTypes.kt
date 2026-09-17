package expo.modules.kritha.runtime.tts

import java.io.File

data class SpeechAudio(
    val pcm: FloatArray,
    val sampleRate: Int,
    val channels: Int = 1,
)

data class SynthesisOptions(
    val voice: Int = 0,
    val speed: Float = 1f,
    val language: String = "english",
    val greedy: Boolean = false,
    val seed: Long? = null,
)

data class SynthesisResult(
    val audio: SpeechAudio,
    val elapsedMs: Long,
)

data class TtsModelId(val value: String)

data class TtsArtifact(
    val name: String,
    val path: String = name,
    val alternatives: List<String> = emptyList(),
    val remoteUrl: String? = null,
    val sizeBytes: Long? = null,
    val sha256: String? = null,
    val required: Boolean = true,
)

data class TtsModelSpec(
    val id: TtsModelId,
    val displayName: String,
    val version: String,
    val languages: Set<String> = emptySet(),
    val sampleRate: Int = 24_000,
    val displaySize: String? = null,
    /**
     * On-device directory name under the models root. Defaults to the model
     * id; Qwen overrides it because its JS-facing id predates the longer
     * upstream directory name already on devices.
     */
    val directoryName: String = id.value,
    val artifacts: List<TtsArtifact> = emptyList(),
) {
    val totalSizeBytes: Long?
        get() {
            var total = 0L
            for (artifact in artifacts) {
                if (!artifact.required) continue
                total += artifact.sizeBytes ?: return null
            }
            return total
        }

    fun isComplete(assets: TtsModelAssets): Boolean = missing(assets).isEmpty()

    fun missing(assets: TtsModelAssets): List<TtsArtifact> =
        artifacts.filter { it.required && !isPresent(assets, it) }

    private fun isPresent(assets: TtsModelAssets, artifact: TtsArtifact): Boolean {
        if (assets.exists(artifact.path)) return true
        return artifact.alternatives.any { assets.exists(it) }
    }
}

/**
 * Storage abstraction supplied by the model manager; the adapter never owns
 * model installation/deletion policy.
 */
interface TtsModelAssets {
    val modelId: TtsModelId
    fun file(name: String): File
    fun exists(name: String): Boolean
}

interface TtsAdapter : AutoCloseable {
    fun synthesize(
        text: String,
        options: SynthesisOptions = SynthesisOptions(),
    ): SynthesisResult

    override fun close()
}
