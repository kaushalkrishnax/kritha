package expo.modules.kritha

import android.content.Context
import android.net.Uri
import expo.modules.kritha.litert.LiteRT
import expo.modules.kritha.litert.LiteRTApi
import expo.modules.kritha.litert.LiteRTModelDescriptor
import expo.modules.kritha.litert.LiteRTTask
import expo.modules.kritha.litert.speech.tts.SpeechAudio
import expo.modules.kritha.litert.speech.tts.SynthesisOptions
import expo.modules.kritha.litert.speech.tts.TtsFileAssets
import expo.modules.kritha.litert.speech.tts.TtsModelId
import expo.modules.kritha.litert.speech.tts.TtsModelSpec
import expo.modules.kritha.litert.speech.tts.adapters.TtsAdapterRegistry
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Expo-module-facing bridge over the generic LiteRT facade. Talks to JS through
 * [expo.modules.kritha.KrithaModule] and owns the LiteRT runtime lifecycle.
 * Model knowledge lives in the adapter providers ([TtsAdapterRegistry]); this
 * bridge only consumes generic [TtsModelSpec] metadata for catalog, download,
 * completeness, and synthesis routing.
 */
class LiteRTModuleBridge(
    private val context: Context,
) : Closeable {
    private val stack = LiteRT(context)
    private val ttsLock = Any()

    /** Root directory for on-device speech models. */
    val ttsModelsRoot: File = File(context.filesDir, "models").apply { mkdirs() }

    /** Last TTS model id selected by JS (mirrors `voice.store.selectedTtsModelId`). */
    @Volatile
    private var selectedTtsModelId: String? = null

    fun setTtsModelSelection(modelId: String?) {
        selectedTtsModelId = modelId
    }

    data class ActiveTts(
        val modelId: String,
        val directory: File,
    )

    fun ttsCatalog(): List<Map<String, Any?>> = TtsAdapterRegistry.allSpecs().map { spec ->
        mapOf(
            "id" to spec.id.value,
            "name" to spec.displayName,
            "size" to (spec.displaySize ?: "Unknown"),
            "langs" to spec.languages
                .sorted()
                .joinToString(", ") { it.replaceFirstChar(Char::uppercase) },
            "category" to "tts",
            "backend" to "LiteRT",
            "isDownloaded" to isSpecDownloaded(spec),
        )
    }

    fun defaultTtsModelId(): String = TtsAdapterRegistry.allSpecs().first().id.value

    /** Whether [modelId] (spec id or JS alias) refers to a registered TTS model. */
    fun isTtsModel(modelId: String): Boolean = findSpec(modelId) != null

    /** Prefer the JS-selected model, falling back to any downloaded one. */
    fun resolveActiveTts(): ActiveTts? {
        val fallbacks = buildList {
            selectedTtsModelId
                ?.takeIf { it.isNotBlank() }
                ?.let { findSpec(it) }
                ?.let { add(modelDirFor(it)) }
            addAll(TtsAdapterRegistry.allSpecs().map { modelDirFor(it) })
            // Pre-registry on-device layout; checked last.
            add(File(ttsModelsRoot, "qwen3-tts-0.6b-base"))
        }.filter { it.isDirectory }

        for (dir in fallbacks.distinct()) {
            specForDir(dir)?.let { return ActiveTts(it.id.value, dir) }
        }
        return null
    }

    fun info(): Map<String, Any> = mapOf(
        "version" to LiteRTApi.VERSION,
        "tasks" to listOf(
            LiteRTApi.TASK_TEXT_TO_TEXT,
            LiteRTApi.TASK_SPEECH_TO_TEXT,
            LiteRTApi.TASK_ASR,
            LiteRTApi.TASK_TEXT_TO_SPEECH,
            LiteRTApi.TASK_TTS,
        ),
        "devices" to listOf(
            LiteRTApi.DEVICE_CPU,
            LiteRTApi.DEVICE_GPU,
            LiteRTApi.DEVICE_NPU,
        ),
    )

    fun inspectModel(
        id: String,
        path: String,
        task: String,
        signature: String,
        inputNames: List<String>,
        outputNames: List<String>,
        outputTypes: List<String>,
    ): Map<String, Any?> {
        val descriptor = LiteRTModelDescriptor(
            id = id,
            path = path,
            task = parseTask(task),
            signature = signature,
            metadata = mapOf(
                "inputs" to inputNames.joinToString(","),
                "outputs" to outputNames.joinToString(","),
                "outputTypes" to outputTypes.joinToString(","),
            ),
        )

        val info = stack.loadModel(descriptor).inspect()
        return mapOf(
            "path" to info.path,
            "signatures" to info.signatures.map { signatureInfo ->
                mapOf(
                    "name" to signatureInfo.name,
                    "inputs" to signatureInfo.inputs.map(::tensorInfo),
                    "outputs" to signatureInfo.outputs.map(::tensorInfo),
                )
            },
        )
    }

    /** Raw audio synthesis. Voice names are resolved by the model's provider. */
    fun synthesizeTtsPcm(
        modelId: String,
        modelDirectory: String,
        text: String,
        voice: String? = null,
        speed: Float = 1f,
        language: String = "english",
        greedy: Boolean = true,
        seed: Long? = null,
    ): SpeechAudio {
        require(text.isNotBlank()) { "text cannot be blank" }
        require(modelDirectory.isNotBlank()) { "modelDirectory cannot be blank" }

        val root = File(modelDirectory).canonicalFile
        require(root.isDirectory) {
            "TTS model directory does not exist: ${root.absolutePath}"
        }

        synchronized(ttsLock) {
            val spec = findSpec(modelId) ?: error("No TTS adapter registered for model: $modelId")
            val provider = TtsAdapterRegistry.providerFor(spec.id)
            val assets = TtsFileAssets(spec.id, root)
            val result = stack.synthesizeTts(
                model = assets,
                text = text,
                options = SynthesisOptions(
                    voice = provider.voiceIndex(voice),
                    speed = speed,
                    language = language,
                    greedy = greedy,
                    seed = seed,
                ),
            )
            return result.audio
        }
    }

    /**
     * File-producing synthesis for the JS `liteRtTtsSynthesize` entry point.
     * Named-voice proxies accept string voices via [synthesizeTtsPcm].
     */
    fun synthesizeTts(
        modelId: String,
        modelDirectory: String,
        text: String,
        language: String,
        voice: Int,
        speed: Float,
        greedy: Boolean,
        seed: Long?,
    ): Map<String, Any?> {
        require(modelDirectory.isNotBlank()) { "modelDirectory cannot be blank" }

        synchronized(ttsLock) {
            val start = System.nanoTime()
            val synthStart = System.nanoTime()
            val audio = synthesizeTtsPcm(
                modelId = modelId,
                modelDirectory = modelDirectory,
                text = text,
                voice = voice.toString(),
                speed = speed,
                language = language,
                greedy = greedy,
                seed = seed,
            )
            val elapsedMs = (System.nanoTime() - synthStart) / 1_000_000
            val spec = findSpec(modelId) ?: error("No TTS adapter registered for model: $modelId")

            val wavFile = writeWav(
                pcm = audio.pcm,
                sampleRate = audio.sampleRate,
                channels = audio.channels,
            )

            return mapOf(
                "modelId" to spec.id.value,
                "sampleRate" to audio.sampleRate,
                "channels" to audio.channels,
                "samples" to audio.pcm.size,
                "durationMs" to (
                    audio.pcm.size.toLong() * 1000L /
                        audio.sampleRate /
                        audio.channels.coerceAtLeast(1)
                    ),
                "elapsedMs" to elapsedMs,
                "bridgeElapsedMs" to ((System.nanoTime() - start) / 1_000_000),
                "wavPath" to wavFile.absolutePath,
                "wavUri" to Uri.fromFile(wavFile).toString(),
            )
        }
    }

    fun releaseTts(modelId: String) {
        synchronized(ttsLock) {
            findSpec(modelId)?.let {
                runCatching { stack.releaseTts(it.id) }
            }
        }
    }

    fun releaseActiveTts() {
        synchronized(ttsLock) {
            resolveActiveTts()?.let {
                runCatching { stack.releaseTts(TtsModelId(it.modelId)) }
            }
        }
    }

    /** Encode float PCM into signed 16-bit little-endian bytes for playback. */
    fun encodePcm16(pcm: FloatArray): ByteArray {
        val out = ByteArray(pcm.size * 2)
        for (i in pcm.indices) {
            val scaled = (pcm[i].coerceIn(-1f, 1f) * 32767f).toInt()
            out[i * 2] = (scaled and 0xFF).toByte()
            out[i * 2 + 1] = ((scaled ushr 8) and 0xFF).toByte()
        }
        return out
    }

    fun ttsModelDirectory(): String? = resolveActiveTts()?.directory?.absolutePath

    fun isTtsModelDownloaded(): Boolean =
        TtsAdapterRegistry.allSpecs().any { isSpecDownloaded(it) }

    /**
     * Delete the downloaded TTS model matching [modelId]. Without a match all
     * downloaded TTS model directories are removed.
     */
    fun deleteTtsModel(modelId: String? = null): Boolean {
        val spec = modelId?.let { findSpec(it) }
        var found = false
        for (dir in candidateModelDirs()) {
            if (!dir.isDirectory) continue
            if (spec != null && specForDir(dir)?.id != spec.id) continue
            dir.deleteRecursively()
            found = true
        }
        return found
    }

    /**
     * Download a registered TTS model into the app's private files directory.
     * Reports progress as a percentage (0..100). Downloads are resumable: an
     * interrupted transfer keeps the partial file and continues from the last byte.
     */
    fun downloadTtsModel(modelId: String, onProgress: (Float) -> Unit): File {
        val spec = findSpec(modelId) ?: error("No TTS adapter registered for model: $modelId")
        val targetDir = modelDirFor(spec).apply { mkdirs() }
        require(targetDir.isDirectory) {
            "Cannot create model directory: ${targetDir.absolutePath}"
        }

        downloadMissingArtifacts(spec, targetDir, onProgress)
        TtsAdapterRegistry.providerFor(spec.id).finishDownload(targetDir)

        val assets = TtsFileAssets(spec.id, targetDir)
        require(spec.isComplete(assets)) {
            "TTS model download finished but the model is incomplete at ${targetDir.absolutePath}"
        }
        return targetDir
    }

    /** Download every artifact with a remote URL that is missing locally. */
    private fun downloadMissingArtifacts(
        spec: TtsModelSpec,
        targetDir: File,
        onProgress: (Float) -> Unit,
    ) {
        val assets = TtsFileAssets(spec.id, targetDir)
        val remote = spec.artifacts.filter { it.remoteUrl != null }
        val totalFiles = remote.size
        require(totalFiles > 0) { "Model ${spec.id.value} declares no downloadable artifacts" }
        var completed = 0f
        var lastReported = -1f
        fun report(progress: Float) {
            val clamped = progress.coerceIn(0f, 100f)
            if (clamped >= 100f || clamped - lastReported >= 0.5f) {
                lastReported = clamped
                onProgress(clamped)
            }
        }

        for (artifact in remote) {
            val present = assets.exists(artifact.path) ||
                artifact.alternatives.any { assets.exists(it) }
            if (present) {
                val finalFile = File(targetDir, artifact.path)
                if (finalFile.isFile && finalFile.length() > 0L) {
                    completed += 1f
                    report(completed / totalFiles * 100f)
                    continue
                }
            }

            val part = File(targetDir, "${artifact.path}.part")
            downloadFile(artifact.remoteUrl!!, part) { fraction ->
                report((completed + fraction) / totalFiles * 100f)
            }
            val finalFile = File(targetDir, artifact.path)
            if (!part.renameTo(finalFile)) {
                part.copyTo(finalFile, overwrite = true)
                part.delete()
            }
            completed += 1f
            report(completed / totalFiles * 100f)
        }
    }

    /** Exact id match first, then a short-alias match. */
    private fun findSpec(modelId: String): TtsModelSpec? {
        val specs = TtsAdapterRegistry.allSpecs()
        specs.firstOrNull { it.id.value == modelId }?.let { return it }
        val wanted = modelId.lowercase()
        // JS aliases such as "qwen3-tts" predate the full registry ids.
        return specs.firstOrNull { wanted.contains(it.id.value.substringBefore("-")) }
    }

    private fun modelDirFor(spec: TtsModelSpec): File = File(ttsModelsRoot, spec.directoryName)

    private fun candidateModelDirs(): List<File> =
        TtsAdapterRegistry.allSpecs().map { modelDirFor(it) } +
            File(ttsModelsRoot, "qwen3-tts-0.6b-base")

    private fun specForDir(dir: File): TtsModelSpec? {
        if (!dir.isDirectory) return null
        return TtsAdapterRegistry.allSpecs().firstOrNull { spec ->
            runCatching { spec.isComplete(TtsFileAssets(spec.id, dir)) }.getOrDefault(false)
        }
    }

    private fun isSpecDownloaded(spec: TtsModelSpec): Boolean =
        candidateModelDirs().any { dir ->
            dir.isDirectory &&
                runCatching { spec.isComplete(TtsFileAssets(spec.id, dir)) }.getOrDefault(false)
        }

    override fun close() {
        stack.close()
    }

    private fun downloadFile(
        url: String,
        destination: File,
        onFileProgress: (Float) -> Unit,
    ) {
        var connection: HttpURLConnection? = null
        try {
            var existing = destination.length()
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setInstanceFollowRedirects(true)
                setRequestProperty("User-Agent", "kritha/1.0 (LiteRT TTS bridge)")
                if (existing > 0L) {
                    setRequestProperty("Range", "bytes=$existing-")
                }
            }

            when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> if (existing > 0L) {
                    // Server ignored the Range header; restart the file.
                    destination.delete()
                    existing = 0L
                }
                HttpURLConnection.HTTP_PARTIAL -> Unit
                else -> throw IOException(
                    "HTTP ${connection.responseCode} while downloading ${destination.name}"
                )
            }

            val totalBytes = connection.contentLength.let {
                if (it > 0L) it + existing else -1L
            }
            var downloaded = existing
            val buffer = ByteArray(DOWNLOAD_BUFFER_BYTES)

            val input = connection.inputStream
                ?: throw IOException("No response body for ${destination.name}")
            input.use { stream ->
                FileOutputStream(destination, existing > 0L).use { output ->
                    while (true) {
                        val read = stream.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        downloaded += read
                        if (totalBytes > 0L) {
                            onFileProgress(downloaded.toFloat() / totalBytes)
                        }
                    }
                }
            }
        } finally {
            connection?.disconnect()
        }
    }

    private fun tensorInfo(info: expo.modules.kritha.litert.LiteRTTensorInfo): Map<String, Any?> =
        mapOf(
            "name" to info.name,
            "type" to info.type,
            "shape" to info.shape,
            "strides" to info.strides,
            "signature" to info.signature,
        )

    private fun parseTask(value: String): LiteRTTask = when (value.lowercase()) {
        "text-to-text", "text_to_text" -> LiteRTTask.TEXT_TO_TEXT
        "speech-to-text", "speech_to_text" -> LiteRTTask.SPEECH_TO_TEXT
        "asr" -> LiteRTTask.ASR
        "text-to-speech", "text_to_speech" -> LiteRTTask.TEXT_TO_SPEECH
        "tts" -> LiteRTTask.TTS
        else -> error("Unsupported LiteRT task: $value")
    }

    private fun writeWav(
        pcm: FloatArray,
        sampleRate: Int,
        channels: Int,
    ): File {
        val safeChannels = channels.coerceAtLeast(1)
        val outputDir = File(context.cacheDir, "litert-tts").apply { mkdirs() }
        val file = File(outputDir, "tts_${System.currentTimeMillis()}.wav")
        val bytesPerSample = 2
        val dataSize = pcm.size * bytesPerSample
        val byteRate = sampleRate * safeChannels * bytesPerSample
        val blockAlign = safeChannels * bytesPerSample

        FileOutputStream(file).use { out ->
            writeAscii(out, "RIFF")
            writeIntLE(out, 36 + dataSize)
            writeAscii(out, "WAVE")
            writeAscii(out, "fmt ")
            writeIntLE(out, 16)
            writeShortLE(out, 1) // PCM
            writeShortLE(out, safeChannels)
            writeIntLE(out, sampleRate)
            writeIntLE(out, byteRate)
            writeShortLE(out, blockAlign)
            writeShortLE(out, 16)
            writeAscii(out, "data")
            writeIntLE(out, dataSize)

            val sample = ByteArray(2)
            for (value in pcm) {
                val scaled = (value.coerceIn(-1f, 1f) * 32767f).toInt()
                sample[0] = (scaled and 0xFF).toByte()
                sample[1] = ((scaled ushr 8) and 0xFF).toByte()
                out.write(sample)
            }
        }

        return file
    }

    private fun writeAscii(out: FileOutputStream, value: String) {
        out.write(value.toByteArray(Charsets.US_ASCII))
    }

    private fun writeShortLE(out: FileOutputStream, value: Int) {
        out.write(value and 0xFF)
        out.write((value ushr 8) and 0xFF)
    }

    private fun writeIntLE(out: FileOutputStream, value: Int) {
        out.write(value and 0xFF)
        out.write((value ushr 8) and 0xFF)
        out.write((value ushr 16) and 0xFF)
        out.write((value ushr 24) and 0xFF)
    }

    private companion object {
        const val CONNECT_TIMEOUT_MS = 30_000
        const val READ_TIMEOUT_MS = 60_000
        const val DOWNLOAD_BUFFER_BYTES = 64 * 1024
    }
}
