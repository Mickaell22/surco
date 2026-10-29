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
