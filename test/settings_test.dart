import 'dart:math';

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

  test('cumpleaños gana sobre todo y solo ese día', () {
    final s = Settings()
      ..birthdayMonth = 10
      ..birthdayDay = 20;
    expect(s.paletteFor(DateTime(2026, 10, 20)), Palette.cumple);
    expect(s.paletteFor(DateTime(2026, 10, 21)), Palette.halloween);
  });

  test('rotación diaria: estable en el día, nunca de temporada, distinta a ayer', () {
    final d = DateTime(2026, 6, 10);
    expect(dailyPalette(d), dailyPalette(DateTime(2026, 6, 10, 23, 59)));
    // Días de calendario (no add(Duration): con cambio de horario 24 h no siempre es "mañana").
    for (var i = 0; i < 400; i++) {
      final day = DateTime(2026, 6, 10 + i), prev = DateTime(2026, 6, 9 + i);
      expect(dailyPalette(day).seasonal, isFalse);
      expect(dailyPalette(day), isNot(dailyPalette(prev)));
    }
  });

  test('al abrir: nunca repite la paleta de la apertura anterior', () {
    final rnd = Random(1);
    var last = Palette.papel;
    for (var i = 0; i < 200; i++) {
      final next = launchPaletteAfter(last, rnd);
      expect(next, isNot(last));
      expect(next.seasonal, isFalse);
      last = next;
    }
  });

  test('elegir una paleta con algo automático vale solo por hoy', () {
    final s = Settings()..rotation = ThemeRotation.daily;
    expect(s.choosePalette(Palette.cobre), isTrue);
    expect(s.activePalette, Palette.cobre);
    expect(s.paletteFor(DateTime.now().add(const Duration(days: 2))), isNot(Palette.cobre.seasonal ? null : null));
    final fija = Settings()..rotation = ThemeRotation.fixed;
    fija.seasonalThemes = false;
    expect(fija.choosePalette(Palette.musgo), isFalse);
    expect(fija.paletteFor(DateTime(2030, 3, 3)), Palette.musgo);
  });
}
