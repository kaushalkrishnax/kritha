package expo.modules.kritha.runtime.tts

import java.io.File

class TtsFileAssets(
    override val modelId: TtsModelId,
    private val root: File,
) : TtsModelAssets {
    private val canonicalRoot = root.canonicalFile

    init {
        require(canonicalRoot.isDirectory) {
            "TTS model directory does not exist: ${canonicalRoot.absolutePath}"
        }
    }

    override fun file(name: String): File {
        require(name.isNotBlank()) { "Asset name cannot be blank" }
        val file = File(canonicalRoot, name).canonicalFile
        require(file == canonicalRoot || file.toPath().startsWith(canonicalRoot.toPath())) {
            "Asset path escapes model directory: $name"
        }
        return file
    }

    override fun exists(name: String): Boolean = file(name).isFile
}
