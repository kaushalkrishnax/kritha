package expo.modules.kritha.wakeword

import android.util.Log

object WakeWordNative {
    init {
        val libraries = listOf("wakeword_bridge", "kritha", "wakeword")
        var loaded = false
        for (lib in libraries) {
            try {
                System.loadLibrary(lib)
                Log.i("WakeWordNative", "Successfully loaded native library: $lib")
                loaded = true
                break
            } catch (e: Throwable) {
                Log.e("WakeWordNative", "Failed to load native library $lib", e)
            }
        }
        if (!loaded) {
            Log.e("WakeWordNative", "FATAL: Could not load native library wakeword_bridge")
        }
    }

    @JvmStatic
    external fun runInference(samples: ShortArray): FloatArray?
}
