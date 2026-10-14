package com.darvoza.security.darvoza

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.darvoza.security/apk_receiver"
    private val ACTION_INSTALL_COMPLETE = "com.darvoza.security.INSTALL_COMPLETE"
    private var pendingApkPath: String? = null
    private var isSelfTriggered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        handleIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialApk" -> {
                    result.success(pendingApkPath)
                    pendingApkPath = null
                }
                "getApkMetadata" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val metadata = extractApkMetadata(path)
                            result.success(metadata)
                        } catch (e: Exception) {
                            result.error("METADATA_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "checkInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            installApkDirectly(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "deleteApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val file = File(path)
                            val deleted = file.delete()
                            result.success(deleted)
                        } catch (e: Exception) {
                            result.error("DELETE_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "getInstalledAppsAudit" -> {
                    try {
                        val apps = getInstalledAppsWithPermissions()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("AUDIT_FAILED", e.message, null)
                    }
                }
                "scanTelegramDownloads" -> {
                    try {
                        val apks = findRecentDownloadedApks()
                        result.success(apks)
                    } catch (e: Exception) {
                        result.error("SCAN_DOWNLOADS_FAILED", e.message, null)
                    }
                }
                "startWatcherService" -> {
                    try {
                        val serviceIntent = Intent(this, ApkWatcherService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WATCHER_START_FAILED", e.message, null)
                    }
                }
                "deepScanApkStrings" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val scanResult = performDeepStringAndUrlScan(path)
                            result.success(scanResult)
                        } catch (e: Exception) {
                            result.error("DEEP_SCAN_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "cleanTrashApks" -> {
                    try {
                        val cleaned = cleanAllDownloadedApkTrash()
                        result.success(cleaned)
                    } catch (e: Exception) {
                        result.error("CLEAN_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractApkMetadata(filePath: String): Map<String, Any?> {
        val pm = packageManager
        val pi = pm.getPackageArchiveInfo(filePath, PackageManager.GET_ACTIVITIES or PackageManager.GET_PERMISSIONS)
        val data = mutableMapOf<String, Any?>()

        if (pi != null) {
            val appInfo = pi.applicationInfo
            if (appInfo != null) {
                appInfo.sourceDir = filePath
                appInfo.publicSourceDir = filePath

                val appName = pm.getApplicationLabel(appInfo).toString()
                val packageName = pi.packageName
                val versionName = pi.versionName ?: "1.0"
                val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    pi.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    pi.versionCode.toLong()
                }

                data["appName"] = appName
                data["packageName"] = packageName
                data["versionName"] = versionName
                data["versionCode"] = versionCode

                try {
                    val iconDrawable = pm.getApplicationIcon(appInfo)
                    val bitmap = drawableToBitmap(iconDrawable)
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    data["iconBytes"] = stream.toByteArray()
                } catch (e: Exception) {
                    data["iconBytes"] = null
                }
            }
        }
        return data
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 128
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 128
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    /**
     * Android PackageInstaller.Session orqali bevosita (to'g'ridan-to'g'ri) o'rnatish.
     * Bu usulda tizim qaysi dastur orqali ochishni so'rab o'tirmaydi, to'g'ridan-to'g'ri o'rnatish boshlanadi.
     */
    private fun installApkDirectly(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) throw Exception("APK file does not exist")

        val pi = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        
        // Ilova nomini sessiyaga berish
        try {
            val archiveInfo = packageManager.getPackageArchiveInfo(filePath, 0)
            if (archiveInfo != null) {
                params.setAppPackageName(archiveInfo.packageName)
            }
        } catch (_: Exception) {}

        val sessionId = pi.createSession(params)
        val session = pi.openSession(sessionId)

        val inputStream: InputStream = FileInputStream(file)
        val outputStream: OutputStream = session.openWrite("package_install_darvoza", 0, file.length())

        val buffer = ByteArray(65536)
        var c: Int
        while (inputStream.read(buffer).also { c = it } != -1) {
            outputStream.write(buffer, 0, c)
        }
        session.fsync(outputStream)
        inputStream.close()
        outputStream.close()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_INSTALL_COMPLETE
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, sessionId, intent, flags)

        isSelfTriggered = true
        session.commit(pendingIntent.intentSender)
        session.close()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == ACTION_INSTALL_COMPLETE) {
            // O'rnatish yakunlandi yoki foydalanuvchi tasdiqladi
            return
        }
        if (isSelfTriggered) {
            isSelfTriggered = false
            return
        }
        handleIntent(intent)
        if (pendingApkPath != null && flutterEngine != null) {
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onApkReceived", pendingApkPath)
            pendingApkPath = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == ACTION_INSTALL_COMPLETE || isSelfTriggered) {
            isSelfTriggered = false
            return
        }
        val uri = intent?.data ?: return
        try {
            val localPath = copyUriToCache(uri)
            pendingApkPath = localPath
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun copyUriToCache(uri: Uri): String {
        if (uri.scheme == "file") {
            return uri.path ?: ""
        }
        val inputStream = contentResolver.openInputStream(uri) ?: return ""
        val tempFile = File(cacheDir, "incoming_target_${System.currentTimeMillis()}.apk")
        val outputStream = FileOutputStream(tempFile)
        inputStream.use { input ->
            outputStream.use { output ->
                input.copyTo(output)
            }
        }
        return tempFile.absolutePath
    }

    private fun getInstalledAppsWithPermissions(): List<Map<String, Any?>> {
        val pm = packageManager
        val packages = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        val list = mutableListOf<Map<String, Any?>>()

        for (pi in packages) {
            val appInfo = pi.applicationInfo ?: continue
            // Tizim dasturlari (System apps) emas, faqat foydalanuvchi o'rnatgan dasturlarni filtrlash
            val isSystemApp = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystemApp && !pi.packageName.contains("telegram") && !pi.packageName.contains("whatsapp")) {
                continue
            }

            val appName = pm.getApplicationLabel(appInfo).toString()
            val packageName = pi.packageName
            val permissions = pi.requestedPermissions?.toList() ?: emptyList<String>()

            // Faqat maxfiy huquqlari bo'lgan ilovalarni yoki umumiy ilovalarni olish
            val dangerous = permissions.filter {
                it.contains("SMS") || it.contains("RECORD_AUDIO") || it.contains("CAMERA") ||
                it.contains("LOCATION") || it.contains("CONTACTS") || it.contains("ACCESSIBILITY")
            }

            val item = mutableMapOf<String, Any?>()
            item["appName"] = appName
            item["packageName"] = packageName
            item["versionName"] = pi.versionName ?: "1.0"
            item["isSystemApp"] = isSystemApp
            item["dangerousCount"] = dangerous.size
            item["dangerousPermissions"] = dangerous

            // Kichik rasm (icon)
            try {
                val iconDrawable = pm.getApplicationIcon(appInfo)
                val bitmap = drawableToBitmap(iconDrawable)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
                item["iconBytes"] = stream.toByteArray()
            } catch (e: Exception) {
                item["iconBytes"] = null
            }

            list.add(item)
        }

        // Xavflilik darajasi yuqorilari birinchi chiqadi
        list.sortByDescending { (it["dangerousCount"] as? Int) ?: 0 }
        return list
    }

    private fun findRecentDownloadedApks(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val candidateDirs = listOf(
            File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "Telegram"),
            android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS),
            File(android.os.Environment.getExternalStorageDirectory(), "Telegram/Telegram Documents")
        )

        for (dir in candidateDirs) {
            if (dir.exists() && dir.isDirectory) {
                val files = dir.listFiles { f -> f.isFile && f.name.endsWith(".apk", ignoreCase = true) }
                if (files != null) {
                    for (file in files) {
                        try {
                            val item = mutableMapOf<String, Any?>()
                            item["path"] = file.absolutePath
                            item["fileName"] = file.name
                            item["size"] = file.length()
                            item["lastModified"] = file.lastModified()
                            results.add(item)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            }
        }

        // Eng yangi yuklangan fayllar yuqorida turadi
        results.sortByDescending { (it["lastModified"] as? Long) ?: 0L }
        return results.take(15)
    }

    /**
     * SHAFAQATSIZ STRING VA URL SKANER:
     * APK arxividagi barcha DEX va resurslardan yashirin URL, IP, Bot tokenlari va shubhali domanlarni qidiradi.
     */
    private fun performDeepStringAndUrlScan(filePath: String): Map<String, Any?> {
        val file = File(filePath)
        val extractedUrls = mutableSetOf<String>()
        val extractedIps = mutableSetOf<String>()
        val suspiciousTokens = mutableSetOf<String>()
        val suspiciousDomains = mutableSetOf<String>()

        val urlPattern = Regex("https?://[a-zA-Z0-9.-]+(?:/[a-zA-Z0-9&%_.~+-]*)*")
        val ipPattern = Regex("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b")
        val botTokenPattern = Regex("[0-9]{8,10}:[a-zA-Z0-9_-]{35}")

        try {
            val zipFile = java.util.zip.ZipFile(file)
            val entries = zipFile.entries()

            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                if (entry.name.endsWith(".dex") || entry.name == "resources.arsc" || entry.name == "AndroidManifest.xml") {
                    val stream = zipFile.getInputStream(entry)
                    val buffer = ByteArray(entry.size.coerceAtMost(1024 * 1024 * 5).toInt()) // Max 5MB per dex chunk
                    val read = stream.read(buffer)
                    if (read > 0) {
                        val content = String(buffer, 0, read, Charsets.ISO_8859_1)

                        // URL-larni yig'ish
                        urlPattern.findAll(content).forEach { match ->
                            val url = match.value
                            if (!url.contains("schemas.android.com") && !url.contains("w3.org") && !url.contains("google.com")) {
                                extractedUrls.add(url)
                                if (url.contains(".ru") || url.contains(".xyz") || url.contains(".top") || url.contains(".cc")) {
                                    suspiciousDomains.add(url)
                                }
                            }
                        }

                        // Shubhali qattiq yozilgan IP manzillarni yig'ish
                        ipPattern.findAll(content).forEach { match ->
                            val ip = match.value
                            if (!ip.startsWith("127.") && !ip.startsWith("0.0.") && !ip.startsWith("255.")) {
                                extractedIps.add(ip)
                            }
                        }

                        // Telegram bot tokenlari
                        botTokenPattern.findAll(content).forEach { match ->
                            suspiciousTokens.add(match.value)
                        }
                    }
                    stream.close()
                }
            }
            zipFile.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val result = mutableMapOf<String, Any?>()
        result["urls"] = extractedUrls.take(25).toList()
        result["ips"] = extractedIps.take(10).toList()
        result["suspiciousDomains"] = suspiciousDomains.toList()
        result["botTokens"] = suspiciousTokens.toList()
        result["hasMaliciousIndicators"] = suspiciousDomains.isNotEmpty() || suspiciousTokens.isNotEmpty() || extractedIps.isNotEmpty()

        return result
    }

    /**
     * ZERO TRASH: Barcha yuklab olingan va o'rnatilgan APK axlatlarini bitta bosishda tozalash
     */
    private fun cleanAllDownloadedApkTrash(): Map<String, Any?> {
        var totalBytesFreed = 0L
        var deletedFilesCount = 0

        val candidateDirs = listOf(
            File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "Telegram"),
            android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS),
            File(android.os.Environment.getExternalStorageDirectory(), "Telegram/Telegram Documents"),
            cacheDir
        )

        for (dir in candidateDirs) {
            if (dir.exists() && dir.isDirectory) {
                val files = dir.listFiles { f -> f.isFile && f.name.endsWith(".apk", ignoreCase = true) }
                if (files != null) {
                    for (f in files) {
                        try {
                            val len = f.length()
                            if (f.delete()) {
                                totalBytesFreed += len
                                deletedFilesCount++
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
        }

        val res = mutableMapOf<String, Any?>()
        res["deletedCount"] = deletedFilesCount
        res["bytesFreed"] = totalBytesFreed
        res["mbFreed"] = String.format(java.util.Locale.US, "%.1f", totalBytesFreed.toDouble() / (1024 * 1024))
        return res
    }
}

