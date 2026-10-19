import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum Palette {
  papel('Papel', 'Calido, el original'),
  grafito('Grafito', 'Gris neutro con azul'),
  bosque('Bosque', 'Verdes tranquilos'),
  oceano('Oceano', 'Azul petroleo'),
  vino('Vino', 'Burdeos suave'),
  lavanda('Lavanda', 'Violeta apagado'),
  // De temporada: se aplican solas en sus fechas (ver seasonFor).
  halloween('Halloween', 'Calabaza y noche', seasonal: true),
  muertos('Dia de Muertos', 'Cempasuchil y papel picado', seasonal: true),
  navidad('Navidad', 'Rojo y pino', seasonal: true),
  anioNuevo('Ano Nuevo', 'Medianoche y dorado', seasonal: true),
  sanValentin('San Valentin', 'Rosa suave', seasonal: true),
  cumple('Cumpleanos', 'Vela y confeti', seasonal: true);

  const Palette(this.label, this.hint, {this.seasonal = false});
  final String label, hint;
  final bool seasonal;

  static List<Palette> get regular => values.where((p) => !p.seasonal).toList();
}

/// Temporada activa en la fecha [d], o null fuera de temporada.
Palette? seasonFor(DateTime d) {
  final m = d.month, day = d.day;
  if (m == 10 && day >= 15) return Palette.halloween;
  if (m == 11 && day <= 2) return Palette.muertos;
  if (m == 12 && day <= 25) return Palette.navidad;
  if ((m == 12 && day >= 26) || (m == 1 && day <= 6)) return Palette.anioNuevo;
  if (m == 2 && day >= 7 && day <= 15) return Palette.sanValentin;
  return null;
}

/// Paleta "al azar" del dia: estable durante el dia y nunca igual a la de ayer.
/// Cada dia avanza un salto aleatorio de 1..n-1 posiciones desde la de ayer.
// ponytail: recorre los dias desde 2026-01-01 (unos cientos de iteraciones por
// ano, despreciable). Si molestara, cachear el resultado por fecha.
Palette dailyPalette(DateTime d) {
  final pool = Palette.regular;
  final days = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;
  var idx = 0;
  for (var i = 1; i <= days; i++) {
    idx = (idx + 1 + Random(i).nextInt(pool.length - 1)) % pool.length;
  }
  return pool[idx];
}

enum LibraryScope {
  music('Solo Music y Download', 'Mas rapido'),
  all('Todo el telefono', 'Encuentra audio en cualquier carpeta');

  const LibraryScope(this.label, this.hint);
  final String label, hint;
}

enum SongSort {
  title('Titulo'),
  artist('Artista'),
  added('Agregadas recientemente'),
  plays('Mas escuchadas'),
  duration('Duracion');

  const SongSort(this.label);
  final String label;
}

/// Preferencias persistidas en un JSON chico (sin shared_preferences: una
/// dependencia menos y es un archivo de unos pocos bytes).
class Settings extends ChangeNotifier {
  Palette palette = Palette.papel;
  ThemeMode mode = ThemeMode.system;
  bool pureBlack = false;
  bool dailyTheme = false;
  bool seasonalThemes = true;
  /// Cumpleanos del usuario (mes y dia); null si no lo configuro.
  int? birthdayMonth, birthdayDay;
  bool pauseOnUnplug = true;
  bool resumeSession = true;
  bool skipSilence = false;
  bool ignoreShort = true;
  LibraryScope scope = LibraryScope.music;
  SongSort sort = SongSort.title;

  File? _file;

  /// Paleta en uso: la de temporada si toca, si no la del dia o la elegida.
  // ponytail: se evalua al construir el tema; si la app queda abierta pasada la
  // medianoche cambia en la proxima reconstruccion, no exactamente a las 00:00.
  Palette get activePalette => paletteFor(DateTime.now());

  bool isBirthday(DateTime d) => d.month == birthdayMonth && d.day == birthdayDay;

  Palette paletteFor(DateTime d) {
    if (seasonalThemes && isBirthday(d)) return Palette.cumple;
    final season = seasonalThemes ? seasonFor(d) : null;
    if (season != null) return season;
    return dailyTheme ? dailyPalette(d) : palette;
  }

  Future<void> load() async {
    _file = File('${(await getApplicationSupportDirectory()).path}/settings.json');
    if (!await _file!.exists()) return;
    try {
      final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
      palette = Palette.values.asNameMap()[j['palette']] ?? palette;
      mode = ThemeMode.values.asNameMap()[j['mode']] ?? mode;
      scope = LibraryScope.values.asNameMap()[j['scope']] ?? scope;
      sort = SongSort.values.asNameMap()[j['sort']] ?? sort;
      pureBlack = j['pureBlack'] ?? pureBlack;
      dailyTheme = j['dailyTheme'] ?? dailyTheme;
      seasonalThemes = j['seasonalThemes'] ?? seasonalThemes;
      birthdayMonth = j['birthdayMonth'];
      birthdayDay = j['birthdayDay'];
      pauseOnUnplug = j['pauseOnUnplug'] ?? pauseOnUnplug;
      resumeSession = j['resumeSession'] ?? resumeSession;
      skipSilence = j['skipSilence'] ?? skipSilence;
      ignoreShort = j['ignoreShort'] ?? ignoreShort;
    } catch (_) {/* archivo corrupto: quedan los valores por defecto */}
  }

  void update(void Function(Settings s) change) {
    change(this);
    notifyListeners();
    _file?.writeAsString(jsonEncode({
      'palette': palette.name,
      'mode': mode.name,
      'scope': scope.name,
      'sort': sort.name,
      'pureBlack': pureBlack,
      'dailyTheme': dailyTheme,
      'seasonalThemes': seasonalThemes,
      'birthdayMonth': birthdayMonth,
      'birthdayDay': birthdayDay,
      'pauseOnUnplug': pauseOnUnplug,
      'resumeSession': resumeSession,
      'skipSilence': skipSilence,
      'ignoreShort': ignoreShort,
    }));
  }
}
