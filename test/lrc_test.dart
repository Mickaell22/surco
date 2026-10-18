import 'package:flutter_test/flutter_test.dart';
import 'package:surco/player.dart';

void main() {
  test('parseLrc lee tiempos, repetidos y ordena', () {
    final l = parseLrc('[ti:x]\n[00:05.50]b\n[00:01.00][00:10.00]a\n')!;
    expect(l.map((e) => e.text), ['a', 'b', 'a']);
    expect(l.first.at, const Duration(seconds: 1));
    expect(l[1].at, const Duration(milliseconds: 5500));
  });

  test('texto plano no es LRC', () => expect(parseLrc('linea uno\nlinea dos'), isNull));

  test('lrcIndexAt elige la ultima linea ya alcanzada', () {
    final l = parseLrc('[00:01.00]a\n[00:05.00]b')!;
    expect(lrcIndexAt(l, Duration.zero), -1);
    expect(lrcIndexAt(l, const Duration(seconds: 3)), 0);
    expect(lrcIndexAt(l, const Duration(seconds: 9)), 1);
  });
}
