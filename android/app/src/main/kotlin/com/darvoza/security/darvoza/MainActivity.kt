package com.darvoza.security.darvoza

import android.content.Intent
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
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.darvoza.security/apk_receiver"
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
                            installApkFile(path)
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

    private fun installApkFile(filePath: String) {
        val file = File(filePath)
        val apkUri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )

        isSelfTriggered = true

        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }

        // Tizimdagi standart o'rnatuvchini topish (Darvoza o'zini o'zi qayta chaqirmasligi uchun)
        val pm = packageManager
        val resolveInfos = pm.queryIntentActivities(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
            },
            PackageManager.MATCH_DEFAULT_ONLY
        )

        var targeted = false
        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            // Google yoki Android tizimining PackageInstaller ilovasi
            if (pkg.contains("packageinstaller") || pkg.contains("google.android.packageinstaller")) {
                intent.setClassName(pkg, info.activityInfo.name)
                targeted = true
                break
            }
        }

        if (!targeted) {
            intent.action = Intent.ACTION_VIEW
            intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
        }

        startActivity(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Agar o'zimiz tizimga o'rnatish uchun yuborgan bo'lsak, uni ushlab qolmaymiz
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
        if (isSelfTriggered) {
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
