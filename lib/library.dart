import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const audioExt = {'.mp3', '.m4a', '.aac', '.flac', '.ogg', '.opus', '.wav'};
const playlistExt = {'.m3u', '.m3u8'};

class Song {
  Song({
    required this.path,
    required this.mtime,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.cover,
    this.hasLyrics = false,
  });

  final String path;
  final int mtime;
  final String title, artist, album;
  final int durationMs;
  final String? cover; // portada extraida a la cache (jpg/png en disco)
  final bool hasLyrics;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'p': path, 'm': mtime, 't': title, 'a': artist, 'b': album,
        'd': durationMs, 'c': cover, 'l': hasLyrics,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        path: j['p'], mtime: j['m'], title: j['t'], artist: j['a'], album: j['b'],
        durationMs: j['d'], cover: j['c'], hasLyrics: j['l'] ?? false,
      );
}

class Playlist {
  Playlist(this.name, this.songs);
  final String name;
  final List<Song> songs;
}

/// Biblioteca local: escanea el almacenamiento, guarda una cache JSON y
/// solo re-lee los archivos nuevos o modificados.
class Library extends ChangeNotifier {
  List<Song> songs = [];
  List<Playlist> playlists = [];
  bool scanning = false;
  String? error;

  late final Directory _cacheDir;
  File get _cacheFile => File('${_cacheDir.path}/library.json');

  Future<void> load() async {
    _cacheDir = await getApplicationSupportDirectory();
    if (await _cacheFile.exists()) {
      try {
        final raw = jsonDecode(await _cacheFile.readAsString()) as List;
        songs = raw.map((e) => Song.fromJson(e)).toList();
        notifyListeners();
      } catch (_) {/* cache corrupta: se reconstruye en el scan */}
    }
    await scan();
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final known = {for (final s in songs) s.path: s};
      final coverDir = '${_cacheDir.path}/covers';
      final result = await Isolate.run(() => _scanIsolate(_roots, known, coverDir));
      songs = result.$1..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final byPath = {for (final s in songs) s.path: s};
      playlists = [
        for (final p in result.$2) _readPlaylist(p, byPath),
      ].where((p) => p.songs.isNotEmpty).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _cacheFile.writeAsString(jsonEncode(songs.map((s) => s.toJson()).toList()));
    } catch (e) {
      error = '$e';
    }
    scanning = false;
    notifyListeners();
  }

  Map<String, List<Song>> get byArtist => _group((s) => s.artist);
  Map<String, List<Song>> get byAlbum => _group((s) => s.album);

  Map<String, List<Song>> _group(String Function(Song) key) {
    final m = <String, List<Song>>{};
    for (final s in songs) {
      m.putIfAbsent(key(s), () => []).add(s);
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())));
  }

  /// Letra embebida en el archivo; se lee bajo demanda para no tenerla en RAM.
  static Future<String?> lyricsOf(Song s) => Isolate.run(() {
        try {
          return readMetadata(File(s.path)).lyrics;
        } catch (_) {
          return null;
        }
      });
}

// ponytail: raiz fija del almacenamiento compartido de Android. Si algun dia
// hace falta una SD externa, se agrega aqui (o un selector de carpetas).
const _roots = ['/storage/emulated/0'];
const _skipDirs = {'Android', 'DCIM', 'Pictures', 'Movies'};

(List<Song>, List<String>) _scanIsolate(List<String> roots, Map<String, Song> known, String coverDir) {
  Directory(coverDir).createSync(recursive: true);
  final songs = <Song>[];
  final lists = <String>[];

  void walk(Directory d, int depth) {
    List<FileSystemEntity> entries;
    try {
      entries = d.listSync(followLinks: false);
    } catch (_) {
      return; // carpeta sin permiso
    }
    for (final e in entries) {
      final name = e.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (name.startsWith('.')) continue;
      if (e is Directory) {
        if (depth == 0 && _skipDirs.contains(name)) continue;
        if (depth < 8) walk(e, depth + 1);
      } else if (e is File) {
        final ext = _ext(name);
        if (playlistExt.contains(ext)) {
          lists.add(e.path);
        } else if (audioExt.contains(ext)) {
          final s = _readSong(e, known[e.path], coverDir);
          if (s != null) songs.add(s);
        }
      }
    }
  }

  for (final r in roots) {
    walk(Directory(r), 0);
  }
  return (songs, lists);
}

Song? _readSong(File f, Song? cached, String coverDir) {
  int mtime;
  try {
    mtime = f.lastModifiedSync().millisecondsSinceEpoch;
  } catch (_) {
    return null;
  }
  if (cached != null && cached.mtime == mtime) return cached;

  final fallback = _ext(f.path).isEmpty ? f.path : f.path.substring(0, f.path.length - _ext(f.path).length);
  final baseName = fallback.split('/').last;
  try {
    final m = readMetadata(f, getImage: true);
    String? cover;
    if (m.pictures.isNotEmpty) {
      final pic = m.pictures.first;
      final ext = pic.mimetype.contains('png') ? 'png' : 'jpg';
      final out = File('$coverDir/${f.path.hashCode.toUnsigned(32)}_$mtime.$ext');
      if (!out.existsSync()) out.writeAsBytesSync(pic.bytes);
      cover = out.path;
    }
    final artist = (m.artist ?? m.albumArtist ?? '').trim();
    return Song(
      path: f.path,
      mtime: mtime,
      title: (m.title ?? '').trim().isEmpty ? baseName : m.title!.trim(),
      artist: artist.isEmpty ? 'Artista desconocido' : artist,
      album: (m.album ?? '').trim().isEmpty ? 'Sin album' : m.album!.trim(),
      durationMs: m.duration?.inMilliseconds ?? 0,
      cover: cover,
      hasLyrics: (m.lyrics ?? '').trim().isNotEmpty,
    );
  } catch (_) {
    // Archivo sin tags legibles: igual se puede reproducir.
    return Song(path: f.path, mtime: mtime, title: baseName, artist: 'Artista desconocido', album: 'Sin album', durationMs: 0);
  }
}

Playlist _readPlaylist(String path, Map<String, Song> byPath) {
  final dir = File(path).parent.path;
  final name = path.split('/').last.replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), '');
  final songs = <Song>[];
  try {
    for (var line in File(path).readAsLinesSync()) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final full = line.startsWith('/') ? line : File('$dir/$line').absolute.uri.normalizePath().toFilePath();
      final s = byPath[full];
      if (s != null) songs.add(s);
    }
  } catch (_) {}
  return Playlist(name, songs);
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i).toLowerCase();
}
