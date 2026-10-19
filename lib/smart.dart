import 'dart:math';

import 'library.dart';
import 'settings.dart';
import 'stats.dart';

/// Listas que se arman solas con el historial de escuchas. Las que aun no
/// tienen datos no se muestran (salvo "Agregadas recientemente").
List<Playlist> smartPlaylists(Library lib, Stats stats) {
  final week = stats.topSongs(lib.byPath, window: const Duration(days: 7), limit: 30);
  final allTime = stats.topSongs(lib.byPath, limit: 50);
  final recent = stats.recent(lib.byPath, limit: 50);
  final added = List.of(lib.songs)..sort((a, b) => b.mtime - a.mtime);
  final counts = stats.playCounts();
  // Semilla por dia: "Descubre" cambia cada dia pero no cada vez que se abre.
  final today = DateTime.now();
  final rnd = Random(today.year * 1000 + today.month * 40 + today.day);
  final unheard = lib.songs.where((s) => !counts.containsKey(s.path)).toList()..shuffle(rnd);

  return [
    if (week.isNotEmpty) Playlist('Lo mejor de la semana', [for (final c in week) c.song]),
    if (allTime.isNotEmpty) Playlist('Más escuchadas', [for (final c in allTime) c.song]),
    if (recent.isNotEmpty) Playlist('Escuchadas recientemente', recent),
    if (added.isNotEmpty) Playlist('Agregadas recientemente', added.take(50).toList()),
    if (unheard.isNotEmpty && stats.events.isNotEmpty) Playlist('Descubre: nunca escuchadas', unheard.take(30).toList()),
  ];
}

List<Song> sortSongs(List<Song> songs, SongSort by, Map<String, int> plays) {
  final out = List.of(songs);
  int title(Song a, Song b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  switch (by) {
    case SongSort.title:
      out.sort(title);
    case SongSort.artist:
      out.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : title(a, b);
      });
    case SongSort.added:
      out.sort((a, b) => b.mtime - a.mtime);
    case SongSort.plays:
      out.sort((a, b) {
        final c = (plays[b.path] ?? 0) - (plays[a.path] ?? 0);
        return c != 0 ? c : title(a, b);
      });
    case SongSort.duration:
      out.sort((a, b) => b.durationMs - a.durationMs);
  }
  return out;
}
