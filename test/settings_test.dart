import 'package:flutter_test/flutter_test.dart';
import 'package:surco/settings.dart';

void main() {
  test('fuera de temporada manda la paleta elegida', () {
    final s = Settings()..palette = Palette.vino;
    expect(s.paletteFor(DateTime(2026, 6, 10)), Palette.vino);
  });

  test('temporadas y su prioridad', () {
    final s = Settings();
    expect(s.paletteFor(DateTime(2026, 10, 18)), Palette.halloween);
    expect(s.paletteFor(DateTime(2026, 11, 2)), Palette.muertos);
    expect(s.paletteFor(DateTime(2026, 12, 24)), Palette.navidad);
    expect(s.paletteFor(DateTime(2027, 1, 1)), Palette.anioNuevo);
    expect(s.paletteFor(DateTime(2027, 2, 14)), Palette.sanValentin);
    s.seasonalThemes = false;
    expect(s.paletteFor(DateTime(2026, 12, 24)), s.palette);
  });

  test('cumpleanos gana sobre todo y solo ese dia', () {
    final s = Settings()
      ..birthdayMonth = 10
      ..birthdayDay = 20;
    expect(s.paletteFor(DateTime(2026, 10, 20)), Palette.cumple);
    expect(s.paletteFor(DateTime(2026, 10, 21)), Palette.halloween);
  });

  test('tema del dia: estable en el dia, nunca de temporada, distinto a ayer', () {
    final d = DateTime(2026, 6, 10);
    expect(dailyPalette(d), dailyPalette(DateTime(2026, 6, 10, 23, 59)));
    // Dias de calendario (no add(Duration): con cambio de horario 24 h no siempre es "manana").
    for (var i = 0; i < 400; i++) {
      final day = DateTime(2026, 6, 10 + i), prev = DateTime(2026, 6, 9 + i);
      expect(dailyPalette(day).seasonal, isFalse);
      expect(dailyPalette(day), isNot(dailyPalette(prev)));
    }
  });
}
