package expo.modules.kritha.litert.llm

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Channel
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.LoraConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.NoRepeatNgramConfig
import com.google.ai.edge.litertlm.RepetitionPenaltyConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.SuppressTokensConfig
import com.google.ai.edge.litertlm.ThinkingConfig
import com.google.ai.edge.litertlm.OpenApiTool
import com.google.ai.edge.litertlm.tool
import java.io.Closeable
import java.util.concurrent.ConcurrentHashMap

data class LiteRTLLMMessage(val role: String, val content: String)

data class LiteRTLLMTool(
    val name: String,
    val description: String? = null,
    val parametersJson: String? = null,
    val executor: (String) -> String
)

data class LiteRTLLMRequest(
    val modelPath: String,
    val messages: List<LiteRTLLMMessage>,
    val device: Device = Device.CPU,
    val threadCount: Int? = null,
    val maxNumTokens: Int? = null,
    val maxNumImages: Int? = null,
    val cacheDir: String? = null,
    val temperature: Double = 0.8,
    val topK: Int = 40,
    val topP: Double = 0.95,
    val seed: Int = 0,
    val repetitionPenalty: Float? = null,
    val presencePenalty: Float? = null,
    val frequencyPenalty: Float? = null,
    val repetitionWindowSize: Int? = null,
    val noRepeatNgramSize: Int? = null,
    val noRepeatNgramWindowSize: Int? = null,
    val suppressTokens: List<Int> = emptyList(),
    val enableThinking: Boolean? = null,
    val thinkingTokenBudget: Int = -1,
    val maxOutputToken: Int? = null,
    val enableResponseFormat: Boolean = false,
    val enableSpeculativeDecoding: Boolean? = null,
    val automaticToolCalling: Boolean = true,
    val systemInstruction: String? = null,
    val chatTemplate: String? = null,
    val channels: List<Channel> = emptyList(),
    val tools: List<LiteRTLLMTool> = emptyList(),
    val loraPath: String? = null,
    val audioLoraPath: String? = null,
)

enum class Device { CPU, GPU, NPU }

class LiteRTLLM(private val context: Context) : Closeable {
    private val engines = ConcurrentHashMap<String, Engine>()

    @OptIn(ExperimentalApi::class)
    suspend fun generate(
        request: LiteRTLLMRequest,
        onDelta: (String) -> Unit = {},
        onChannel: (String, String) -> Unit = { _, _ -> },
    ): String {
        require(request.messages.isNotEmpty()) { "messages cannot be empty" }

        val engine = engine(request)
        val initial = request.messages.dropLast(1).map(::message)
        val final = message(request.messages.last())

        val config = ConversationConfig(
            systemInstruction = request.systemInstruction?.let { com.google.ai.edge.litertlm.Contents.of(it) },
            initialMessages = initial,
            samplerConfig = SamplerConfig(
                topK = request.topK,
                topP = request.topP,
                temperature = request.temperature,
                seed = request.seed,
            ),
            automaticToolCalling = request.automaticToolCalling,
            channels = request.channels.ifEmpty { null },
            loraConfig = if (request.loraPath != null || request.audioLoraPath != null) {
                LoraConfig(request.loraPath, request.audioLoraPath)
            } else null,
            maxOutputToken = request.maxOutputToken,
            thinkingConfig = request.enableThinking?.let {
                ThinkingConfig(it, request.thinkingTokenBudget)
            },
            enableResponseFormat = request.enableResponseFormat,
            enableSpeculativeDecoding = request.enableSpeculativeDecoding,
            chatTemplate = request.chatTemplate,
            tools = request.tools.map { it.toProvider() },
        )

        val conversation = engine.createConversation(config)
        return try {
            var full = ""
            conversation.sendMessageAsync(final).collect { partial ->
                val rendered = conversation.renderMessageIntoString(partial)
                if (rendered.isNotEmpty()) {
                    full += rendered
                    onDelta(rendered)
                }
                partial.channels.forEach { (name, content) ->
                    onChannel(name, content.toString())
                }
            }
            full
        } finally {
            conversation.close()
        }
    }

    fun closeModel(modelPath: String, device: Device) {
        engines.remove(key(modelPath, device))?.close()
    }

    override fun close() {
        engines.values.forEach { runCatching { it.close() } }
        engines.clear()
    }

    private suspend fun engine(request: LiteRTLLMRequest): Engine {
        val key = key(request.modelPath, request.device)
        engines[key]?.let { return it }

        val backend = when (request.device) {
            Device.CPU -> Backend.CPU(threadCount = request.threadCount)
            Device.GPU -> Backend.GPU()
            Device.NPU -> Backend.NPU(context.applicationInfo.nativeLibraryDir)
        }

        return Engine(
            EngineConfig(
                modelPath = request.modelPath,
                backend = backend,
                maxNumTokens = request.maxNumTokens,
                maxNumImages = request.maxNumImages,
                cacheDir = request.cacheDir,
            )
        ).also {
            it.initialize()
            engines[key] = it
        }
    }

    private fun key(path: String, device: Device) = "$device:$path"

    private fun message(message: LiteRTLLMMessage): Message = when (message.role.lowercase()) {
        "system" -> Message.system(message.content)
        "assistant", "model" -> Message.model(message.content)
        else -> Message.user(message.content)
    }

    private fun LiteRTLLMTool.toProvider() = tool(object : OpenApiTool {
        override fun getToolDescriptionJsonString(): String {
            val params = parametersJson ?: """{"type":"object","properties":{}}"""
            return buildString {
                append("""{"name":""")
                append(json(name))
                description?.let { append(""","description":"""); append(json(it)) }
                append(""","parameters":""")
                append(params)
                append('}')
            }
        }

        override fun execute(paramsJsonString: String): String = executor(paramsJsonString)
    })

    private fun json(value: String): String =
        "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
}
