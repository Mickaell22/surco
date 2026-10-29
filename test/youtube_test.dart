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

  test('encuentra el link dentro de un texto compartido', () {
    expect(findYoutubeUrl('Mira esto https://youtu.be/dQw4w9WgXcQ?si=abc'), 'https://youtu.be/dQw4w9WgXcQ?si=abc');
    expect(findYoutubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isNotNull);
    expect(findYoutubeUrl('hola'), isNull);
  });
}
