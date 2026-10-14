package com.darvoza.security.darvoza

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.FileObserver
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class ApkWatcherService : Service() {
    private val CHANNEL_ID = "vaultix_silent_guard_channel"
    private val NOTIF_ID = 1001
    private val observers = mutableListOf<FileObserver>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildForegroundNotification("Telegram va yuklamalar kuzatilmoqda..."))
        setupFileObservers()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Vaultix Doimiy Kiber-Qalqon",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Yangi yuklangan APK fayllarni real-vaqt rejimida ushlab qolish"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Vaultix Silent Watcher FAOL")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun setupFileObservers() {
        val candidateDirs = listOf(
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Telegram"),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            File(Environment.getExternalStorageDirectory(), "Telegram/Telegram Documents")
        )

        for (dir in candidateDirs) {
            if (dir.exists() && dir.isDirectory) {
                val observer = object : FileObserver(dir.absolutePath, CREATE or CLOSE_WRITE or MOVED_TO) {
                    override fun onEvent(event: Int, path: String?) {
                        if (path != null && path.endsWith(".apk", ignoreCase = true)) {
                            val fullPath = File(dir, path).absolutePath
                            notifyNewApkDetected(fullPath, path)
                        }
                    }
                }
                observer.startWatching()
                observers.add(observer)
            }
        }
    }

    private fun notifyNewApkDetected(fullPath: String, fileName: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            data = android.net.Uri.fromFile(File(fullPath))
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(), launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val alertNotif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⚠️ Yangi APK aniqlandi!")
            .setContentText("\"$fileName\" faylini ochishdan oldin tekshiring!")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify((System.currentTimeMillis() % 10000).toInt(), alertNotif)
    }

    override fun onDestroy() {
        for (observer in observers) {
            observer.stopWatching()
        }
        observers.clear()
        super.onDestroy()
    }
}
