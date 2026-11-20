package com.afifsuda.canvas

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.afifsuda.canvas/audio"
        private const val EVENT_CHANNEL = "com.afifsuda.canvas/audio_stream"
        private const val PREFS_NAME = "agy_prefs"
        private const val KEY_ROOM = "last_room"
        private const val REQ_MIC_PERMISSION = 1001
        private const val REQ_NOTIF_PERMISSION = 1002
        private const val REQ_MEDIA_PROJECTION = 1003
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_BYTES = 1280 // 40ms @ 16kHz 16-bit mono
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val playbackExecutor = Executors.newSingleThreadExecutor()

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermResult: MethodChannel.Result? = null
    private var pendingMusicResult: MethodChannel.Result? = null
    private var mediaProjection: MediaProjection? = null

    @Volatile
    private var isCapturing = false
    private var audioRecord: AudioRecord? = null
    private var noiseSuppressor: NoiseSuppressor? = null
    private var echoCanceler: AcousticEchoCanceler? = null
    private var captureThread: Thread? = null

    private val playbackLock = Any()
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSavedRoom" -> {
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        result.success(prefs.getString(KEY_ROOM, "1234") ?: "1234")
                    }
                    "saveRoom" -> {
                        val room = (call.arguments as? String)?.trim()
                        if (!room.isNullOrEmpty()) {
                            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                                .edit()
                                .putString(KEY_ROOM, room)
                                .apply()
                        }
                        result.success(true)
                    }
                    "startKeepAlive" -> {
                        val room = (call.arguments as? String) ?: "1234"
                        requestNotificationPermissionIfNeeded()
                        val intent = Intent(this, KeepAliveService::class.java).apply {
                            action = KeepAliveService.ACTION_START
                            putExtra(KeepAliveService.EXTRA_ROOM, room)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopKeepAlive" -> {
                        val intent = Intent(this, KeepAliveService::class.java).apply {
                            action = KeepAliveService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "hasMicPermission" -> {
                        result.success(hasRecordAudioPermission())
                    }
                    "requestMicPermission" -> {
                        if (hasRecordAudioPermission()) {
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pendingPermResult?.success(false)
                            pendingPermResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_MIC_PERMISSION
                            )
                        } else {
                            result.success(true)
                        }
                    }
                    "startCapture" -> {
                        if (!hasRecordAudioPermission()) {
                            result.error("NO_PERMISSION", "Izin mikrofon belum diberikan", null)
                        } else {
                            startAudioCapture()
                            result.success(true)
                        }
                    }
                    "stopCapture" -> {
                        stopAudioCapture()
                        result.success(true)
                    }
                    "isInternalAudioSupported" -> {
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    }
                    "startMusicCapture" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.error("UNSUPPORTED", "Butuh Android 10+ untuk rekam audio internal", null)
                        } else if (!hasRecordAudioPermission()) {
                            result.error("NO_PERMISSION", "Izin mikrofon/audio belum diberikan", null)
                        } else {
                            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            pendingMusicResult?.success(false)
                            pendingMusicResult = result
                            startActivityForResult(mgr.createScreenCaptureIntent(), REQ_MEDIA_PROJECTION)
                        }
                    }
                    "stopMusicCapture" -> {
                        stopAudioCapture()
                        mediaProjection?.stop()
                        mediaProjection = null
                        result.success(true)
                    }
                    "startPlayback" -> {
                        startAudioPlayback()
                        result.success(true)
                    }
                    "writePlayback" -> {
                        val bytes = call.arguments as? ByteArray
                        if (bytes != null && bytes.isNotEmpty()) {
                            writeAudioPlayback(bytes)
                        }
                        result.success(true)
                    }
                    "stopPlayback" -> {
                        stopAudioPlayback()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_NOTIF_PERMISSION
                )
            }
        }
    }

    private fun hasRecordAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MIC_PERMISSION) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermResult?.success(granted)
            pendingPermResult = null
        }
    }

    private fun startAudioCapture() {
        if (isCapturing) return
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuf, CHUNK_BYTES * 4)

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        } catch (_: Throwable) {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return
        }

        try {
            if (NoiseSuppressor.isAvailable()) {
                noiseSuppressor = NoiseSuppressor.create(record.audioSessionId)?.apply {
                    enabled = true
                }
            }
            if (AcousticEchoCanceler.isAvailable()) {
                echoCanceler = AcousticEchoCanceler.create(record.audioSessionId)?.apply {
                    enabled = true
                }
            }
        } catch (_: Throwable) {
        }

        audioRecord = record
        isCapturing = true
        record.startRecording()

        captureThread = Thread {
            val buf = ByteArray(CHUNK_BYTES)
            while (isCapturing) {
                val read = record.read(buf, 0, buf.size)
                if (read > 0) {
                    val copy = buf.copyOf(read)
                    mainHandler.post {
                        eventSink?.success(copy)
                    }
                }
            }
        }.apply {
            name = "AgyAudioCapture"
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun stopAudioCapture() {
        isCapturing = false
        try {
            captureThread?.join(200)
        } catch (_: InterruptedException) {
        }
        captureThread = null
        try {
            noiseSuppressor?.release()
        } catch (_: Throwable) {
        }
        noiseSuppressor = null
        try {
            echoCanceler?.release()
        } catch (_: Throwable) {
        }
        echoCanceler = null
        try {
            audioRecord?.stop()
        } catch (_: Throwable) {
        }
        try {
            audioRecord?.release()
        } catch (_: Throwable) {
        }
        audioRecord = null
    }

    private fun startAudioPlayback() {
        synchronized(playbackLock) {
            if (audioTrack != null) return
            val minBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = maxOf(minBuf, CHUNK_BYTES * 4)
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            track.play()
            audioTrack = track
        }
    }

    private fun writeAudioPlayback(bytes: ByteArray) {
        playbackExecutor.execute {
            synchronized(playbackLock) {
                val track = audioTrack ?: return@execute
                try {
                    track.write(bytes, 0, bytes.size)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun stopAudioPlayback() {
        synchronized(playbackLock) {
            val track = audioTrack ?: return
            audioTrack = null
            try {
                track.pause()
                track.flush()
                track.release()
            } catch (_: Throwable) {
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val projection = mgr.getMediaProjection(resultCode, data)
                if (projection != null) {
                    mediaProjection = projection
                    val started = startInternalAudioCapture(projection)
                    pendingMusicResult?.success(started)
                } else {
                    pendingMusicResult?.success(false)
                }
            } else {
                pendingMusicResult?.success(false)
            }
            pendingMusicResult = null
        }
    }

    private fun startInternalAudioCapture(projection: MediaProjection): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        stopAudioCapture()

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuf, CHUNK_BYTES * 4)

        val record = try {
            AudioRecord.Builder()
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setAudioPlaybackCaptureConfig(config)
                .build()
        } catch (_: Throwable) {
            return false
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return false
        }

        audioRecord = record
        isCapturing = true
        record.startRecording()

        captureThread = Thread {
            val buf = ByteArray(CHUNK_BYTES)
            while (isCapturing) {
                val read = record.read(buf, 0, buf.size)
                if (read > 0) {
                    val copy = buf.copyOf(read)
                    mainHandler.post {
                        eventSink?.success(copy)
                    }
                }
            }
        }.apply {
            name = "AgyMusicCapture"
            priority = Thread.MAX_PRIORITY
            start()
        }
        return true
    }

    override fun onDestroy() {
        stopAudioCapture()
        mediaProjection?.stop()
        mediaProjection = null
        stopAudioPlayback()
        playbackExecutor.shutdownNow()
        super.onDestroy()
    }
}
