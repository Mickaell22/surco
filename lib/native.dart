import 'package:flutter/services.dart';

import 'library.dart';

/// Lo poco que Flutter no trae, hecho en Kotlin (MainActivity) sin paquetes.
const _channel = MethodChannel('surco/native');

/// Surco abrió una pantalla de Android (compartir, selector de carpetas,
/// instalador): volver de ahí no es "abrir la app" y no debe cambiar el tema.
bool openedSystemScreen = false;

Future<T?> _system<T>(String method, [Object? args]) {
  openedSystemScreen = true;
  return _channel.invokeMethod<T>(method, args);
}

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
    _system('share', {'path': s.path, 'mime': _mime(s.path), 'title': '${s.title} · ${s.artist}'});

/// Abre el selector de carpetas de Android (SD, USB, Drive...). Devuelve la
/// carpeta elegida o null si se canceló.
Future<String?> pickFolder() => _system<String>('pickFolder');

/// Resultado de un backup: copiadas, ya estaban (mismo tamaño) y fallidas.
typedef BackupResult = ({int copied, int skipped, int failed});

/// Copia [files] a una carpeta "Surco" dentro de [tree]. [onProgress] recibe
/// (hechas, total) a medida que avanza; corre en un hilo nativo.
Future<BackupResult> backup(String tree, List<String> files, void Function(int done, int total) onProgress) async {
  _onBackupProgress = onProgress;
  try {
    final r = (await _channel.invokeMapMethod<String, int>('backup', {'tree': tree, 'files': files}))!;
    return (copied: r['copied']!, skipped: r['skipped']!, failed: r['failed']!);
  } finally {
    _onBackupProgress = null;
  }
}

void Function(int done, int total)? _onBackupProgress;

/// Recibe lo que manda Kotlin por su cuenta: progreso del backup y links
/// compartidos con la app ya abierta. [onShared] recibe el texto compartido.
Future<void> listenNative({required void Function(String text) onShared}) async {
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'backupProgress':
        _onBackupProgress?.call(call.arguments['done'] as int, call.arguments['total'] as int);
      case 'shared':
        onShared(call.arguments as String);
    }
  });
  // Texto con el que se abrió la app desde "Compartir", si lo hubo.
  if (await _channel.invokeMethod<String>('sharedText') case final text?) onShared(text);
}

/// Arquitectura principal del teléfono (arm64-v8a, armeabi-v7a, x86_64).
Future<String> primaryAbi() async => (await _channel.invokeMethod<String>('abi')) ?? 'arm64-v8a';

/// Abre el instalador de Android con un APK ya descargado.
Future<void> installApk(String path) => _system('installApk', {'path': path});

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
