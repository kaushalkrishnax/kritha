package expo.modules.kritha.runtime

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Shared HTTP download helper for model artifacts (Range resume + progress). */
internal object ModelDownloader {
    fun download(
        url: String,
        destination: File,
        onFileProgress: (Float) -> Unit,
    ) {
        var connection: HttpURLConnection? = null
        try {
            var existing = destination.length()
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 30_000
                readTimeout = 60_000
                setInstanceFollowRedirects(true)
                setRequestProperty("User-Agent", "kritha/1.0 (Kritha model downloader)")
                if (existing > 0L) {
                    setRequestProperty("Range", "bytes=$existing-")
                }
            }

            when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> if (existing > 0L) {
                    destination.delete()
                    existing = 0L
                }
                HttpURLConnection.HTTP_PARTIAL -> Unit
                else -> throw IOException(
                    "HTTP ${connection.responseCode} while downloading ${destination.name}"
                )
            }

            val totalBytes = connection.contentLength.let {
                if (it > 0L) it + existing else -1L
            }
            var downloaded = existing
            val buffer = ByteArray(64 * 1024)

            val input = connection.inputStream
                ?: throw IOException("No response body for ${destination.name}")
            input.use { stream ->
                FileOutputStream(destination, existing > 0L).use { output ->
                    while (true) {
                        val read = stream.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        downloaded += read
                        if (totalBytes > 0L) {
                            onFileProgress(downloaded.toFloat() / totalBytes)
                        }
                    }
                }
            }
        } finally {
            connection?.disconnect()
        }
    }
}
