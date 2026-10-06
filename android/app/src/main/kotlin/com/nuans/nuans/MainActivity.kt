package com.nuans.nuans

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.nuans.nuans/open_file"
    private var channel: MethodChannel? = null
    private var pendingUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val uri = pendingUri
                        pendingUri = null
                        if (uri == null) {
                            result.success(null)
                        } else {
                            try {
                                result.success(copyUriToCache(Uri.parse(uri)))
                            } catch (error: Exception) {
                                result.error("copy", error.message, null)
                            }
                        }
                    }
                    "copyUri" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            try {
                                result.success(copyUriToCache(Uri.parse(uri)))
                            } catch (error: Exception) {
                                result.error("copy", error.message, null)
                            }
                        }
                    }
                    "unzipNuans" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("path", "Dosya yolu yok.", null)
                        } else {
                            try {
                                result.success(unwrapNuans(path))
                            } catch (error: Exception) {
                                result.error("unzip", error.message, null)
                            }
                        }
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val name = sanitizeNuansName(call.argument<String>("name"))
                        if (path.isNullOrEmpty()) {
                            result.error("path", "Dosya yolu yok.", null)
                        } else {
                            try {
                                shareNuansFile(path, name)
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("share", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleIntent(intent, notifyDart = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, notifyDart = true)
    }

    private fun sanitizeNuansName(raw: String?): String {
        var base = (raw ?: "Nuans_formu").substringAfterLast('/')
        base = base
            .replace(Regex("\\.nuansform$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\.nuans$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\.zip$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .replace(Regex("\\s+"), "_")
            .trim('_')
            .ifEmpty { "Nuans_formu" }
        return if (base.endsWith(".nuans", ignoreCase = true)) base else "$base.nuans"
    }

    private fun shareNuansFile(sourcePath: String, displayName: String) {
        val folder = File(cacheDir, "share/${System.currentTimeMillis()}")
        folder.mkdirs()
        val out = File(folder, displayName)
        File(sourcePath).copyTo(out, overwrite = true)
        val uri = FileProvider.getUriForFile(this, "$packageName.nuans.files", out)
        val mime = "application/nuans"
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, displayName)
            clipData = ClipData(displayName, arrayOf(mime), ClipData.Item(uri))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, displayName)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        grantUriToTargets(send, uri)
        startActivity(chooser)
    }

    private fun grantUriToTargets(send: Intent, uri: Uri) {
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
        val targets = packageManager.queryIntentActivities(send, PackageManager.MATCH_DEFAULT_ONLY)
        for (info in targets) {
            grantUriPermission(info.activityInfo.packageName, uri, flags)
        }
        grantUriPermission("com.whatsapp", uri, flags)
        grantUriPermission("com.whatsapp.w4b", uri, flags)
    }

    private fun notifyPendingOpenIfAny() {
        if (pendingUri.isNullOrEmpty()) return
        channel?.invokeMethod("opened", pendingUri)
    }

    private fun handleIntent(intent: Intent?, notifyDart: Boolean) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND && action != Intent.ACTION_EDIT) {
            return
        }
        val uri = extractUri(intent) ?: return
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
        }
        pendingUri = uri.toString()
        if (notifyDart) {
            notifyPendingOpenIfAny()
        }
    }

    private fun extractUri(intent: Intent): Uri? {
        when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_EDIT -> {
                intent.data?.let { return it }
                return clipUri(intent)
            }
            Intent.ACTION_SEND -> {
                return extraStream(intent) ?: clipUri(intent)
            }
            else -> {
                intent.data?.let { return it }
                extraStream(intent)?.let { return it }
                return clipUri(intent)
            }
        }
    }

    private fun clipUri(intent: Intent): Uri? {
        val clip = intent.clipData ?: return null
        if (clip.itemCount <= 0) return null
        return clip.getItemAt(0).uri
    }

    private fun extraStream(intent: Intent): Uri? {
        return if (android.os.Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun copyUriToCache(uri: Uri): String {
        val rawName = queryDisplayName(uri) ?: uri.lastPathSegment ?: "import.nuans"
        val safeName = rawName.substringAfterLast('/')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .ifEmpty { "import.nuans" }
        val out = File(cacheDir, "open_$safeName")
        val input = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Dosya açılamadı.")
        input.use { stream ->
            out.outputStream().use { output -> stream.copyTo(output) }
        }
        if (!out.exists() || out.length() == 0L) {
            throw IllegalStateException("Dosya kopyalanamadı.")
        }
        return unwrapNuans(out.absolutePath)
    }

    private fun unwrapNuans(path: String): String {
        val file = File(path)
        if (!file.name.lowercase().endsWith(".zip") && !isZip(file)) return path
        ZipInputStream(file.inputStream().buffered()).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                val name = File(entry.name).name.lowercase()
                if (!entry.isDirectory &&
                    (name.endsWith(".nuans") || name.endsWith(".nuansform") || name.endsWith(".json"))
                ) {
                    val out = File(cacheDir, "unzip_${File(entry.name).name}")
                    out.outputStream().use { zip.copyTo(it) }
                    return out.absolutePath
                }
                entry = zip.nextEntry
            }
        }
        throw IllegalStateException("Zip içinde Nüans formu yok.")
    }

    private fun isZip(file: File): Boolean {
        if (file.length() < 4) return false
        file.inputStream().use { input ->
            val header = ByteArray(2)
            if (input.read(header) != 2) return false
            return header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && index >= 0) cursor.getString(index) else null
        }
    }
}
