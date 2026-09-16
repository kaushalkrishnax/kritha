package expo.modules.kritha.litert.speech

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

object Audio {
    fun mono(audio: FloatArray, channels: Int): FloatArray {
        if (channels <= 1) return audio
        val frames = audio.size / channels
        return FloatArray(frames) { frame ->
            var sum = 0f
            for (c in 0 until channels) sum += audio[frame * channels + c]
            sum / channels
        }
    }

    fun resample(input: FloatArray, fromRate: Int, toRate: Int): FloatArray {
        if (fromRate == toRate || input.isEmpty()) return input
        val outSize = (input.size.toLong() * toRate / fromRate).toInt()
        return FloatArray(outSize) { i ->
            val source = i.toDouble() * fromRate / toRate
            val left = source.toInt().coerceIn(0, input.lastIndex)
            val right = (left + 1).coerceAtMost(input.lastIndex)
            val fraction = (source - left).toFloat()
            input[left] * (1f - fraction) + input[right] * fraction
        }
    }

    fun normalizePeak(input: FloatArray): FloatArray {
        val peak = input.maxOfOrNull { kotlin.math.abs(it) } ?: 0f
        if (peak <= 1f || peak == 0f) return input
        return FloatArray(input.size) { input[it] / peak }
    }

    fun logMel(input: FloatArray, sampleRate: Int, spec: MelSpec): FloatArray {
        require(spec.fftSize > 0 && spec.nMels > 0 && spec.hopLength > 0)
        val window = hann(spec.windowLength)
        val frameCount = if (input.size <= spec.fftSize) 1
        else 1 + (input.size - spec.fftSize) / spec.hopLength

        val filters = melFilterBank(
            sampleRate, spec.fftSize, spec.nMels, 20f, sampleRate / 2f
        )
        val output = FloatArray(frameCount * spec.nMels)
        val frame = FloatArray(spec.fftSize)

        for (f in 0 until frameCount) {
            val offset = f * spec.hopLength
            for (i in frame.indices) {
                val x = if (offset + i < input.size) input[offset + i] else 0f
                frame[i] = if (i < window.size) x * window[i] else x
            }

            if (spec.preEmphasis != 0f) {
                for (i in frame.lastIndex downTo 1) {
                    frame[i] -= spec.preEmphasis * frame[i - 1]
                }
            }

            val power = powerSpectrum(frame)
            for (m in 0 until spec.nMels) {
                var energy = 0.0
                val filter = filters[m]
                for (k in filter.indices) energy += power[k] * filter[k]
                output[m * frameCount + f] = ln(max(energy.toFloat(), 1e-10f))
            }
        }

        if (!spec.normalize) return output
        var mean = output.average().toFloat()
        var variance = output.map { (it - mean) * (it - mean) }.average().toFloat()
        val std = sqrt(max(variance, 1e-8f))
        for (i in output.indices) output[i] = (output[i] - mean) / std
        return output
    }

    private fun hann(n: Int): FloatArray =
        FloatArray(n) { i -> (0.5 - 0.5 * cos(2.0 * PI * i / max(1, n - 1))).toFloat() }

    private fun powerSpectrum(frame: FloatArray): FloatArray {
        val n = frame.size
        val bins = n / 2 + 1
        val out = FloatArray(bins)
        for (k in 0 until bins) {
            var re = 0.0
            var im = 0.0
            for (t in 0 until n) {
                val angle = -2.0 * PI * k * t / n
                re += frame[t] * cos(angle)
                im += frame[t] * sin(angle)
            }
            out[k] = (re * re + im * im).toFloat() / n
        }
        return out
    }

    private fun melFilterBank(
        sampleRate: Int,
        fftSize: Int,
        mels: Int,
        lowHz: Float,
        highHz: Float
    ): Array<FloatArray> {
        fun hzToMel(hz: Float) = 2595f * kotlin.math.log10(1f + hz / 700f)
        fun melToHz(mel: Float) = 700f * (10f.pow(mel / 2595f) - 1f)

        val low = hzToMel(lowHz)
        val high = hzToMel(highHz)
        val points = FloatArray(mels + 2) { low + (high - low) * it / (mels + 1) }
        val bins = points.map { ((fftSize + 1) * melToHz(it) / sampleRate).toInt() }
        return Array(mels) { m ->
            val filter = FloatArray(fftSize / 2 + 1)
            val a = bins[m]
            val b = bins[m + 1]
            val c = bins[m + 2]
            for (k in a until b) if (k in filter.indices && b > a) filter[k] = (k - a).toFloat() / (b - a)
            for (k in b until c) if (k in filter.indices && c > b) filter[k] = (c - k).toFloat() / (c - b)
            filter
        }
    }

    private fun Float.pow(value: Float): Float = exp(value * ln(this))
}
