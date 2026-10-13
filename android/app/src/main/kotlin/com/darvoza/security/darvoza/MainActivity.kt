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
}
