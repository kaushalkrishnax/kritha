package expo.modules.kritha.liveTalk

import android.util.Log

/**
 * [AudioProcessor] backed by the WebRTC Audio Processing Module.
 *
 * STUB: the WebRTC APM native library (libwebrtc_apm) is not bundled yet.
 * The processor reports itself unavailable so [LiveTalkSession] falls back to
 * the platform AEC path; session behavior is unchanged. When the library
 * ships, this class will bridge capture frames through the APM and feed the
 * playback stream as the far-end reference.
 */
class WebRtcAudioProcessor : AudioProcessor {
    companion object {
        private const val TAG = "WebRtcAudioProcessor"

        val isAvailable: Boolean by lazy {
            runCatching { System.loadLibrary("webrtc_apm") }
                .onFailure { Log.i(TAG, "libwebrtc_apm not present; WebRTC APM unavailable") }
                .isSuccess
        }
    }

    override fun start(audioSessionId: Int) {
        check(isAvailable) { "WebRTC APM native library is not available" }
    }

    override fun process(input: ShortArray): ShortArray = input

    override fun stop() {
    }
}
