package expo.modules.wakeword.intelligence

internal sealed interface PipelineResult {
    data class Hit(val response: String, val layer: IntelligenceLayer) : PipelineResult
    data class Miss(val reason: String) : PipelineResult
}
