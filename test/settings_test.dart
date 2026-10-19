import 'package:flutter_test/flutter_test.dart';
import 'package:surco/settings.dart';

void main() {
  test('tema del dia rota las paletas y apagado respeta la elegida', () {
    final s = Settings()..palette = Palette.vino;
    expect(s.activePalette, Palette.vino);
    s.dailyTheme = true;
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year)).inDays;
    expect(s.activePalette, Palette.values[day % Palette.values.length]);
  });
}
