package com.example.vitality_assist

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    // NOTA: FLAG_SECURE rimosso per consentire l'acquisizione di screenshot dimostrativi per la tesi.
    // In ambiente di produzione ospedaliero può essere riattivato (OWASP Mobile M9 / GDPR Art. 32).

    companion object {
        private const val DEVICE_FILES_CHANNEL = "com.example.vitality_assist/device_files"
        private const val SHARED_REPORTS_DIR = "shared_reports"
        private const val ALBUM_FOLDER = "diaLog2"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "referto.png"
                        val mimeType = call.argument<String>("mimeType") ?: "image/png"
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Dati immagine vuoti", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val info = saveImageToGalleryInternal(bytes, fileName, mimeType)
                                runOnUiThread { result.success(info) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("GALLERY_SAVE_ERROR", e.localizedMessage ?: "Errore salvataggio in Galleria", null)
                                }
                            }
                        }.start()
                    }

                    "saveFileToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "referto.pdf"
                        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Dati file vuoti", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val info = saveFileToDownloadsInternal(bytes, fileName, mimeType)
                                runOnUiThread { result.success(info) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("DOWNLOAD_SAVE_ERROR", e.localizedMessage ?: "Errore salvataggio in Archivio", null)
                                }
                            }
                        }.start()
                    }

                    "openFileWithChooser" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "referto.pdf"
                        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                        val chooserTitle = call.argument<String>("chooserTitle") ?: "Apri referto con"
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Dati file vuoti", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openFileWithChooserInternal(bytes, fileName, mimeType, chooserTitle)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FILE_ERROR", e.localizedMessage ?: "Impossibile aprire il file", null)
                        }
                    }

                    "renderPdfPages" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val maxPages = call.argument<Int>("maxPages") ?: 10
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Dati PDF vuoti", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val pages = renderPdfPagesInternal(bytes, maxPages.coerceIn(1, 20))
                                runOnUiThread { result.success(pages) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("PDF_RENDER_ERROR", e.localizedMessage ?: "Impossibile renderizzare il PDF", null)
                                }
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sanitizeFileName(raw: String, fallbackExt: String): String {
        val cleaned = raw.replace(Regex("[^a-zA-Z0-9._\\-]"), "_").trim('_')
        if (cleaned.isEmpty()) return "referto.$fallbackExt"
        return if (cleaned.contains('.')) cleaned else "$cleaned.$fallbackExt"
    }

    private fun saveImageToGalleryInternal(
        bytes: ByteArray,
        fileName: String,
        mimeType: String
    ): Map<String, String> {
        val ext = when {
            mimeType.contains("jpeg") || mimeType.contains("jpg") -> "jpg"
            mimeType.contains("webp") -> "webp"
            else -> "png"
        }
        val safeName = sanitizeFileName(fileName, ext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, safeName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$ALBUM_FOLDER")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Impossibile creare la voce in Galleria")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                    out.flush()
                } ?: throw IllegalStateException("Stream di scrittura Galleria non disponibile")
                val done = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return mapOf(
                "uri" to uri.toString(),
                "location" to "Galleria/$ALBUM_FOLDER",
                "fileName" to safeName
            )
        }

        @Suppress("DEPRECATION")
        val picturesDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            ALBUM_FOLDER
        )
        if (!picturesDir.exists()) picturesDir.mkdirs()
        val outFile = File(picturesDir, safeName)
        FileOutputStream(outFile).use { it.write(bytes) }
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(outFile.absolutePath),
            arrayOf(mimeType),
            null
        )
        return mapOf(
            "uri" to outFile.absolutePath,
            "location" to "Galleria/$ALBUM_FOLDER",
            "fileName" to safeName
        )
    }

    private fun saveFileToDownloadsInternal(
        bytes: ByteArray,
        fileName: String,
        mimeType: String
    ): Map<String, String> {
        val ext = if (mimeType.contains("pdf")) "pdf" else "bin"
        val safeName = sanitizeFileName(fileName, ext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$ALBUM_FOLDER")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Impossibile creare il file in Download")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                    out.flush()
                } ?: throw IllegalStateException("Stream di scrittura Archivio non disponibile")
                val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return mapOf(
                "uri" to uri.toString(),
                "location" to "Download/$ALBUM_FOLDER",
                "fileName" to safeName
            )
        }

        @Suppress("DEPRECATION")
        val downloadsDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            ALBUM_FOLDER
        )
        if (!downloadsDir.exists()) downloadsDir.mkdirs()
        val outFile = File(downloadsDir, safeName)
        FileOutputStream(outFile).use { it.write(bytes) }
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(outFile.absolutePath),
            arrayOf(mimeType),
            null
        )
        return mapOf(
            "uri" to outFile.absolutePath,
            "location" to "Download/$ALBUM_FOLDER",
            "fileName" to safeName
        )
    }

    private fun openFileWithChooserInternal(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        chooserTitle: String
    ) {
        val dir = File(cacheDir, SHARED_REPORTS_DIR)
        if (!dir.exists()) dir.mkdirs()

        // Pulizia file temporanei vecchi (> 24 ore)
        val cutoff = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
        dir.listFiles()?.forEach { f ->
            if (f.isFile && f.lastModified() < cutoff) {
                f.delete()
            }
        }

        val ext = when {
            mimeType.contains("pdf") -> "pdf"
            mimeType.contains("jpeg") || mimeType.contains("jpg") -> "jpg"
            mimeType.contains("webp") -> "webp"
            else -> "png"
        }
        val safeName = sanitizeFileName(fileName, ext)
        val tempFile = File(dir, "${System.currentTimeMillis()}_$safeName")
        FileOutputStream(tempFile).use { it.write(bytes) }

        val authority = "${applicationContext.packageName}.report_fileprovider"
        val contentUri = FileProvider.getUriForFile(applicationContext, authority, tempFile)

        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                viewIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(viewIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        for (info in resolved) {
            grantUriPermission(
                info.activityInfo.packageName,
                contentUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        val chooser = Intent.createChooser(viewIntent, chooserTitle).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }

    private fun renderPdfPagesInternal(bytes: ByteArray, maxPages: Int): List<ByteArray> {
        val tempPdf = File.createTempFile("preview_report_", ".pdf", cacheDir)
        try {
            FileOutputStream(tempPdf).use { it.write(bytes) }
            val pfd = ParcelFileDescriptor.open(tempPdf, ParcelFileDescriptor.MODE_READ_ONLY)
            pfd.use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    val count = minOf(renderer.pageCount, maxPages)
                    val out = ArrayList<ByteArray>(count)
                    for (i in 0 until count) {
                        renderer.openPage(i).use { page ->
                            val scale = (1200f / page.width.coerceAtLeast(1)).coerceIn(1.0f, 2.2f)
                            val targetW = (page.width * scale).toInt().coerceAtLeast(1)
                            val targetH = (page.height * scale).toInt().coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
                            try {
                                val canvas = Canvas(bitmap)
                                canvas.drawColor(Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val baos = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 92, baos)
                                out.add(baos.toByteArray())
                            } finally {
                                bitmap.recycle()
                            }
                        }
                    }
                    return out
                }
            }
        } finally {
            tempPdf.delete()
        }
    }
}
