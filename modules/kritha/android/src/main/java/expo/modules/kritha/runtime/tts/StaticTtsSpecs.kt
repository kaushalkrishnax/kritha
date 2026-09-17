package expo.modules.kritha.runtime.tts

object StaticTtsSpecs {
    val allSpecs = listOf(
        TtsModelSpec(
            id = TtsModelId("qwen3-tts"),
            displayName = "Qwen3 TTS",
            version = "0.6b-base",
            languages = setOf("english"),
            sampleRate = 24_000,
            displaySize = "1.5 GB",
            directoryName = "qwen3-tts-0.6b-base",
            artifacts = listOf(
                TtsArtifact(
                    name = "qwen3_tts_0_6b.tflite",
                    remoteUrl = "https://huggingface.co/litert-community/Qwen3-TTS/resolve/main/qwen3_tts_0_6b.tflite"
                )
            )
        ),
        TtsModelSpec(
            id = TtsModelId("kitten-tts"),
            displayName = "KittenTTS Nano 0.8 (LiteRT)",
            version = "0.8",
            languages = setOf("english"),
            sampleRate = 24_000,
            displaySize = "45 MB",
            artifacts = listOf(
                TtsArtifact(
                    name = "kitten_predictor_fp16.tflite",
                    remoteUrl = "https://huggingface.co/litert-community/kitten-tts-nano-0.8/resolve/main/kitten_predictor_fp16.tflite"
                ),
                TtsArtifact(
                    name = "kitten_prosody_fp16.tflite",
                    remoteUrl = "https://huggingface.co/litert-community/kitten-tts-nano-0.8/resolve/main/kitten_prosody_fp16.tflite"
                ),
                TtsArtifact(
                    name = "kitten_vocoder_fp16.tflite",
                    remoteUrl = "https://huggingface.co/litert-community/kitten-tts-nano-0.8/resolve/main/kitten_vocoder_fp16.tflite"
                ),
                TtsArtifact(name = "voices.bin"),
                TtsArtifact(
                    name = "voices.npz",
                    required = false,
                    remoteUrl = "https://huggingface.co/litert-community/kitten-tts-nano-0.8/resolve/main/voices.npz"
                ),
                TtsArtifact(
                    name = "dp_g2p_matcha_fp16.tflite",
                    remoteUrl = "https://huggingface.co/litert-community/Matcha-TTS/resolve/main/dp_g2p_matcha_fp16.tflite"
                ),
                TtsArtifact(
                    name = "config.json",
                    remoteUrl = "https://huggingface.co/litert-community/Matcha-TTS/resolve/main/config.json"
                ),
                TtsArtifact(
                    name = "g2p_meta.json",
                    remoteUrl = "https://huggingface.co/litert-community/Matcha-TTS/resolve/main/g2p_meta.json"
                ),
                TtsArtifact(name = "g2p_dict.txt", required = false),
                TtsArtifact(
                    name = "g2p_dict.txt.gz",
                    required = false,
                    remoteUrl = "https://huggingface.co/litert-community/Matcha-TTS/resolve/main/g2p_dict.txt.gz"
                )
            )
        )
    )
}
