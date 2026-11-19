package com.afifsuda.canvas

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

object TunnelBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    var status: String = "stopped"
        private set
    var url: String? = null
        private set
    var message: String = "Tunnel nonaktif"
        private set

    var listener: ((Map<String, Any?>) -> Unit)? = null

    fun emit(newStatus: String, newUrl: String? = url, newMsg: String = message) {
        status = newStatus
        url = newUrl
        message = newMsg
        val payload = mapOf(
            "status" to status,
            "url" to url,
            "message" to message
        )
        mainHandler.post {
            listener?.invoke(payload)
        }
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "status" to status,
        "url" to url,
        "message" to message
    )
}

class TunnelService : Service() {
    companion object {
        const val ACTION_START = "com.afifsuda.canvas.START_TUNNEL"
        const val ACTION_STOP = "com.afifsuda.canvas.STOP_TUNNEL"
        private const val CHANNEL_ID = "antigravity_tunnel_channel"
        private const val NOTIF_ID = 4201
        private val TRYCLOUDFLARE_REGEX =
            Regex("""https://[a-zA-Z0-9-]+\.trycloudflare\.com""")
    }

    private var process: Process? = null
    private var readerThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null

    @Volatile
    private var stopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTunnelInternal()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startForegroundSafe("Menyiapkan Tunnel Publik...")
                startTunnelProcess()
                return START_STICKY
            }
        }
    }

    private fun startForegroundSafe(contentText: String) {
        ensureNotificationChannel()
        val notif = buildNotification(contentText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = nm.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "Antigravity Audio Tunnel",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Menjaga koneksi audio & tunnel tetap aktif di latar belakang"
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun buildNotification(text: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, piFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Antigravity Audio Host")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification(text))
    }

    private fun startTunnelProcess() {
        if (process?.isAlive == true) return
        stopping = false
        acquireWakeLock()
        TunnelBus.emit("starting", null, "Menghubungkan ke Cloudflare Tunnel...")

        val bin = File(applicationInfo.nativeLibraryDir, "libcloudflared.so")
        if (!bin.exists()) {
            TunnelBus.emit("error", null, "Binary cloudflared tidak ditemukan")
            stopSelf()
            return
        }

        try {
            val etcDir = File(filesDir, "etc")
            if (!etcDir.exists()) etcDir.mkdirs()
            File(etcDir, "resolv.conf").writeText(
                "options timeout:2 attempts:2\nnameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 8.8.4.4\n"
            )

            val pb = ProcessBuilder(
                bin.absolutePath,
                "tunnel",
                "--no-autoupdate",
                "--protocol", "http2",
                "--url", "http://127.0.0.1:8765"
            )
            pb.directory(filesDir)
            pb.environment()["HOME"] = filesDir.absolutePath
            pb.environment()["GODEBUG"] = "netdns=go"
            val apexCerts = File("/apex/com.android.conscrypt/cacerts")
            pb.environment()["SSL_CERT_DIR"] = if (apexCerts.isDirectory) {
                "/apex/com.android.conscrypt/cacerts:/system/etc/security/cacerts"
            } else {
                "/system/etc/security/cacerts"
            }
            pb.redirectErrorStream(true)

            val proc = pb.start()
            process = proc

            readerThread = Thread {
                var lastLine = ""
                try {
                    BufferedReader(InputStreamReader(proc.inputStream)).use { reader ->
                        while (!stopping) {
                            val text = reader.readLine() ?: break
                            if (text.isNotBlank()) {
                                lastLine = text.trim()
                            }
                            val match = TRYCLOUDFLARE_REGEX.find(text)
                            if (match != null) {
                                val foundUrl = match.value
                                TunnelBus.emit("running", foundUrl, "Tunnel aktif")
                                updateNotification("Aktif: $foundUrl")
                            }
                        }
                    }
                    val exitCode = proc.waitFor()
                    if (!stopping) {
                        val detail = if (lastLine.isNotEmpty()) " ($lastLine)" else ""
                        TunnelBus.emit("error", null, "Tunnel berhenti (exit $exitCode)$detail")
                    }
                } catch (e: Throwable) {
                    if (!stopping) {
                        TunnelBus.emit("error", null, "Tunnel error: ${e.message}")
                    }
                } finally {
                    releaseWakeLock()
                    if (!stopping) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                }
            }.apply {
                name = "CloudflaredReader"
                start()
            }
        } catch (e: Throwable) {
            TunnelBus.emit("error", null, "Gagal menjalankan tunnel: ${e.message}")
            releaseWakeLock()
            stopSelf()
        }
    }

    private fun stopTunnelInternal() {
        stopping = true
        try {
            process?.destroy()
            process?.destroyForcibly()
        } catch (_: Throwable) {
        }
        process = null
        readerThread?.interrupt()
        readerThread = null
        releaseWakeLock()
        TunnelBus.emit("stopped", null, "Tunnel dimatikan")
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "AntigravityCanvas::TunnelWakeLock"
                )
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(6 * 60 * 60 * 1000L)
            }
        } catch (_: Throwable) {
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Throwable) {
        }
    }

    override fun onDestroy() {
        stopTunnelInternal()
        super.onDestroy()
    }
}
