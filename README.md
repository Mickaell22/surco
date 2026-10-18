# Surco

Reproductor de música local para Android, ligero y sin distracciones.

- Lee la música del teléfono (MP3, M4A, FLAC, OGG, Opus, WAV) con su portada, artista y álbum.
- Muestra la letra embebida en el archivo; si es sincronizada (LRC) sigue la línea actual y se puede tocar para saltar.
- Reproducción en segundo plano con notificación y controles de los audífonos Bluetooth.
- Canciones, artistas, álbumes y listas `.m3u` que estén junto a la música.
- Cola editable, reproducir a continuación, aleatorio, repetir y temporizador de apagado.
- Tema claro/oscuro según el sistema, con la paleta sobria del Facturador.

## Por qué es ligera

- Pocas dependencias: `just_audio` (+ `just_audio_background`), `audio_metadata_reader` (Dart puro), `permission_handler`, `path_provider`.
- Tipografía del sistema; no se descargan fuentes.
- Las portadas se extraen una vez a caché en disco y se decodifican al tamaño de la miniatura.
- El escaneo corre en un isolate y solo relee archivos nuevos o modificados (caché JSON).
- La letra se lee del archivo solo al abrirla.

## Desarrollo

```bash
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

El APK para la mayoría de teléfonos es `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Nota: `pubspec.yaml` fija `permission_handler_android` y `audio_session` a versiones compatibles con el AGP 8.11 de Flutter 3.38; las más nuevas exigen AGP 9.
