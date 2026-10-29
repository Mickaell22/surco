import 'package:flutter/services.dart';

import 'library.dart';

/// Lo poco que Flutter no trae, hecho en Kotlin (MainActivity) sin paquetes.
const _channel = MethodChannel('surco/native');

String _mime(String path) => switch (path.split('.').last.toLowerCase()) {
  'm4a' || 'mp4' || 'aac' => 'audio/mp4',
  'mp3' => 'audio/mpeg',
  'ogg' || 'opus' => 'audio/ogg',
  'flac' => 'audio/flac',
  'wav' => 'audio/wav',
  _ => 'audio/*',
};

/// Abre el menú de compartir de Android con el archivo de la canción.
Future<void> shareSong(Song s) =>
    _channel.invokeMethod('share', {'path': s.path, 'mime': _mime(s.path), 'title': '${s.title} · ${s.artist}'});

/// Abre el selector de carpetas de Android (SD, USB, Drive...). Devuelve la
/// carpeta elegida o null si se canceló.
Future<String?> pickFolder() => _channel.invokeMethod<String>('pickFolder');

/// Resultado de un backup: copiadas, ya estaban (mismo tamaño) y fallidas.
typedef BackupResult = ({int copied, int skipped, int failed});

/// Copia [files] a una carpeta "Surco" dentro de [tree]. [onProgress] recibe
/// (hechas, total) a medida que avanza; corre en un hilo nativo.
Future<BackupResult> backup(String tree, List<String> files, void Function(int done, int total) onProgress) async {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'backupProgress') onProgress(call.arguments['done'] as int, call.arguments['total'] as int);
  });
  try {
    final r = (await _channel.invokeMapMethod<String, int>('backup', {'tree': tree, 'files': files}))!;
    return (copied: r['copied']!, skipped: r['skipped']!, failed: r['failed']!);
  } finally {
    _channel.setMethodCallHandler(null);
  }
}

/// Arquitectura principal del teléfono (arm64-v8a, armeabi-v7a, x86_64).
Future<String> primaryAbi() async => (await _channel.invokeMethod<String>('abi')) ?? 'arm64-v8a';

/// Abre el instalador de Android con un APK ya descargado.
Future<void> installApk(String path) => _channel.invokeMethod('installApk', {'path': path});

/// Copia el audio de [input] a [output] entre [start] y [end] (null = hasta el
/// final), sin recomprimir. Siempre deja un MP4 normal, no fragmentado.
Future<void> trimAudio(String input, String output, Duration start, Duration? end) => _channel.invokeMethod('trim', {
  'input': input,
  'output': output,
  'startMs': start.inMilliseconds,
  'endMs': end?.inMilliseconds,
});

/// Recorta una imagen al cuadrado del centro y la deja en JPEG de hasta [size] px.
Future<Uint8List?> squareJpeg(Uint8List bytes, {int size = 720}) =>
    _channel.invokeMethod<Uint8List>('squareJpeg', {'bytes': bytes, 'size': size});

/// Avisa a Android de un archivo nuevo para que otras apps lo vean.
Future<void> scanFile(String path) => _channel.invokeMethod('scanFile', {'path': path});

/// Carpeta pública Music del teléfono (donde se guardan las descargas).
Future<String> musicDir() async => (await _channel.invokeMethod<String>('musicDir'))!;
