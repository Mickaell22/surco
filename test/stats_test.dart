import 'package:flutter_test/flutter_test.dart';
import 'package:surco/library.dart';
import 'package:surco/settings.dart';
import 'package:surco/smart.dart';
import 'package:surco/stats.dart';

Song song(String p, {int ms = 200000, int mtime = 0, String artist = 'A'}) =>
    Song(path: p, mtime: mtime, title: p, artist: artist, album: 'X', durationMs: ms);

void main() {
  test('una escucha cuenta con 30 s o la mitad de una cancion corta', () {
    final st = Stats();
    st.record(song('larga'), DateTime.now(), 29000);
    st.record(song('larga'), DateTime.now(), 30000);
    st.record(song('corta', ms: 40000), DateTime.now(), 20000);
    expect(st.events.map((e) => e.path), ['larga', 'corta']);
  });

  test('ranking por escuchas, respetando la ventana de tiempo', () {
    final a = song('a'), b = song('b', artist: 'B');
    final byPath = {'a': a, 'b': b};
    final st = Stats();
    final viejo = DateTime.now().subtract(const Duration(days: 20));
    st.record(a, viejo, 60000);
    st.record(a, viejo, 60000);
    st.record(b, DateTime.now(), 60000);
    expect(st.topSongs(byPath).first.song.path, 'a');
    expect(st.topSongs(byPath, window: const Duration(days: 7)).single.song.path, 'b');
    expect(st.topArtists(byPath).first.name, 'A');
  });

  test('ordenar por mas escuchadas y por agregadas', () {
    final x = song('x', mtime: 1), y = song('y', mtime: 2);
    expect(sortSongs([x, y], SongSort.plays, {'y': 3}).first.path, 'y');
    expect(sortSongs([x, y], SongSort.added, {}).first.path, 'y');
    expect(sortSongs([y, x], SongSort.title, {}).first.path, 'x');
  });
}
