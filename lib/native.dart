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
