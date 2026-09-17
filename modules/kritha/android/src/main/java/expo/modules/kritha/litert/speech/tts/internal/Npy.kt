package expo.modules.kritha.litert.speech.tts.internal

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.ShortBuffer
import java.nio.channels.FileChannel
import java.util.zip.ZipFile

/**
 * Minimal little-endian .npy/.npz reader shared by TTS adapters. Model-specific
 * table layouts stay in their adapter packages.
 */
internal object Npy {
    private data class Header(val isHalf: Boolean, val count: Int, val dataOffset: Int)

    private fun parseHeader(bytes: ByteArray): Header {
        require(bytes.size > 12 && bytes[0] == 0x93.toByte() && String(bytes, 1, 5) == "NUMPY") {
            "Not a NumPy .npy file"
        }
        val major = bytes[6].toInt() and 0xFF
        val headerLen: Int
        val headerStart: Int
        if (major == 1) {
            headerLen = (bytes[8].toInt() and 0xFF) or ((bytes[9].toInt() and 0xFF) shl 8)
            headerStart = 10
        } else {
            headerLen = (bytes[8].toInt() and 0xFF) or
                ((bytes[9].toInt() and 0xFF) shl 8) or
                ((bytes[10].toInt() and 0xFF) shl 16) or
                ((bytes[11].toInt() and 0xFF) shl 24)
            headerStart = 12
        }
        require(headerStart + headerLen <= bytes.size) { "Incomplete .npy header" }
        val header = String(bytes, headerStart, headerLen)
        val isHalf = when {
            header.contains("'<f2'") -> true
            header.contains("'<f4'") -> false
            else -> error("Unsupported .npy dtype: $header")
        }
        // Fortran-order layouts would need a transpose the adapters don't implement.
        require(!header.contains("'fortran_order': True")) { "Fortran-order arrays are unsupported" }
        val shapeText = Regex("'shape':\\s*\\(([^)]*)\\)").find(header)?.groupValues?.get(1)
            ?: error("Missing .npy shape")
        val dims = shapeText.split(',').mapNotNull { it.trim().toLongOrNull() }
        require(dims.isNotEmpty()) { "Missing .npy shape dimensions" }
        val countLong = dims.fold(1L) { a, b -> Math.multiplyExact(a, b) }
        require(countLong <= Int.MAX_VALUE) { ".npy array is too large for JVM arrays" }
        return Header(isHalf, countLong.toInt(), headerStart + headerLen)
    }

    fun loadFloats(file: File): FloatArray = floatsFromNpyBytes(file.readBytes())

    fun floatsFromNpyBytes(bytes: ByteArray): FloatArray {
        val h = parseHeader(bytes)
        val buf = ByteBuffer.wrap(bytes, h.dataOffset, bytes.size - h.dataOffset)
            .order(ByteOrder.LITTLE_ENDIAN)
        val out = FloatArray(h.count)
        if (h.isHalf) {
            val src = buf.asShortBuffer()
            for (i in 0 until h.count) out[i] = halfToFloat(src.get(i))
        } else {
            buf.asFloatBuffer().get(out)
        }
        return out
    }

    fun mmapHalf(file: File): ShortBuffer {
        val headSize = minOf(4096, file.length().toInt().coerceAtLeast(16))
        val head = ByteArray(headSize)
        RandomAccessFile(file, "r").use { raf -> raf.readFully(head) }
        val h = parseHeader(head)
        require(h.isHalf) { "Expected fp16 table: ${file.absolutePath}" }
        val channel = RandomAccessFile(file, "r").channel
        val map: MappedByteBuffer = try {
            channel.map(
                FileChannel.MapMode.READ_ONLY,
                h.dataOffset.toLong(),
                file.length() - h.dataOffset
            )
        } finally {
            channel.close()
        }
        return map.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
    }

    fun loadNpz(file: File, names: List<String>): Map<String, FloatArray> {
        val out = HashMap<String, FloatArray>(names.size)
        ZipFile(file).use { zip ->
            for (name in names) {
                val entry = zip.getEntry("$name.npy")
                    ?: error("$name.npy not found in ${file.absolutePath}")
                zip.getInputStream(entry).use { input ->
                    out[name] = floatsFromNpyBytes(input.readBytes())
                }
            }
        }
        return out
    }

    /** Raw little-endian float32 payload of a single `.npy` entry (voices conversion). */
    fun readF32Payload(raw: ByteArray): ByteArray {
        val magic = byteArrayOf(0x93.toByte(), 0x4e, 0x55, 0x4d, 0x50, 0x59) // \x93NUMPY
        require(raw.size > magic.size + 4 && magic.indices.all { raw[it] == magic[it] }) {
            "Invalid .npy header"
        }
        val major = raw[6].toInt()
        val headerLen = when (major) {
            1 -> (raw[8].toInt() and 0xFF) or ((raw[9].toInt() and 0xFF) shl 8)
            2 -> (raw[8].toInt() and 0xFF) or ((raw[9].toInt() and 0xFF) shl 8) or
                ((raw[10].toInt() and 0xFF) shl 16) or ((raw[11].toInt() and 0xFF) shl 24)
            else -> error("Unsupported .npy version $major")
        }
        val headerStart = if (major == 1) 10 else 12
        val header = String(raw, headerStart, headerLen, Charsets.US_ASCII)
        val descr = Regex("'descr':\\s*'([^']*)'").find(header)
            ?.groupValues?.get(1) ?: error("npy header missing descr")
        require(descr.startsWith("<f4") || descr.startsWith("|f4") || descr == "float32") {
            "Unsupported npy dtype: $descr"
        }
        val dataStart = headerStart + headerLen
        return raw.copyOfRange(dataStart, raw.size)
    }

    fun halfToFloat(h: Short): Float {
        val bits = h.toInt() and 0xFFFF
        val sign = (bits and 0x8000) shl 16
        val exp = (bits ushr 10) and 0x1F
        val mant = bits and 0x3FF
        return when {
            exp == 0 -> {
                if (mant == 0) Float.fromBits(sign)
                else {
                    var m = mant
                    var e = -1
                    while ((m and 0x400) == 0) { m = m shl 1; e++ }
                    m = m and 0x3FF
                    Float.fromBits(sign or ((127 - 15 - e) shl 23) or (m shl 13))
                }
            }
            exp == 0x1F -> Float.fromBits(sign or 0x7F800000 or (mant shl 13))
            else -> Float.fromBits(sign or ((exp - 15 + 127) shl 23) or (mant shl 13))
        }
    }
}
