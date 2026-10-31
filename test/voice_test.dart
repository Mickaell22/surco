import 'package:flutter_test/flutter_test.dart';
import 'package:surco/voice.dart';

void main() {
  test('sin nombrar a Surco no hace nada', () {
    expect(parseVoice('pasa la siguiente'), isNull);
    expect(parseVoice('para el carro'), isNull);
  });

  test('comandos básicos, con variantes del reconocedor', () {
    expect(parseVoice('Surco, siguiente'), isA<Next>());
    expect(parseVoice('surco la siguiente canción'), isA<Next>());
    expect(parseVoice('Zurco anterior'), isA<Previous>());
    expect(parseVoice('surco pausa'), isA<Pause>());
    expect(parseVoice('surco para'), isA<Pause>());
    expect(parseVoice('surco sigue'), isA<Resume>());
    expect(parseVoice('surco dale play'), isA<Resume>());
    expect((parseVoice('Surco, sube el volumen') as Volume).up, isTrue);
    expect((parseVoice('surco bájale') as Volume).up, isFalse);
    expect(parseVoice('surco aleatorio'), isA<Shuffle>());
    expect(parseVoice('surco otra vez'), isA<RepeatOne>());
    expect(parseVoice('surco apágate'), isA<StopListening>());
    expect(parseVoice('surco qué hora es'), isA<Unknown>());
    expect(parseVoice('Surco'), isA<Wake>());
    expect(parseVoice('siguiente'), isNull);
    expect(parseVoice('siguiente', awake: true), isA<Next>());
  });

  test('pon X busca canción, artista o lista', () {
    expect((parseVoice('Surco, pon Daydream') as PlayQuery).query, 'daydream');
    expect((parseVoice('surco ponme algo de Zarcort') as PlayQuery).query, 'zarcort');
    expect((parseVoice('surco pon la lista de entrenar') as PlayQuery).query, 'de entrenar');
    expect(parseVoice('surco pon la música'), isA<Resume>());
  });

  test('palabras clave de las listas, sin relleno', () {
    expect(keywords('Para entrenar'), ['entrenar']);
    expect(keywords('Felices y de buen rollo'), ['felices', 'buen', 'rollo']);
    expect(keywords('Rock'), ['rock']);
    expect((parseVoice('surco entrenar') as Unknown).text, 'entrenar');
    expect(parseVoice('surco para'), isA<Pause>());
  });
}
