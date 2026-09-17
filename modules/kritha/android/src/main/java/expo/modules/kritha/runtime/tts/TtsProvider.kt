package expo.modules.kritha.runtime.tts

interface TtsProvider {
    fun getAvailableSpecs(): List<TtsModelSpec> = emptyList()

    fun synthesize(
        model: TtsModelAssets,
        text: String,
        options: SynthesisOptions = SynthesisOptions(),
    ): SynthesisResult

    fun release(modelId: TtsModelId)
    fun releaseAll()
    
    fun finishDownload(modelDir: java.io.File, modelId: String) {}
}
