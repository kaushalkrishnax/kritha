package expo.modules.kritha.runtime.tts

object StaticTtsSpecs {
    private const val RELEASE_BASE =
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models"

    val allSpecs = listOf(
        TtsModelSpec(
            id = TtsModelId("piper-en-us-lessac-low"),
            displayName = "Piper Lessac Low (EN)",
            version = "1.0",
            languages = setOf("english"),
            sampleRate = 22_050,
            displaySize = "~61 MB",
            directoryName = "vits-piper-en_US-lessac-low",
            artifacts = listOf(
                TtsArtifact(
                    name = "en_US-lessac-low.onnx",
                    remoteUrl = "$RELEASE_BASE/vits-piper-en_US-lessac-low.tar.bz2",
                ),
                TtsArtifact(name = "tokens.txt"),
                TtsArtifact(name = "en_US-lessac-low.onnx.json"),
                TtsArtifact(name = "espeak-ng-data"),
            ),
        ),
        TtsModelSpec(
            id = TtsModelId("piper-en-us-lessac-medium"),
            displayName = "Piper Lessac Medium (EN)",
            version = "1.0",
            languages = setOf(
                "english",
            ),
            sampleRate = 22_050,
            displaySize = "~61 MB",
            directoryName = "vits-piper-en_US-lessac-medium",
            artifacts = listOf(
                TtsArtifact(
                    name = "en_US-lessac-medium.onnx",
                    remoteUrl = "$RELEASE_BASE/vits-piper-en_US-lessac-medium.tar.bz2",
                ),
                TtsArtifact(name = "tokens.txt"),
                TtsArtifact(name = "en_US-lessac-medium.onnx.json"),
                TtsArtifact(name = "espeak-ng-data"),
            ),
        ),
        TtsModelSpec(
            id = TtsModelId("piper-en-us-lessac-high"),
            displayName = "Piper Lessac High (EN)",
            version = "1.0",
            languages = setOf("english"),
            sampleRate = 22_050,
            displaySize = "~110 MB",
            directoryName = "vits-piper-en_US-lessac-high",
            artifacts = listOf(
                TtsArtifact(
                    name = "en_US-lessac-high.onnx",
                    remoteUrl = "$RELEASE_BASE/vits-piper-en_US-lessac-high.tar.bz2",
                ),
                TtsArtifact(name = "tokens.txt"),
                TtsArtifact(name = "en_US-lessac-high.onnx.json"),
                TtsArtifact(name = "espeak-ng-data"),
            ),
        ),
    )
}
