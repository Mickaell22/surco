package com.mickaell.surco

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
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * Modo manos libres con Vosk: reconocimiento sin internet, leyendo el micrófono
 * directo (sin pedir el foco de audio, así la música no se corta ni baja) y
 * con vocabulario cerrado ([EXTRA_GRAMMAR]: "surco", comandos, artistas,
 * listas), que lo hace preciso aun con ruido. Servicio en primer plano de tipo
 * micrófono para seguir con la pantalla apagada.
 */
class ListenService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var speech: SpeechService? = null
    private var model: Model? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification())
        }
        running = true
        if (speech == null) {
            val grammar = intent?.getStringExtra(EXTRA_GRAMMAR) ?: "[]"
            // Cargar el modelo tarda un par de segundos: fuera del hilo principal.
            Thread {
                try {
                    val m = Model(modelDir(this).path)
                    val s = SpeechService(Recognizer(m, 16000f, grammar), 16000f)
                    main.post {
                        if (!running) {
                            s.shutdown(); m.close(); return@post
                        }
                        model = m
                        speech = s
                        s.startListening(listener)
                    }
                } catch (e: Exception) {
                    main.post { stopSelf() }
                }
            }.start()
        }
        return START_NOT_STICKY
    }

    private val listener = object : RecognitionListener {
        override fun onResult(hypothesis: String?) {
            val text = hypothesis?.let { JSONObject(it).optString("text") }.orEmpty()
            if (text.isNotBlank()) onText?.invoke(listOf(text))
        }

        override fun onFinalResult(hypothesis: String?) = onResult(hypothesis)
        override fun onPartialResult(hypothesis: String?) {}
        override fun onError(exception: Exception?) {
            stopSelf()
        }

        override fun onTimeout() {}
    }

    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Manos libres", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val stop = PendingIntent.getService(
            this, 0, Intent(this, ListenService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Surco te escucha")
            .setContentText("Di «Surco, siguiente», «Surco, pausa»…")
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Desactivar", stop).build())
            .build()
    }

    override fun onDestroy() {
        running = false
        speech?.stop()
        speech?.shutdown()
        speech = null
        model?.close()
        model = null
        onStopped?.invoke()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.mickaell.surco.LISTEN_STOP"
        const val EXTRA_GRAMMAR = "grammar"
        private const val CHANNEL = "manos-libres"
        private const val NOTIFICATION_ID = 7301

        /** Modelo pequeño de español de Vosk (Apache 2.0). */
        private const val MODEL_URL = "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip"

        var running = false
        var onText: ((List<String>) -> Unit)? = null
        var onStopped: (() -> Unit)? = null

        fun modelDir(context: Context) = File(context.filesDir, "vosk-es")

        fun modelReady(context: Context) = File(modelDir(context), "am/final.mdl").exists()

        /**
         * Baja y descomprime el modelo en files/vosk-es (se hace una sola vez).
         * [progress] recibe de 0 a 1. Descomprime en una carpeta temporal y la
         * renombra al final: un corte a mitad no deja un modelo roto.
         */
        fun downloadModel(context: Context, progress: (Double) -> Unit) {
            val tmp = File(context.filesDir, "vosk-es.tmp").apply { deleteRecursively(); mkdirs() }
            val conn = URL(MODEL_URL).openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            try {
                val total = conn.contentLengthLong.coerceAtLeast(1)
                var read = 0L
                val counted = object : java.io.FilterInputStream(conn.inputStream) {
                    override fun read(b: ByteArray, off: Int, len: Int): Int =
                        super.read(b, off, len).also { if (it > 0) { read += it; progress(read.toDouble() / total) } }
                }
                ZipInputStream(counted.buffered()).use { zip ->
                    while (true) {
                        val entry = zip.nextEntry ?: break
                        // El zip trae una carpeta raíz (vosk-model-small-es-0.42/): se quita.
                        val rel = entry.name.substringAfter('/', "")
                        if (rel.isEmpty()) continue
                        val out = File(tmp, rel)
                        if (!out.canonicalPath.startsWith(tmp.canonicalPath)) continue
                        if (entry.isDirectory) out.mkdirs() else {
                            out.parentFile?.mkdirs()
                            out.outputStream().use { zip.copyTo(it) }
                        }
                    }
                }
            } finally {
                conn.disconnect()
            }
            val dir = modelDir(context)
            dir.deleteRecursively()
            if (!tmp.renameTo(dir)) throw IllegalStateException("No se pudo guardar el modelo")
        }

        fun grammar(phrases: List<String>): String = JSONArray(phrases + "[unk]").toString()
    }
}
