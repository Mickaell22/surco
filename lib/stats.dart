import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'library.dart';

/// Una escucha: que cancion, cuando empezo y cuanto se oyo de verdad.
class PlayEvent {
  PlayEvent(this.path, this.at, this.ms);
  final String path;
  final DateTime at;
  final int ms;
}

class SongCount {
  SongCount(this.song, this.plays, this.ms);
  final Song song;
  final int plays, ms;
}

class NameCount {
  NameCount(this.name, this.plays, this.ms);
  final String name;
  final int plays, ms;
}

/// Historial local de escuchas. Solo vive en el telefono.
class Stats extends ChangeNotifier {
  final List<PlayEvent> events = [];
  File? _file;

  // ponytail: todo el historial en memoria y reescritura completa del JSON al
  // guardar. 10.000 escuchas son ~600 KB; si algun dia pesa, pasar a append.
  Future<void> load() async {
    _file = File('${(await getApplicationSupportDirectory()).path}/stats.json');
    if (!await _file!.exists()) return;
    try {
      for (final e in jsonDecode(await _file!.readAsString()) as List) {
        events.add(PlayEvent(e[0], DateTime.fromMillisecondsSinceEpoch(e[1]), e[2]));
      }
    } catch (_) {}
  }

  /// Regla de Last.fm: cuenta si se oyo la mitad de la cancion o 4 minutos (lo
  /// que llegue primero). Saltar una cancion que no gusta no la suma. Pistas de
  /// menos de 30 s nunca cuentan. Si no se conoce la duracion, exige 4 minutos.
  /// [listenedMs] es tiempo realmente sonado: adelantar con la barra no lo infla.
  void record(Song s, DateTime at, int listenedMs) {
    if (s.durationMs > 0 && s.durationMs < 30000) return;
    final threshold = s.durationMs > 0 ? (s.durationMs ~/ 2).clamp(0, 240000) : 240000;
    if (listenedMs < threshold) return;
    events.add(PlayEvent(s.path, at, listenedMs));
    notifyListeners();
    _file?.writeAsString(jsonEncode([
      for (final e in events) [e.path, e.at.millisecondsSinceEpoch, e.ms]
    ]));
  }

  Future<void> clear() async {
    events.clear();
    notifyListeners();
    await _file?.writeAsString('[]');
  }

  Iterable<PlayEvent> since(Duration? window) {
    if (window == null) return events;
    final from = DateTime.now().subtract(window);
    return events.where((e) => e.at.isAfter(from));
  }

  List<SongCount> topSongs(Map<String, Song> byPath, {Duration? window, int limit = 50}) {
    final plays = <String, int>{}, ms = <String, int>{};
    for (final e in since(window)) {
      plays[e.path] = (plays[e.path] ?? 0) + 1;
      ms[e.path] = (ms[e.path] ?? 0) + e.ms;
    }
    final out = [
      for (final p in plays.keys)
        if (byPath[p] != null) SongCount(byPath[p]!, plays[p]!, ms[p]!)
    ]..sort((a, b) => b.plays != a.plays ? b.plays - a.plays : b.ms - a.ms);
    return out.take(limit).toList();
  }

  List<NameCount> topArtists(Map<String, Song> byPath, {Duration? window, int limit = 10}) {
    final plays = <String, int>{}, ms = <String, int>{};
    for (final e in since(window)) {
      final a = byPath[e.path]?.artist;
      if (a == null) continue;
      plays[a] = (plays[a] ?? 0) + 1;
      ms[a] = (ms[a] ?? 0) + e.ms;
    }
    final out = [for (final a in plays.keys) NameCount(a, plays[a]!, ms[a]!)]
      ..sort((a, b) => b.plays != a.plays ? b.plays - a.plays : b.ms - a.ms);
    return out.take(limit).toList();
  }

  /// Minutos escuchados por dia de la semana (lunes = 0).
  List<int> minutesByWeekday({Duration? window}) {
    final out = List.filled(7, 0);
    for (final e in since(window)) {
      out[e.at.weekday - 1] += e.ms;
    }
    return [for (final ms in out) ms ~/ 60000];
  }

  int playsOf(String path) => events.where((e) => e.path == path).length;

  Map<String, int> playCounts() {
    final m = <String, int>{};
    for (final e in events) {
      m[e.path] = (m[e.path] ?? 0) + 1;
    }
    return m;
  }

  List<Song> recent(Map<String, Song> byPath, {int limit = 50}) {
    final seen = <String>{};
    final out = <Song>[];
    for (final e in events.reversed) {
      final s = byPath[e.path];
      if (s != null && seen.add(e.path)) out.add(s);
      if (out.length >= limit) break;
    }
    return out;
  }
}
