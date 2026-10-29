package com.mickaell.surco

import android.content.Intent
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// AudioServiceActivity: necesaria para que just_audio_background maneje la
// notificacion y los botones de medios (audifonos Bluetooth).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Un solo canal para lo poco que Flutter no trae: compartir archivos.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "surco/native").setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
        }
    }
}
