import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum Palette {
  papel('Papel', 'Cálido, el original'),
  grafito('Grafito', 'Gris neutro con azul'),
  bosque('Bosque', 'Verdes tranquilos'),
  oceano('Océano', 'Azul petróleo'),
  vino('Vino', 'Burdeos suave'),
  lavanda('Lavanda', 'Violeta apagado'),
  arena('Arena', 'Ocre de playa'),
  menta('Menta', 'Verde fresco'),
  cobre('Cobre', 'Metal tostado'),
  pizarra('Pizarra', 'Azul grisáceo'),
  ciruela('Ciruela', 'Morado profundo'),
  atardecer('Atardecer', 'Coral cálido'),
  musgo('Musgo', 'Oliva suave'),
  cielo('Cielo', 'Azul claro'),
  // De temporada: se aplican solas en sus fechas (ver seasonFor).
  halloween('Halloween', 'Calabaza y noche', seasonal: true),
  muertos('Día de Muertos', 'Cempasúchil y papel picado', seasonal: true),
  navidad('Navidad', 'Rojo y pino', seasonal: true),
  anioNuevo('Año Nuevo', 'Medianoche y dorado', seasonal: true),
  sanValentin('San Valentín', 'Rosa suave', seasonal: true),
  cumple('Cumpleaños', 'Vela y confeti', seasonal: true);

  const Palette(this.label, this.hint, {this.seasonal = false});
  final String label, hint;
  final bool seasonal;

  static List<Palette> get regular => values.where((p) => !p.seasonal).toList();
}

/// Cómo cambia la paleta sola.
enum ThemeRotation {
  fixed('Fija'),
  daily('Cada día'),
  launch('Al abrir');

  const ThemeRotation(this.label);
  final String label;
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

/// Paleta "al azar" del día: estable durante el día y nunca igual a la de ayer.
/// Cada día avanza un salto aleatorio de 1..n-1 posiciones desde la de ayer.
// ponytail: recorre los días desde 2026-01-01 (unos cientos de iteraciones por
// año, despreciable). Si molestara, cachear el resultado por fecha.
Palette dailyPalette(DateTime d) {
  final pool = Palette.regular;
  final days = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;
  var idx = 0;
  for (var i = 1; i <= days; i++) {
    idx = (idx + 1 + Random(i).nextInt(pool.length - 1)) % pool.length;
  }
  return pool[idx];
}

/// Paleta al azar para esta apertura, distinta a la de la apertura anterior.
Palette launchPaletteAfter(Palette? last, [Random? rnd]) {
  final pool = Palette.regular.where((p) => p != last).toList();
  return pool[(rnd ?? Random()).nextInt(pool.length)];
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

enum LibraryScope {
  music('Solo Music y Download', 'Más rápido'),
  all('Todo el teléfono', 'Encuentra audio en cualquier carpeta');

  const LibraryScope(this.label, this.hint);
  final String label, hint;
}

enum SongSort {
  title('Título'),
  artist('Artista'),
  added('Agregadas recientemente'),
  plays('Más escuchadas'),
  duration('Duración');

  const SongSort(this.label);
  final String label;
}

/// Preferencias persistidas en un JSON chico (sin shared_preferences: una
/// dependencia menos y es un archivo de unos pocos bytes).
class Settings extends ChangeNotifier {
  Palette palette = Palette.papel;
  ThemeMode mode = ThemeMode.system;
  bool pureBlack = false;
  ThemeRotation rotation = ThemeRotation.fixed;
  bool seasonalThemes = true;
  bool decorations = true;
  /// Cumpleaños del usuario (mes y día); null si no lo configuró.
  int? birthdayMonth, birthdayDay;
  bool pauseOnUnplug = true;
  bool resumeSession = true;
  bool skipSilence = false;
  bool ignoreShort = true;
  LibraryScope scope = LibraryScope.music;
  SongSort sort = SongSort.title;

  /// Paleta elegida a mano "solo por hoy" mientras manda algo automático.
  Palette? overridePalette;
  String? overrideDay;

  /// Sorteada en cada apertura (modo "Al abrir"); se recuerda para no repetir.
  Palette launchPalette = Palette.papel;

  File? _file;

  /// Paleta en uso.
  // ponytail: se evalúa al construir el tema; si la app queda abierta pasada la
  // medianoche cambia en la próxima reconstrucción, no exactamente a las 00:00.
  Palette get activePalette => paletteFor(DateTime.now());

  bool isBirthday(DateTime d) => d.month == birthdayMonth && d.day == birthdayDay;

  /// Paleta automática que manda (temporada o rotación), o null si manda la elegida.
  Palette? autoPaletteFor(DateTime d) {
    if (seasonalThemes && isBirthday(d)) return Palette.cumple;
    final season = seasonalThemes ? seasonFor(d) : null;
    if (season != null) return season;
    return switch (rotation) {
      ThemeRotation.fixed => null,
      ThemeRotation.daily => dailyPalette(d),
      ThemeRotation.launch => launchPalette,
    };
  }

  /// Prioridad: elección manual de hoy > cumpleaños/temporada > rotación > fija.
  Palette paletteFor(DateTime d) {
    if (overrideDay == _dayKey(d) && overridePalette != null) return overridePalette!;
    return autoPaletteFor(d) ?? palette;
  }

  bool get hasOverrideToday => overrideDay == _dayKey(DateTime.now()) && overridePalette != null;

  /// Tocar una paleta. Si manda algo automático vale solo por hoy (mañana vuelve
  /// lo automático); si no, queda como paleta fija. Devuelve true si fue por hoy.
  bool choosePalette(Palette p) {
    final now = DateTime.now();
    final auto = autoPaletteFor(now) != null;
    update((x) {
      x.palette = p;
      x.overridePalette = auto ? p : null;
      x.overrideDay = auto ? _dayKey(now) : null;
    });
    return auto;
  }

  void clearOverride() => update((x) {
        x.overridePalette = null;
        x.overrideDay = null;
      });

  Future<void> load() async {
    _file = File('${(await getApplicationSupportDirectory()).path}/settings.json');
    Palette? lastLaunch;
    if (await _file!.exists()) {
      try {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        final p = Palette.values.asNameMap();
        palette = p[j['palette']] ?? palette;
        mode = ThemeMode.values.asNameMap()[j['mode']] ?? mode;
        scope = LibraryScope.values.asNameMap()[j['scope']] ?? scope;
        sort = SongSort.values.asNameMap()[j['sort']] ?? sort;
        // Migración: la 1.1 guardaba un bool dailyTheme.
        rotation = ThemeRotation.values.asNameMap()[j['rotation']] ??
            (j['dailyTheme'] == true ? ThemeRotation.daily : ThemeRotation.fixed);
        pureBlack = j['pureBlack'] ?? pureBlack;
        seasonalThemes = j['seasonalThemes'] ?? seasonalThemes;
        decorations = j['decorations'] ?? decorations;
        birthdayMonth = j['birthdayMonth'];
        birthdayDay = j['birthdayDay'];
        overridePalette = p[j['overridePalette']];
        overrideDay = j['overrideDay'];
        lastLaunch = p[j['lastLaunch']];
        pauseOnUnplug = j['pauseOnUnplug'] ?? pauseOnUnplug;
        resumeSession = j['resumeSession'] ?? resumeSession;
        skipSilence = j['skipSilence'] ?? skipSilence;
        ignoreShort = j['ignoreShort'] ?? ignoreShort;
      } catch (_) {/* archivo corrupto: quedan los valores por defecto */}
    }
    launchPalette = launchPaletteAfter(lastLaunch);
    _save();
  }

  void update(void Function(Settings s) change) {
    change(this);
    notifyListeners();
    _save();
  }

  void _save() => _file?.writeAsString(jsonEncode({
        'palette': palette.name,
        'mode': mode.name,
        'scope': scope.name,
        'sort': sort.name,
        'rotation': rotation.name,
        'pureBlack': pureBlack,
        'seasonalThemes': seasonalThemes,
        'decorations': decorations,
        'birthdayMonth': birthdayMonth,
        'birthdayDay': birthdayDay,
        'overridePalette': overridePalette?.name,
        'overrideDay': overrideDay,
        'lastLaunch': launchPalette.name,
        'pauseOnUnplug': pauseOnUnplug,
        'resumeSession': resumeSession,
        'skipSilence': skipSilence,
        'ignoreShort': ignoreShort,
      }));
}
