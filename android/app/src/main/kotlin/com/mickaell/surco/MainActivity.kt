package com.mickaell.surco

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer

// AudioServiceActivity: necesaria para que just_audio_background maneje la
// notificacion y los botones de medios (audifonos Bluetooth).
class MainActivity : AudioServiceActivity() {
    private lateinit var channel: MethodChannel
    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Un solo canal para lo poco que Flutter no trae: compartir y copiar archivos.
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "surco/native")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "share" -> {
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.archivos", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = call.argument<String>("mime")
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("title"))
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, call.argument<String>("title")))
                    result.success(null)
                }
                "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull())
                "musicDir" -> result.success(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC).path
                )
                "installApk" -> {
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.archivos", file)
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(null)
                }
                "trim" -> Thread {
                    try {
                        trim(
                            call.argument<String>("input")!!, call.argument<String>("output")!!,
                            call.argument<Number>("startMs")!!.toLong(), call.argument<Number>("endMs")?.toLong()
                        )
                        main.post { result.success(null) }
                    } catch (e: Exception) {
                        main.post { result.error("trim", e.message, null) }
                    }
                }.start()
                "squareJpeg" -> {
                    val bytes = call.argument<ByteArray>("bytes")!!
                    val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    if (src == null) result.success(null) else {
                        val side = minOf(src.width, src.height)
                        val crop = Bitmap.createBitmap(src, (src.width - side) / 2, (src.height - side) / 2, side, side)
                        val max = call.argument<Int>("size")!!
                        val out = if (side > max) Bitmap.createScaledBitmap(crop, max, max, true) else crop
                        val buf = ByteArrayOutputStream()
                        out.compress(Bitmap.CompressFormat.JPEG, 90, buf)
                        result.success(buf.toByteArray())
                    }
                }
                "scanFile" -> {
                    MediaScannerConnection.scanFile(this, arrayOf(call.argument<String>("path")!!), null, null)
                    result.success(null)
                }
                "pickFolder" -> {
                    pendingPick?.success(null)
                    pendingPick = result
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_FOLDER)
                }
                "backup" -> {
                    val tree = Uri.parse(call.argument<String>("tree")!!)
                    val files = call.argument<List<String>>("files")!!
                    Thread { backup(tree, files, result) }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult basta para un solo selector")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FOLDER) return
        val uri = data?.data
        if (resultCode == RESULT_OK && uri != null) {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        }
        pendingPick?.success(if (resultCode == RESULT_OK) uri?.toString() else null)
        pendingPick = null
    }

    /**
     * Copia [files] dentro de una carpeta "Surco" en [tree], conservando las
     * carpetas relativas al almacenamiento. Salta lo que ya esta con el mismo
     * tamano, asi repetir el backup en la misma carpeta solo copia lo nuevo.
     */
    private fun backup(tree: Uri, files: List<String>, result: MethodChannel.Result) {
        val root = Environment.getExternalStorageDirectory().path + "/"
        val dirs = HashMap<String, String>() // ruta relativa -> documentId
        val children = HashMap<String, Map<String, Long>>() // documentId -> nombre -> tamano
        var copied = 0
        var skipped = 0
        var failed = 0
        try {
            val base = child(tree, DocumentsContract.getTreeDocumentId(tree), "Surco", children, dir = true)
            dirs[""] = base
            files.forEachIndexed { i, path ->
                try {
                    val src = File(path)
                    val rel = if (path.startsWith(root)) path.removePrefix(root) else src.name
                    val parts = rel.split('/')
                    var parent = base
                    var key = ""
                    for (part in parts.dropLast(1)) {
                        key += "/$part"
                        parent = dirs.getOrPut(key) { child(tree, parent, part, children, dir = true) }
                    }
                    val name = parts.last()
                    if (list(tree, parent, children)[name] == src.length()) {
                        skipped++
                    } else {
                        val ext = name.substringAfterLast('.', "").lowercase()
                        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
                        val doc = DocumentsContract.createDocument(
                            contentResolver, DocumentsContract.buildDocumentUriUsingTree(tree, parent), mime, name
                        )!!
                        contentResolver.openOutputStream(doc)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
                        copied++
                    }
                } catch (e: Exception) {
                    failed++
                }
                val done = i + 1
                main.post { channel.invokeMethod("backupProgress", mapOf("done" to done, "total" to files.size)) }
            }
            val summary = mapOf("copied" to copied, "skipped" to skipped, "failed" to failed)
            main.post { result.success(summary) }
        } catch (e: Exception) {
            main.post { result.error("backup", e.message, null) }
        }
    }

    /**
     * Copia la pista de audio de [input] a un MP4 normal en [output], solo entre
     * [startMs] y [endMs] (null = hasta el final). No recomprime: copia las
     * muestras AAC tal cual, asi no pierde calidad. Tambien convierte el MP4
     * fragmentado de YouTube en uno comun, donde se pueden escribir etiquetas.
     */
    private fun trim(input: String, output: String, startMs: Long, endMs: Long?) {
        val ex = MediaExtractor()
        ex.setDataSource(input)
        val track = (0 until ex.trackCount).first {
            ex.getTrackFormat(it).getString(android.media.MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        }
        ex.selectTrack(track)
        val muxer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val out = muxer.addTrack(ex.getTrackFormat(track))
            muxer.start()
            ex.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val buf = ByteBuffer.allocate(1 shl 20)
            val info = MediaCodec.BufferInfo()
            var first = -1L
            while (true) {
                val n = ex.readSampleData(buf, 0)
                if (n < 0) break
                val t = ex.sampleTime
                if (endMs != null && t > endMs * 1000) break
                if (first < 0) first = t
                info.set(0, n, t - first, if (ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                muxer.writeSampleData(out, buf, info)
                ex.advance()
            }
            muxer.stop()
        } finally {
            muxer.release()
            ex.release()
        }
    }

    /** Hijos de una carpeta (nombre -> tamano), leidos una sola vez. */
    private fun list(tree: Uri, docId: String, cache: HashMap<String, Map<String, Long>>): Map<String, Long> =
        cache.getOrPut(docId) {
            val out = HashMap<String, Long>()
            contentResolver.query(
                DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId),
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_SIZE),
                null, null, null
            )?.use { c -> while (c.moveToNext()) out[c.getString(0)] = if (c.isNull(1)) -1 else c.getLong(1) }
            out
        }

    /** documentId de la subcarpeta [name] dentro de [parent]; la crea si no existe. */
    private fun child(
        tree: Uri, parent: String, name: String, cache: HashMap<String, Map<String, Long>>, dir: Boolean
    ): String {
        contentResolver.query(
            DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent),
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null
        )?.use { c -> while (c.moveToNext()) if (c.getString(1) == name) return c.getString(0) }
        val mime = if (dir) DocumentsContract.Document.MIME_TYPE_DIR else "application/octet-stream"
        val uri = DocumentsContract.createDocument(
            contentResolver, DocumentsContract.buildDocumentUriUsingTree(tree, parent), mime, name
        )!!
        cache.remove(parent)
        return DocumentsContract.getDocumentId(uri)
    }

    companion object {
        private const val PICK_FOLDER = 4107
    }
}
