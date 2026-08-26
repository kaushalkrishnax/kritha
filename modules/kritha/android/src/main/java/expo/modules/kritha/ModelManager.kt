package expo.modules.kritha

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import kotlin.coroutines.coroutineContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

data class ModelInfo(
    val id: String,
    val name: String,
    val provider: String,
    val remoteUrl: String,
    val localPath: String,
)

object ModelCatalog {
    val MODELS = listOf(
        ModelInfo(
            id = "gemini-flash-lite-latest",
            name = "Gemini Flash (Cloud)",
            provider = "Google Cloud",
            remoteUrl = "",
            localPath = ""
        ),
        ModelInfo(
            id = "gemma-4-E2B-it",
            name = "Gemma 4 E2B",
            provider = "Hugging Face",
            remoteUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm",
            localPath = "gemma-4-E2B-it.litertlm"
        ),
        ModelInfo(
            id = "gemma-4-E4B-it",
            name = "Gemma 4 E4B",
            provider = "Hugging Face",
            remoteUrl = "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm",
            localPath = "gemma-4-E4B-it.litertlm"
        ),
        ModelInfo(
            id = "Qwen3-1.7B",
            name = "Qwen 3 1.7B",
            provider = "Hugging Face",
            remoteUrl = "https://huggingface.co/litert-community/Qwen3-1.7B/resolve/main/Qwen3_1.7B.litertlm",
            localPath = "Qwen3_1.7B.litertlm"
        ),
        ModelInfo(
            id = "Qwen3-4B-Thinking-2507",
            name = "Qwen 3 4B Thinking 2507",
            provider = "Hugging Face",
            remoteUrl = "https://huggingface.co/litert-community/Qwen3-4B-Thinking-2507/resolve/main/model.litertlm",
            localPath = "Qwen3-4B-Thinking-2507.litertlm"
        ),
    )

    fun getModel(id: String): ModelInfo? {
        return MODELS.find { it.id.equals(id, ignoreCase = true) }
    }

    fun isCloudModel(id: String): Boolean {
        return id.equals("gemini-flash-lite-latest", ignoreCase = true)
    }
}

data class DownloadProgress(
    val modelId: String,
    val downloadedMb: Int,
    val totalMb: Int,
    val percentComplete: Float,
    val speedMbps: Double,
    val eta: Long
)

class ModelDownloadManager(private val context: Context) {
    private val downloadsDir = File(context.filesDir, "models").apply { mkdirs() }
    private val activeDownloads = ConcurrentHashMap<String, Job>()
    private val pausedDownloads = ConcurrentHashMap<String, Boolean>()

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun downloadModel(
        modelId: String,
        onProgress: (downloadedMb: Int, totalMb: Int, speedMbps: Double) -> Unit
    ) {
        val modelInfo = ModelCatalog.getModel(modelId) ?: run {
            Log.e(TAG, "Model $modelId not found in catalog")
            return
        }

        val targetFile = File(downloadsDir, modelInfo.localPath)
        if (targetFile.exists() && targetFile.length() > 0) {
            Log.i(TAG, "Model $modelId is already downloaded at ${targetFile.absolutePath}")
            val sizeMb = (targetFile.length() / (1024 * 1024)).toInt()
            onProgress(sizeMb, sizeMb, 0.0)
            return
        }

        if (activeDownloads[modelId]?.isActive == true) {
            Log.i(TAG, "Download for model $modelId is already in progress")
            return
        }

        val tempFile = File(downloadsDir, "${modelInfo.localPath}.tmp")
        pausedDownloads[modelId] = false

        val job = scope.launch {
            try {
                performDownload(modelId, modelInfo.remoteUrl, targetFile, tempFile, onProgress)
            } catch (e: CancellationException) {
                Log.i(TAG, "Download for $modelId was cancelled")
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Error downloading model $modelId", e)
            } finally {
                activeDownloads.remove(modelId)
                pausedDownloads.remove(modelId)
            }
        }

        activeDownloads[modelId] = job
    }

    private suspend fun performDownload(
        modelId: String,
        remoteUrl: String,
        targetFile: File,
        tempFile: File,
        onProgress: (downloadedMb: Int, totalMb: Int, speedMbps: Double) -> Unit
    ) {
        var existingBytes = if (tempFile.exists()) tempFile.length() else 0L
        var currentUrl = remoteUrl
        var connection: HttpURLConnection? = null
        var redirects = 0
        val maxRedirects = 10

        while (redirects < maxRedirects) {
            val url = URL(currentUrl)
            connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Kritha-App)")
                if (existingBytes > 0) {
                    setRequestProperty("Range", "bytes=$existingBytes-")
                }
            }

            val code = connection.responseCode
            if (code == HttpURLConnection.HTTP_MOVED_PERM ||
                code == HttpURLConnection.HTTP_MOVED_TEMP ||
                code == HttpURLConnection.HTTP_SEE_OTHER ||
                code == 307 || code == 308
            ) {

                val location = connection.getHeaderField("Location")
                connection.disconnect()
                if (location.isNull_orEmpty()) break
                currentUrl = location
                redirects++
            } else {
                break
            }
        }

        val conn = connection ?: throw IllegalStateException("Failed to establish connection")
        val responseCode = conn.responseCode

        if (responseCode !in 200..299) {
            conn.disconnect()
            throw IllegalStateException("HTTP error code: $responseCode")
        }

        val isPartial = (responseCode == HttpURLConnection.HTTP_PARTIAL)
        if (!isPartial) {
            existingBytes = 0L
        }

        val contentLength = conn.contentLengthLong
        val totalBytes = if (contentLength > 0) {
            if (isPartial) contentLength + existingBytes else contentLength
        } else {
            -1L
        }

        val totalMb = if (totalBytes > 0) (totalBytes / (1024 * 1024)).toInt() else -1

        var input: InputStream? = null
        var output: FileOutputStream? = null

        try {
            input = conn.inputStream
            output = FileOutputStream(tempFile, isPartial)

            val buffer = ByteArray(64 * 1024)
            var bytesDownloaded = existingBytes
            var bytesSinceLastProgress = 0L
            var lastProgressTime = System.currentTimeMillis()

            while (coroutineContext.isActive) {
                if (pausedDownloads[modelId] == true) {
                    delay(500)
                    lastProgressTime = System.currentTimeMillis()
                    bytesSinceLastProgress = 0L
                    continue
                }

                val bytesRead = input.read(buffer)
                if (bytesRead == -1) break

                output.write(buffer, 0, bytesRead)
                bytesDownloaded += bytesRead
                bytesSinceLastProgress += bytesRead

                val now = System.currentTimeMillis()
                val elapsedSinceLastMs = now - lastProgressTime
                if (elapsedSinceLastMs >= 400) {
                    val speedMBps = (bytesSinceLastProgress / (1024.0 * 1024.0)) / (elapsedSinceLastMs / 1000.0)
                    val downloadedMb = (bytesDownloaded / (1024 * 1024)).toInt()

                    withContext(Dispatchers.Main) {
                        onProgress(downloadedMb, totalMb, speedMBps)
                    }
                    lastProgressTime = now
                    bytesSinceLastProgress = 0L
                }
            }

            output.flush()

            if (coroutineContext.isActive) {
                if (tempFile.renameTo(targetFile)) {
                    Log.i(TAG, "Successfully downloaded model $modelId to ${targetFile.absolutePath}")
                    val finalMb = (targetFile.length() / (1024 * 1024)).toInt()
                    withContext(Dispatchers.Main) {
                        onProgress(finalMb, finalMb, 0.0)
                    }
                } else {
                    Log.e(TAG, "Failed to rename temp file to target file")
                }
            }
        } finally {
            output?.runCatching { close() }
            input?.runCatching { close() }
            conn.disconnect()
        }
    }

    fun pauseDownload(modelId: String) {
        pausedDownloads[modelId] = true
        Log.i(TAG, "Paused download for model $modelId")
    }

    fun resumeDownload(modelId: String) {
        pausedDownloads[modelId] = false
        Log.i(TAG, "Resumed download for model $modelId")
    }

    fun cancelDownload(modelId: String) {
        activeDownloads[modelId]?.cancel()
        activeDownloads.remove(modelId)
        pausedDownloads.remove(modelId)
        val model = ModelCatalog.getModel(modelId)
        if (model != null) {
            val tempFile = File(downloadsDir, "${model.localPath}.tmp")
            if (tempFile.exists()) {
                tempFile.delete()
            }
        }
        Log.i(TAG, "Cancelled download for model $modelId")
    }

    fun isModelDownloaded(modelId: String): Boolean {
        if (ModelCatalog.isCloudModel(modelId)) return true
        val model = ModelCatalog.getModel(modelId) ?: return false
        val targetFile = File(downloadsDir, model.localPath)
        return targetFile.exists() && targetFile.length() > 0
    }

    fun getDownloadedModels(): List<String> {
        return ModelCatalog.MODELS.filter { isModelDownloaded(it.id) }.map { it.id }
    }

    fun getLocalModelPath(modelId: String): File? {
        val model = ModelCatalog.getModel(modelId) ?: return null
        val file = File(downloadsDir, model.localPath)
        return if (file.exists() && file.length() > 0) file else null
    }

    private fun String?.isNull_orEmpty(): Boolean = this == null || this.trim().isEmpty()

    companion object {
        private const val TAG = "ModelDownloadManager"
    }
}

object ModelManager {

    private const val PREFS = "kritha_models"
    private const val KEY_SELECTED = "selected_model"
    private const val DEFAULT_MODEL = "gemma-4-E2B-it"

    @Volatile
    private var downloadManager: ModelDownloadManager? = null

    @Synchronized
    fun getDownloadManager(context: Context): ModelDownloadManager {
        return downloadManager ?: ModelDownloadManager(context.applicationContext).also {
            downloadManager = it
        }
    }

    fun getAllModels(): List<ModelInfo> = ModelCatalog.MODELS

    fun getModelInfo(modelId: String): ModelInfo? = ModelCatalog.getModel(modelId)

    fun getSelectedModel(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SELECTED, DEFAULT_MODEL) ?: DEFAULT_MODEL

    fun setSelectedModel(context: Context, modelId: String) {
        require(getDownloadManager(context).isModelDownloaded(modelId)) {
            "Cannot select '$modelId' — model is not downloaded"
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_SELECTED, modelId).apply()
    }

    fun isModelDownloaded(context: Context, modelId: String): Boolean =
        getDownloadManager(context).isModelDownloaded(modelId)

    fun getDownloadedModels(context: Context): List<String> =
        getDownloadManager(context).getDownloadedModels()

    fun getModelFilePath(context: Context, modelId: String): File? =
        getDownloadManager(context).getLocalModelPath(modelId)
}
