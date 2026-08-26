package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

internal class L3CloudLLM(private val context: Context) {

    suspend fun infer(
        messages: List<ConversationMessage>,
        onChunk: suspend (String) -> Unit = {}
    ): String? = withContext(Dispatchers.IO) {
        isCancelled = false

        val apiKey = getApiKey()
        if (apiKey.isBlank()) {
            val fallbackMsg = "[Cloud LLM] Gemini API key missing. Please configure Gemini API Key."
            onChunk(fallbackMsg)
            return@withContext fallbackMsg
        }

        val endpointUrl =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:streamGenerateContent?alt=sse&key=$apiKey"
        val responseBuilder = StringBuilder()

        var connection: HttpURLConnection? = null
        try {
            val url = URL(endpointUrl)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            connection.doOutput = true
            connection.doInput = true
            connection.connectTimeout = 15000
            connection.readTimeout = 30000

            val requestBody = JSONObject().apply {
                val systemParts = JSONArray()
                val contentsArray = JSONArray()

                messages.forEach { msg ->
                    when (msg.role) {
                        Role.SYSTEM -> {
                            systemParts.put(JSONObject().apply { put("text", msg.content) })
                        }

                        Role.USER -> {
                            contentsArray.put(JSONObject().apply {
                                put("role", "user")
                                put("parts", JSONArray().apply { put(JSONObject().apply { put("text", msg.content) }) })
                            })
                        }

                        Role.ASSISTANT -> {
                            contentsArray.put(JSONObject().apply {
                                put("role", "model")
                                put("parts", JSONArray().apply { put(JSONObject().apply { put("text", msg.content) }) })
                            })
                        }
                    }
                }

                if (systemParts.length() > 0) {
                    put("system_instruction", JSONObject().apply { put("parts", systemParts) })
                }

                put("contents", contentsArray)
            }

            OutputStreamWriter(connection.outputStream, "UTF-8").use { writer ->
                writer.write(requestBody.toString())
                writer.flush()
            }

            val statusCode = connection.responseCode
            if (statusCode !in 200..299) {
                val errorStream = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "Cloud API returned HTTP $statusCode: $errorStream")
                val errorMsg = "Cloud LLM request failed (HTTP $statusCode)."
                onChunk(errorMsg)
                return@withContext errorMsg
            }

            BufferedReader(InputStreamReader(connection.inputStream, "UTF-8")).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (isCancelled || !currentCoroutineContext().isActive) {
                        Log.i(TAG, "Cloud LLM inference cancelled mid-stream")
                        connection.disconnect()
                        throw CancellationException("Cloud generation cancelled")
                    }

                    val currentLine = line?.trim() ?: continue
                    if (currentLine.startsWith("data:")) {
                        val jsonData = currentLine.removePrefix("data:").trim()
                        if (jsonData.isEmpty()) continue

                        try {
                            val jsonObj = JSONObject(jsonData)
                            val candidates = jsonObj.optJSONArray("candidates")
                            if (candidates != null && candidates.length() > 0) {
                                val candidate = candidates.getJSONObject(0)
                                val contentObj = candidate.optJSONObject("content")
                                val parts = contentObj?.optJSONArray("parts")
                                if (parts != null && parts.length() > 0) {
                                    val textChunk = parts.getJSONObject(0).optString("text", "")
                                    if (textChunk.isNotEmpty()) {
                                        responseBuilder.append(textChunk)
                                        onChunk(textChunk)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error parsing SSE chunk: ${e.message}")
                        }
                    }
                }
            }

            val response = responseBuilder.toString()
            Log.d(TAG, "Cloud inference completed — ${response.length} chars")
            response

        } catch (e: CancellationException) {
            Log.i(TAG, "Cloud generation cancelled by user")
            responseBuilder.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Cloud LLM inference failed", e)
            val errText = "Error connecting to Cloud LLM: ${e.localizedMessage}"
            onChunk(errText)
            errText
        } finally {
            connection?.disconnect()
        }
    }

    private fun getApiKey(): String {
        if (apiKey.isNotBlank()) return apiKey
        return System.getenv("EXPO_PUBLIC_GEMINI_API_KEY")
            ?: System.getProperty("EXPO_PUBLIC_GEMINI_API_KEY")
            ?: ""
    }

    companion object {
        private const val TAG = "L3CloudLLM"

        @Volatile
        var apiKey: String = ""

        @Volatile
        var isCancelled: Boolean = false

        fun cancelInference() {
            isCancelled = true
        }
    }
}
