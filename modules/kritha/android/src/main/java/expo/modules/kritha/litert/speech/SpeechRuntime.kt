package expo.modules.kritha.litert.speech

import android.content.Context
import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class SpeechRuntime(
    context: Context,
    private val execution: LiteRTExecutionOptions = LiteRTExecutionOptions()
) : AutoCloseable {
    private val runtime = LiteRTRuntime(context)
    private val adapters = ConcurrentHashMap<String, AutoCloseable>()

    fun load(manifest: SpeechModelManifest, tokenizer: Tokenizer): AutoCloseable {
        adapters[manifest.id]?.let { return it }

        val adapter: AutoCloseable = when (manifest.task) {
            SpeechTask.ASR, SpeechTask.STT -> when (manifest.architecture.lowercase()) {
                "ctc", "parakeet-ctc", "wav2vec2" ->
                    CtcAsrAdapter(runtime, manifest, execution, tokenizer)

                "whisper", "moonshine", "seq2seq" ->
                    Seq2SeqAsrAdapter(runtime, manifest, execution, tokenizer)

                else -> error(
                    "No built-in ASR adapter for '${manifest.architecture}'. " +
                        "Register a family adapter rather than guessing model semantics."
                )
            }

            SpeechTask.TTS -> SingleGraphTtsAdapter(
                runtime, manifest, execution, tokenizer
            )
        }

        adapters[manifest.id] = adapter
        return adapter
    }

    fun unload(modelId: String) {
        adapters.remove(modelId)?.let { runCatching { it.close() } }
    }

    fun unloadAll() {
        adapters.values.forEach { runCatching { it.close() } }
        adapters.clear()
        runtime.close()
    }

    override fun close() = unloadAll()

    companion object {
        fun manifestFromJson(file: File): SpeechModelManifest {
            require(file.isFile) { "Manifest not found: ${file.absolutePath}" }
            return manifestFromJson(file.readText())
        }

        fun manifestFromJson(json: String): SpeechModelManifest {
            val o = JSONObject(json)
            val audio = o.optJSONObject("audio")
            val mel = o.optJSONObject("mel")

            val metadata = mutableMapOf<String, String>()
            o.optJSONObject("metadata")?.keys()?.forEach { key ->
                metadata[key] = o.getJSONObject("metadata").optString(key)
            }

            return SpeechModelManifest(
                id = o.getString("id"),
                architecture = o.getString("architecture"),
                task = SpeechTask.valueOf(o.getString("task").uppercase().replace('-', '_')),
                modelPath = o.getString("modelPath"),
                signature = o.optString("signature", ""),
                inputNames = o.optJSONArray("inputNames").toStringList(),
                outputNames = o.optJSONArray("outputNames").toStringList(),
                outputTypes = o.optJSONArray("outputTypes").toStringList(),
                audio = AudioSpec(
                    sampleRate = audio?.optInt("sampleRate", 16000) ?: 16000,
                    channels = audio?.optInt("channels", 1) ?: 1
                ),
                inputMilliseconds = if (o.has("inputMilliseconds")) o.getInt("inputMilliseconds") else null,
                mel = mel?.let {
                    MelSpec(
                        fftSize = it.optInt("fftSize", 400),
                        hopLength = it.optInt("hopLength", 160),
                        nMels = it.optInt("nMels", 80),
                        windowLength = it.optInt("windowLength", 400),
                        preEmphasis = it.optDouble("preEmphasis", 0.0).toFloat(),
                        normalize = it.optBoolean("normalize", true)
                    )
                },
                startTokenId = if (o.has("startTokenId")) o.getInt("startTokenId") else null,
                stopTokenId = if (o.has("stopTokenId")) o.getInt("stopTokenId") else null,
                maxDecodeTokens = o.optInt("maxDecodeTokens", 128),
                tokenizerPath = o.optString("tokenizerPath", null),
                metadata = metadata
            )
        }

        private fun org.json.JSONArray?.toStringList(): List<String> {
            if (this == null) return emptyList()
            return buildList(length()) {
                for (i in 0 until length()) add(getString(i))
            }
        }
    }
}
