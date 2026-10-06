package expo.modules.kritha

import android.content.Context
import expo.modules.kritha.runtime.ModelDownloader
import java.io.Closeable
import java.io.File

/**
 * Catalog + on-disk store for speech artifacts (VAD, STT) used by Live Talk.
 * TTS artifacts remain owned by [TtsModuleBridge]; this bridge covers the
 * input side of the conversation pipeline.
 */
class SpeechModelBridge(
    context: Context,
) : Closeable {

    enum class Kind(val wire: String) {
        VAD("vad"),
        STT("stt"),
    }

    data class Artifact(val path: String, val remoteUrl: String)

    data class SpeechModelSpec(
        val id: String,
        val kind: Kind,
        val displayName: String,
        val displaySize: String,
        val languages: String,
        val backend: String,
        val directoryName: String,
        val artifacts: List<Artifact>,
    )

    private val modelsRoot: File = File(context.filesDir, "models/speech").apply { mkdirs() }

    companion object {
        const val VAD_MODEL_ID = "silero-vad"
        const val DEFAULT_STT_MODEL_ID = "whisper-tiny-en-onnx"

        // Artifact URLs verified against the upstream repos.
        private val specs = listOf(
            SpeechModelSpec(
                id = VAD_MODEL_ID,
                kind = Kind.VAD,
                displayName = "Silero VAD (ONNX)",
                displaySize = "2.3 MB",
                languages = "multilingual",
                backend = "ONNX",
                directoryName = "silero-vad-v5",
                artifacts = listOf(
                    Artifact(
                        path = "silero_vad.onnx",
                        // Versioned directory so stale revisions are never picked up.
                        remoteUrl = "https://github.com/snakers4/silero-vad/raw/v5.1.2/src/silero_vad/data/silero_vad.onnx",
                    ),
                ),
            ),
            SpeechModelSpec(
                id = DEFAULT_STT_MODEL_ID,
                kind = Kind.STT,
                displayName = "Whisper Tiny EN (ONNX)",
                displaySize = "45 MB",
                languages = "en",
                backend = "ONNX",
                directoryName = "whisper-tiny-en-onnx",
                artifacts = listOf(
                    Artifact(
                        path = "encoder.onnx",
                        remoteUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-encoder.int8.onnx",
                    ),
                    Artifact(
                        path = "decoder.onnx",
                        remoteUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-decoder.int8.onnx",
                    ),
                    Artifact(
                        path = "tokens.txt",
                        remoteUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-tokens.txt",
                    ),
                ),
            ),
        )
    }

    fun sttCatalog(): List<Map<String, Any?>> =
        specs.filter { it.kind == Kind.STT }.map { spec ->
            mapOf(
                "id" to spec.id,
                "name" to spec.displayName,
                "size" to spec.displaySize,
                "langs" to spec.languages,
                "category" to spec.kind.wire,
                "backend" to spec.backend,
                "isDownloaded" to isDownloaded(spec.id),
            )
        }

    fun isSpeechModel(modelId: String): Boolean = findSpec(modelId) != null

    fun isDownloaded(modelId: String): Boolean {
        val spec = findSpec(modelId) ?: return false
        if (!specComplete(spec)) return false
        return spec.kind != Kind.STT || isDownloaded(VAD_MODEL_ID)
    }

    /** True when both the STT model and the shared VAD model are present. */
    fun isLiveTalkInputReady(sttModelId: String): Boolean =
        isDownloaded(VAD_MODEL_ID) && isDownloaded(sttModelId)

    fun vadModelFile(): File {
        val spec = findSpec(VAD_MODEL_ID)!!
        val file = File(modelDirFor(spec), spec.artifacts.first().path)
        if (!file.isFile) {
            throw SpeechModelMissingException(VAD_MODEL_ID)
        }
        return file
    }

    fun sttModelDirectory(sttModelId: String): File {
        val spec = findSpec(sttModelId) ?: throw SpeechModelMissingException(sttModelId)
        if (!specComplete(spec)) throw SpeechModelMissingException(sttModelId)
        return modelDirFor(spec)
    }

    /**
     * Downloads a catalog model. Downloading any STT model also fetches the
     * shared VAD artifact, since Live Talk cannot run without it.
     *
     * [onProgress] receives a percent in 0..100. Note that [downloadSpec]
     * reports percent (0..100), not a 0..1 fraction: the VAD sub-download
     * occupies the first [VAD_PROGRESS_SHARE] percent of the total and the
     * model's own artifacts occupy the remainder.
     */
    fun download(modelId: String, onProgress: (Float) -> Unit): File {
        val spec = findSpec(modelId) ?: error("Unknown speech model: $modelId")
        val baseShare = if (spec.kind == Kind.STT) VAD_PROGRESS_SHARE else 0f
        if (spec.kind == Kind.STT) {
            downloadSpec(findSpec(VAD_MODEL_ID)!!) { percent ->
                onProgress((percent * VAD_PROGRESS_SHARE / 100f).coerceIn(0f, 100f))
            }
        }
        val dir = downloadSpec(spec) { percent ->
            val scaled = baseShare + (percent / 100f) * (100f - baseShare)
            onProgress(scaled.coerceIn(0f, 100f))
        }
        onProgress(100f)
        return dir
    }

    fun delete(modelId: String): Boolean {
        val spec = findSpec(modelId) ?: return false
        val dir = modelDirFor(spec)
        return if (dir.exists()) dir.deleteRecursively() else false
    }

    private fun downloadSpec(spec: SpeechModelSpec, onProgress: (Float) -> Unit): File {
        val targetDir = modelDirFor(spec)
        if (specComplete(spec)) return targetDir
        if (targetDir.exists() && !specComplete(spec)) {
            targetDir.deleteRecursively()
        }
        if (!targetDir.mkdirs()) {
            error("Failed to create speech model directory: ${targetDir.absolutePath}")
        }

        val total = spec.artifacts.size
        var completed = 0f
        var lastReported = -1f
        fun report(progress: Float) {
            val clamped = progress.coerceIn(0f, 100f)
            if (clamped >= 100f || clamped - lastReported >= 0.5f) {
                lastReported = clamped
                onProgress(clamped)
            }
        }

        for (artifact in spec.artifacts) {
            val finalFile = File(targetDir, artifact.path)
            if (finalFile.isFile && finalFile.length() > 0L) {
                completed += 1f
                report(completed / total * 100f)
                continue
            }
            val part = File(targetDir, "${artifact.path}.part")
            ModelDownloader.download(artifact.remoteUrl, part) { fraction ->
                report((completed + fraction) / total * 100f)
            }
            if (!part.renameTo(finalFile)) {
                part.copyTo(finalFile, overwrite = true)
                part.delete()
            }
            completed += 1f
            report(completed / total * 100f)
        }

        require(specComplete(spec)) {
            "Download completed but some artifacts are missing for ${spec.id}"
        }
        return targetDir
    }

    private fun specComplete(spec: SpeechModelSpec): Boolean {
        val dir = modelDirFor(spec)
        return spec.artifacts.all { artifact ->
            val f = File(dir, artifact.path)
            f.isFile && f.length() > 0L
        }
    }

    private fun modelDirFor(spec: SpeechModelSpec): File = File(modelsRoot, spec.directoryName)

    private fun findSpec(modelId: String): SpeechModelSpec? =
        specs.firstOrNull { it.id == modelId }

    override fun close() {
    }
}

class SpeechModelMissingException(modelId: String) :
    IllegalStateException("Speech model '$modelId' is not downloaded")

private const val VAD_PROGRESS_SHARE = 5f
