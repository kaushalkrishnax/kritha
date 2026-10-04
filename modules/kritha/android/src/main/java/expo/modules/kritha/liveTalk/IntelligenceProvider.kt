package expo.modules.kritha.liveTalk

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.RuntimeManager
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean

data class IntelligenceMessage(
    val role: String,
    val content: String,
)

data class IntelligenceConfig(
    /** "local" or "cloud" — decided by JS, never by this layer. */
    val kind: String,
    val modelId: String,
    val modelPath: String? = null,
    val device: String = "cpu",
    val apiKey: String? = null,
)

/**
 * Blocking, cancellable text generation (spec §8). The conversation loop
 * treats local and cloud providers identically.
 */
interface IntelligenceProvider {
    /**
     * Blocking generation. Emits [onDelta] per streamed chunk and returns the
     * full text. Throws [CancellationException] when cancelled via [cancel].
     */
    fun generate(
        requestId: String,
        messages: List<IntelligenceMessage>,
        onDelta: (String) -> Unit,
    ): String

    fun cancel(requestId: String)

    fun close()
}

object IntelligenceProviders {
    fun create(config: IntelligenceConfig, runtimeManager: RuntimeManager): IntelligenceProvider =
        when (config.kind) {
            "local" -> LocalIntelligenceProvider(config, runtimeManager)
            "cloud" -> CloudIntelligenceProvider(config)
            else -> throw LiveTalkException(
                LiveTalkException.ERR_INTELLIGENCE,
                "Unknown intelligence kind: ${config.kind}",
            )
        }
}

/** Local generation through the installed LiteRT-LM runtime provider. */
private class LocalIntelligenceProvider(
    private val config: IntelligenceConfig,
    private val runtimeManager: RuntimeManager,
) : IntelligenceProvider {

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val jobs = ConcurrentHashMap<String, Job>()

    override fun generate(
        requestId: String,
        messages: List<IntelligenceMessage>,
        onDelta: (String) -> Unit,
    ): String {
        val modelPath = config.modelPath
        if (modelPath.isNullOrEmpty()) {
            throw LiveTalkException(
                LiveTalkException.ERR_MODEL_MISSING,
                "Local model '${config.modelId}' is not downloaded",
            )
        }
        val llm = runtimeManager.provider(RuntimeId.LITERT_LM)?.llm()
            ?: throw LiveTalkException(
                LiveTalkException.ERR_RUNTIME_MISSING,
                "LiteRT-LM runtime is not installed",
            )

        val request = mapOf<String, Any?>(
            "requestId" to requestId,
            "modelPath" to modelPath,
            "device" to config.device,
            "messages" to messages.map { mapOf("role" to it.role, "content" to it.content) },
        )

        val latch = CountDownLatch(1)
        var result: String? = null
        var failure: Throwable? = null
        val job = scope.launch {
            try {
                result = llm.generate(request, onDelta = onDelta)
            } catch (t: Throwable) {
                if (t !is CancellationException) failure = t
            } finally {
                latch.countDown()
            }
        }
        jobs[requestId] = job
        try {
            latch.await()
        } finally {
            jobs.remove(requestId)
        }
        failure?.let { throw it }
        if (job.isCancelled) {
            throw CancellationException("Local generation cancelled")
        }
        return result ?: ""
    }

    override fun cancel(requestId: String) {
        jobs.remove(requestId)?.cancel()
    }

    override fun close() {
        jobs.values.forEach { it.cancel() }
        jobs.clear()
    }
}

/** Cloud generation through Gemini's streaming (SSE) endpoint. */
private class CloudIntelligenceProvider(
    private val config: IntelligenceConfig,
) : IntelligenceProvider {

    private val activeCalls = ConcurrentHashMap<String, ActiveCall>()

    private class ActiveCall {
        val cancelled = AtomicBoolean(false)

        @Volatile
        var connection: HttpURLConnection? = null

        fun cancel() {
            cancelled.set(true)
            runCatching { connection?.disconnect() }
        }
    }

    override fun generate(
        requestId: String,
        messages: List<IntelligenceMessage>,
        onDelta: (String) -> Unit,
    ): String {
        val apiKey = config.apiKey
        if (apiKey.isNullOrEmpty()) {
            throw LiveTalkException(
                LiveTalkException.ERR_INTELLIGENCE,
                "Cloud intelligence requires an API key",
            )
        }
        val call = ActiveCall()
        activeCalls[requestId] = call
        try {
            return stream(requestId, messages, apiKey, call, onDelta)
        } finally {
            activeCalls.remove(requestId)
            call.connection = null
        }
    }

    private fun stream(
        requestId: String,
        messages: List<IntelligenceMessage>,
        apiKey: String,
        call: ActiveCall,
        onDelta: (String) -> Unit,
    ): String {
        val url = URL(
            "https://generativelanguage.googleapis.com/v1beta/models/" +
                "${config.modelId}:streamGenerateContent?alt=sse&key=$apiKey",
        )
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 60_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }
        call.connection = connection

        OutputStreamWriter(connection.outputStream).use { writer ->
            writer.write(buildRequestBody(messages))
            writer.flush()
        }

        if (call.cancelled.get()) throw CancellationException("Cloud generation cancelled")

        val status = connection.responseCode
        if (status != HttpURLConnection.HTTP_OK) {
            val body = runCatching {
                connection.errorStream?.bufferedReader()?.readText()
            }.getOrNull().orEmpty()
            throw LiveTalkException(
                LiveTalkException.ERR_INTELLIGENCE,
                "Cloud request failed (HTTP $status): ${body.take(300)}",
            )
        }

        val fullText = StringBuilder()
        val reader = BufferedReader(InputStreamReader(connection.inputStream))
        reader.use { stream ->
            while (true) {
                if (call.cancelled.get()) {
                    throw CancellationException("Cloud generation cancelled")
                }
                val line = stream.readLine() ?: break
                if (!line.startsWith("data:")) continue
                val payload = line.removePrefix("data:").trim()
                if (payload.isEmpty() || payload == "[DONE]") continue
                val delta = extractDelta(payload) ?: continue
                fullText.append(delta)
                onDelta(delta)
            }
        }
        return fullText.toString()
    }

    private fun buildRequestBody(messages: List<IntelligenceMessage>): String {
        val root = JSONObject()
        val systemText = messages
            .filter { it.role == "system" }
            .joinToString("\n") { it.content }
            .trim()
        if (systemText.isNotEmpty()) {
            root.put(
                "systemInstruction",
                JSONObject().put(
                    "parts",
                    JSONArray().put(JSONObject().put("text", systemText)),
                ),
            )
        }
        val contents = JSONArray()
        for (message in messages) {
            if (message.role == "system") continue
            val role = if (message.role == "assistant") "model" else "user"
            contents.put(
                JSONObject()
                    .put("role", role)
                    .put("parts", JSONArray().put(JSONObject().put("text", message.content))),
            )
        }
        root.put("contents", contents)
        return root.toString()
    }

    private fun extractDelta(payload: String): String? {
        return try {
            val root = JSONObject(payload)
            val candidates = root.optJSONArray("candidates") ?: return null
            val content = candidates.optJSONObject(0)?.optJSONObject("content") ?: return null
            val parts = content.optJSONArray("parts") ?: return null
            val text = StringBuilder()
            for (i in 0 until parts.length()) {
                text.append(parts.optJSONObject(i)?.optString("text").orEmpty())
            }
            if (text.isEmpty()) null else text.toString()
        } catch (e: Exception) {
            null
        }
    }

    override fun cancel(requestId: String) {
        activeCalls.remove(requestId)?.cancel()
    }

    override fun close() {
        activeCalls.values.forEach { it.cancel() }
        activeCalls.clear()
    }
}
