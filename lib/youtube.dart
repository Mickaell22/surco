import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'mp4tags.dart';
import 'native.dart';

/// Descargas de YouTube: solo audio AAC en .m4a, el único formato al que se le
/// pueden meter portada y letra dentro del archivo (opus/webm no).
// ponytail: YouTube cambia su sistema seguido; si deja de bajar, actualizar
// youtube_explode_dart es casi siempre todo el arreglo.

typedef VideoInfo = ({Video video, List<AudioOnlyStreamInfo> streams});

/// Extrae el link de un texto compartido ("Mira esto https://youtu.be/...").
String? findYoutubeUrl(String text) {
  final m = RegExp(r'https?://\S*(youtube\.com|youtu\.be)\S*').firstMatch(text);
  final url = m?.group(0) ?? text.trim();
  return VideoId.parseVideoId(url) == null ? null : url;
}

Future<VideoInfo> fetchInfo(String url) async {
  final yt = YoutubeExplode();
  try {
    final video = await yt.videos.get(url);
    final manifest = await yt.videos.streams.getManifest(video.id);
    final streams = manifest.audioOnly.where((s) => s.container == StreamContainer.mp4).toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return (video: video, streams: streams);
  } finally {
    yt.close();
  }
}

/// Título y artista a partir del video: "Artista - Canción (Official Video)"
/// queda en Artista / Canción; los canales "X - Topic" o "XVEVO" dan el artista.
({String title, String artist}) guessTags(String videoTitle, String author) {
  final noise = RegExp(
    r'\s*[\(\[][^\)\]]*(official|oficial|video|audio|lyric|letra|visuali[sz]er|music|mv|hd|4k|remaster)[^\)\]]*[\)\]]',
    caseSensitive: false,
  );
  var title = videoTitle.replaceAll(noise, '').trim();
  var artist = author.replaceAll(RegExp(r'\s*-\s*Topic$|VEVO$|\s*Official$', caseSensitive: false), '').trim();
  final dash = RegExp(r'\s+[-–—]\s+').firstMatch(title);
  if (dash != null) {
    artist = title.substring(0, dash.start).trim();
    title = title.substring(dash.end).trim();
  }
  return (title: title, artist: artist);
}

/// YouTube no entregó el audio completo de este video.
class YoutubeBlocked implements Exception {
  const YoutubeBlocked();

  @override
  String toString() =>
      'YouTube bloqueó la descarga de este video (pide una verificación anti-bots). Prueba con otra versión de '
      'la canción, por ejemplo la de YouTube Music, o bájala desde la PC.';
}

/// Baja el audio a un archivo temporal. [onProgress] va de 0 a 1.
Future<File> downloadAudio(AudioOnlyStreamInfo stream, void Function(double) onProgress) async {
  final file = File('${(await getTemporaryDirectory()).path}/yt-${DateTime.now().millisecondsSinceEpoch}.m4a');
  final yt = YoutubeExplode();
  final sink = file.openWrite();
  var got = 0;
  final total = stream.size.totalBytes;
  // Si YouTube niega el audio (videos que exigen verificación anti-bots), el
  // paquete vuelve a pedir el manifiesto en bucle sin entregar nada. Sin datos
  // en 20 s se corta con un aviso. Se escucha a mano y se cancela sin esperar:
  // un `await for` esperaría a que ese bucle termine, y nunca termina.
  final done = Completer<void>();
  Timer? idle;
  void fail(Object e) => done.isCompleted ? null : done.completeError(e);
  void arm() {
    idle?.cancel();
    idle = Timer(const Duration(seconds: 20), () => fail(const YoutubeBlocked()));
  }

  final sub = yt.videos.streams
      .get(stream)
      .listen(
        (chunk) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress(got / total);
          arm();
        },
        onError: fail,
        onDone: () => got < total ? fail(const YoutubeBlocked()) : done.complete(),
        cancelOnError: true,
      );
  arm();
  try {
    await done.future;
  } catch (_) {
    await sink.close();
    if (file.existsSync()) file.deleteSync();
    rethrow;
  } finally {
    idle?.cancel();
    unawaited(sub.cancel());
    yt.close();
  }
  await sink.close();
  return file;
}

Future<Uint8List?> _get(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final res = await (await client.getUrl(url)).close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final b = BytesBuilder(copy: false);
    await for (final c in res) {
      b.add(c);
    }
    return b.toBytes();
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Miniatura del video recortada al cuadrado (la parte del centro).
Future<Uint8List?> fetchCover(Video v) async {
  for (final url in [v.thumbnails.maxResUrl, v.thumbnails.highResUrl]) {
    final bytes = await _get(Uri.parse(url));
    if (bytes != null && bytes.length > 2000) return squareJpeg(bytes);
  }
  return null;
}

/// Letra de lrclib.net (sincronizada si la hay), la misma fuente que la música
/// bajada en la PC. lrclib es abierta y tiene entradas basura ("probe"): se
/// descartan las cortas y se prefiere la de duración parecida con más texto.
Future<String?> fetchLyrics(String title, String artist, Duration duration) async {
  final q = {'track_name': title, 'artist_name': artist, 'duration': '${duration.inSeconds}'};
  final exact = await _get(Uri.https('lrclib.net', '/api/get', q));
  if (exact != null) {
    final l = bestLyrics([jsonDecode(utf8.decode(exact))], duration);
    if (l != null) return l;
  }
  final found = await _get(Uri.https('lrclib.net', '/api/search', {'track_name': title, 'artist_name': artist}));
  return found == null ? null : bestLyrics(jsonDecode(utf8.decode(found)) as List, duration);
}

/// Elige entre resultados de lrclib: duración a ±5 s, con texto de verdad
/// (sin marcas de tiempo, al menos 80 caracteres); sincronizada antes que plana.
String? bestLyrics(List<dynamic> results, Duration duration) {
  int textLength(String l) => l.replaceAll(RegExp(r'\[\d+:\d+(\.\d+)?\]'), '').trim().length;
  String? best;
  var bestScore = 0;
  for (final r in results.cast<Map<String, dynamic>>()) {
    final d = (r['duration'] as num?)?.toDouble();
    if (d != null && duration > Duration.zero && (d - duration.inSeconds).abs() > 5) continue;
    for (final (key, bonus) in [('syncedLyrics', 1 << 20), ('plainLyrics', 0)]) {
      final l = (r[key] as String?)?.trim();
      if (l == null || textLength(l) < 80) continue;
      final score = bonus + textLength(l);
      if (score > bestScore) (best, bestScore) = (l, score);
    }
  }
  return best;
}

/// Año de publicación del disco, solo si YouTube Music lo dice en la
/// descripción ("Released on: 1987-07-27"). El año de subida del video no sirve.
String? releaseYear(String description) => RegExp(r'Released on:\s*(\d{4})').firstMatch(description)?.group(1);

/// Recorta, etiqueta y guarda en Music/Surco. Devuelve la ruta final.
Future<String> saveDownload({
  required File source,
  required Duration start,
  required Duration? end,
  required Mp4Tags tags,
}) async {
  final dir = Directory('${await musicDir()}/Surco')..createSync(recursive: true);
  final name = '${tags.artist} - ${tags.title}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  var out = File('${dir.path}/$name.m4a');
  for (var i = 2; out.existsSync(); i++) {
    out = File('${dir.path}/$name ($i).m4a');
  }
  final trimmed = File('${source.path}.cut.m4a');
  try {
    // Siempre por el recorte nativo: además deja un MP4 común (YouTube manda
    // uno fragmentado, donde no se pueden escribir etiquetas).
    await trimAudio(source.path, trimmed.path, start, end);
    await out.writeAsBytes(writeMp4Tags(await trimmed.readAsBytes(), tags), flush: true);
  } finally {
    if (trimmed.existsSync()) trimmed.deleteSync();
  }
  await scanFile(out.path);
  return out.path;
}
