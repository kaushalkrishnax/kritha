package expo.modules.kritha.litert.speech.tts

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.roundToInt

class AndroidAudioOutput : AudioOutput {
    private var track: AudioTrack? = null

    override fun start(sampleRate: Int, channels: Int) {
        require(channels in 1..2) { "Only mono/stereo AudioTrack playback is supported" }
        stop()
        val channelMask = if (channels == 1) {
            AudioFormat.CHANNEL_OUT_MONO
        } else {
            AudioFormat.CHANNEL_OUT_STEREO
        }
        val min = AudioTrack.getMinBufferSize(
            sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_FLOAT,
        )
        require(min > 0) { "AudioTrack rejected sampleRate=$sampleRate channels=$channels" }
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setChannelMask(channelMask)
                    .build()
            )
            .setBufferSizeInBytes(min * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { it.play() }
    }

    override fun write(pcm: FloatArray) {
        val t = track ?: error("AudioOutput has not been started")
        var offset = 0
        while (offset < pcm.size) {
            val wrote = t.write(pcm, offset, pcm.size - offset, AudioTrack.WRITE_BLOCKING)
            require(wrote >= 0) { "AudioTrack write failed: $wrote" }
            if (wrote == 0) Thread.yield() else offset += wrote
        }
    }

    override fun stop() {
        track?.let {
            runCatching { it.stop() }
            it.release()
        }
        track = null
    }

    override fun close() = stop()
}
