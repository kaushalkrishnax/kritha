package expo.modules.kritha

import android.content.Context
import android.net.Uri
import expo.modules.kritha.runtime.RuntimeManager
import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.tts.*
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class TtsModuleBridge(
    private val context: Context,
) : Closeable {
    private val runtimeManager = RuntimeManager(context)
    private val ttsLock = Any()

    val ttsModelsRoot: File = File(context.filesDir, "models/tts").apply { mkdirs() }

    data class ActiveTts(
        val modelId: String,
        val directory: File,
    )

    fun ttsCatalog(): List<Map<String, Any?>> = StaticTtsSpecs.allSpecs.map { spec ->
        mapOf(
            "id" to spec.id.value,
            "name" to spec.displayName,
            "size" to spec.displaySize,
            "languages" to spec.languages.joinToString(", ") { it.replaceFirstChar(Char::uppercase) },
            "category" to "tts",
            "backend" to "LiteRT",
            "isDownloaded" to isSpecDownloaded(spec),
        )
    }

    fun defaultTtsModelId(): String = StaticTtsSpecs.allSpecs.first().id.value

    fun isTtsModel(modelId: String): Boolean = findSpec(modelId) != null

    fun resolveActiveTts(): ActiveTts? {
        val fallbacks = buildList {
            addAll(StaticTtsSpecs.allSpecs.map { modelDirFor(it) })
            add(File(ttsModelsRoot, "qwen3-tts-0.6b-base"))
        }.filter { it.isDirectory }

        for (dir in fallbacks) {
            val spec = specForDir(dir)
            if (spec != null) {
                return ActiveTts(spec.id.value, dir)
            }
        }
        return null
    }

    fun info(): Map<String, Any> = mapOf(
        "ttsModelsRoot" to ttsModelsRoot.absolutePath,
        "isTtsDownloaded" to isTtsModelDownloaded(),
        "defaultTtsModelId" to defaultTtsModelId(),
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
        val descriptor = mapOf(
            "path" to path,
            "task" to task,
            "signature" to signature,
            "inputNames" to inputNames,
            "outputNames" to outputNames,
            "outputTypes" to outputTypes,
        )
        val provider = runtimeManager.provider(RuntimeId.LITERT) ?: throw IllegalStateException("LiteRT not installed")
        return provider.inspectModel(descriptor) ?: emptyMap()
    }

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
            val provider = runtimeManager.provider(RuntimeId.LITERT)?.tts() ?: throw IllegalStateException("TTS Runtime not installed")
            val result = provider.synthesize(
                model = TtsFileAssets(spec.id, root),
                text = text,
                options = SynthesisOptions(
                    voice = voice?.toIntOrNull() ?: 0,
                    speed = speed,
                    language = language,
                    greedy = greedy,
                    seed = seed,
                ),
            )
            return result.audio
        }
    }

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
                runCatching { runtimeManager.provider(RuntimeId.LITERT)?.tts()?.release(it.id) }
            }
        }
    }

    fun releaseActiveTts() {
        synchronized(ttsLock) {
            resolveActiveTts()?.let {
                runCatching { runtimeManager.provider(RuntimeId.LITERT)?.tts()?.release(TtsModelId(it.modelId)) }
            }
        }
    }

    fun encodePcm16(pcm: FloatArray): ByteArray {
        val bytes = ByteArray(pcm.size * 2)
        for (i in pcm.indices) {
            val scaled = (pcm[i].coerceIn(-1f, 1f) * 32767f).toInt()
            bytes[i * 2] = (scaled and 0xFF).toByte()
            bytes[i * 2 + 1] = ((scaled ushr 8) and 0xFF).toByte()
        }
        return bytes
    }

    fun ttsModelDirectory(): String? = resolveActiveTts()?.directory?.absolutePath

    fun isTtsModelDownloaded(): Boolean =
        StaticTtsSpecs.allSpecs.any { isSpecDownloaded(it) }

    fun deleteTtsModel(modelId: String? = null): Boolean {
        synchronized(ttsLock) {
            if (modelId != null) {
                val spec = findSpec(modelId) ?: return false
                val dir = modelDirFor(spec)
                return if (dir.exists()) dir.deleteRecursively() else false
            } else {
                return ttsModelsRoot.deleteRecursively().also { ttsModelsRoot.mkdirs() }
            }
        }
    }

    fun downloadTtsModel(modelId: String, onProgress: (Float) -> Unit): File {
        val spec = findSpec(modelId) ?: error("No TTS adapter registered for model: $modelId")
        val targetDir = modelDirFor(spec)
        
        if (targetDir.exists()) {
            if (spec.isComplete(TtsFileAssets(spec.id, targetDir))) {
                return targetDir
            }
            targetDir.deleteRecursively()
        }
        
        if (!targetDir.mkdirs()) {
            error("Failed to create TTS model directory: ${targetDir.absolutePath}")
        }

        downloadMissingArtifacts(spec, targetDir, onProgress)
        runtimeManager.provider(RuntimeId.LITERT)?.tts()?.finishDownload(targetDir, spec.id.value)

        val assets = TtsFileAssets(spec.id, targetDir)
        require(spec.isComplete(assets)) {
            "Download completed but some required artifacts are missing"
        }

        return targetDir
    }

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

    private fun findSpec(modelId: String): TtsModelSpec? {
        val specs = StaticTtsSpecs.allSpecs
        specs.firstOrNull { it.id.value == modelId }?.let { return it }
        val wanted = modelId.lowercase()
        return specs.firstOrNull { wanted.contains(it.id.value.substringBefore("-")) }
    }

    private fun modelDirFor(spec: TtsModelSpec): File = File(ttsModelsRoot, spec.directoryName)

    private fun candidateModelDirs(): List<File> =
        StaticTtsSpecs.allSpecs.map { modelDirFor(it) } +
            File(ttsModelsRoot, "qwen3-tts-0.6b-base")

    private fun specForDir(dir: File): TtsModelSpec? {
        if (!dir.isDirectory) return null
        return StaticTtsSpecs.allSpecs.firstOrNull { spec ->
            runCatching { spec.isComplete(TtsFileAssets(spec.id, dir)) }.getOrDefault(false)
        }
    }

    private fun isSpecDownloaded(spec: TtsModelSpec): Boolean =
        candidateModelDirs().any { dir ->
            dir.isDirectory &&
                runCatching { spec.isComplete(TtsFileAssets(spec.id, dir)) }.getOrDefault(false)
        }

    override fun close() {
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
                connectTimeout = 30_000
                readTimeout = 60_000
                setInstanceFollowRedirects(true)
                setRequestProperty("User-Agent", "kritha/1.0 (Kritha TTS bridge)")
                if (existing > 0L) {
                    setRequestProperty("Range", "bytes=$existing-")
                }
            }

            when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> if (existing > 0L) {
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
            val buffer = ByteArray(64 * 1024)

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
}
