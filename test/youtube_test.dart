import 'package:flutter_test/flutter_test.dart';
import 'package:surco/youtube.dart';

void main() {
  test('título y artista limpios desde el video', () {
    var t = guessTags('Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)', 'Rick Astley');
    expect((t.artist, t.title), ('Rick Astley', 'Never Gonna Give You Up'));
    t = guessTags('Bling-Bang-Bang-Born', 'Creepy Nuts - Topic');
    expect((t.artist, t.title), ('Creepy Nuts', 'Bling-Bang-Bang-Born'));
    t = guessTags('Believer [Lyric Video]', 'ImagineDragonsVEVO');
    expect((t.artist, t.title), ('ImagineDragons', 'Believer'));
  });

  test('letras de lrclib: descarta basura y prefiere sincronizada con duración parecida', () {
    final larga = List.filled(10, 'una línea de la canción').join('\n');
    final sync = List.filled(10, '[00:01.00] una línea de la canción').join('\n');
    expect(
      bestLyrics([
        {'duration': 213, 'syncedLyrics': '[00:00.00]probe'},
      ], const Duration(seconds: 213)),
      isNull,
    );
    expect(
      bestLyrics([
        {'duration': 213, 'plainLyrics': larga},
        {'duration': 214, 'syncedLyrics': sync},
        {'duration': 300, 'syncedLyrics': sync},
      ], const Duration(seconds: 213)),
      sync,
    );
    expect(releaseYear('Provided to YouTube\n\nReleased on: 1987-07-27'), '1987');
    expect(releaseYear('Video oficial'), isNull);
  });

  test('encuentra el link dentro de un texto compartido', () {
    expect(findYoutubeUrl('Mira esto https://youtu.be/dQw4w9WgXcQ?si=abc'), 'https://youtu.be/dQw4w9WgXcQ?si=abc');
    expect(findYoutubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isNotNull);
    expect(findYoutubeUrl('hola'), isNull);
  });
}
