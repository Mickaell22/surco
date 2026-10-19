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
  carnaval('Carnaval', 'Serpentinas y confeti', seasonal: true),
  sanPatricio('San Patricio', 'Trébol y verde', seasonal: true),
  diaTierra('Día de la Tierra', 'Hojas y planeta', seasonal: true),
  diaMadre('Día de la Madre', 'Flores', seasonal: true),
  diaPadre('Día del Padre', 'Azul marino', seasonal: true),
  intiRaymi('Inti Raymi', 'Fiesta del sol', seasonal: true),
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

/// Domingo de Pascua (algoritmo gregoriano anónimo de Meeus/Jones/Butcher).
DateTime easter(int y) {
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31, day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(y, month, day);
}

/// [n]-esimo domingo del mes (n = 1..5).
DateTime nthSunday(int y, int month, int n) {
  final first = DateTime(y, month, 1);
  return DateTime(y, month, 1 + (7 - first.weekday) % 7 + 7 * (n - 1));
}

/// Temporada activa en la fecha [d], o null fuera de temporada. Las fechas
/// moviles (Carnaval, dias de la Madre y del Padre) se calculan por año.
Palette? seasonFor(DateTime d) {
  final day0 = DateTime(d.year, d.month, d.day);
  bool within(DateTime from, DateTime to) => !day0.isBefore(from) && !day0.isAfter(to);
  final m = d.month, day = d.day;
  // Aritmetica de calendario (DateTime(y, m, d - n)), no Duration: restar dias
  // como horas cruza el cambio de horario y corre la fecha un dia.
  DateTime minus(DateTime x, int days) => DateTime(x.year, x.month, x.day - days);
  // Carnaval: sabado a martes antes del Miercoles de Ceniza (Pascua - 46).
  final ash = minus(easter(d.year), 46);
  if (within(minus(ash, 4), minus(ash, 1))) return Palette.carnaval;
  final madre = nthSunday(d.year, 5, 2), padre = nthSunday(d.year, 6, 3);
  if (within(minus(madre, 1), madre)) return Palette.diaMadre;
  if (within(minus(padre, 1), padre)) return Palette.diaPadre;
  if (m == 10 && day >= 15) return Palette.halloween;
  if (m == 11 && day <= 2) return Palette.muertos;
  if (m == 12 && day <= 25) return Palette.navidad;
  if ((m == 12 && day >= 26) || (m == 1 && day <= 6)) return Palette.anioNuevo;
  if (m == 2 && day >= 7 && day <= 15) return Palette.sanValentin;
  if (m == 3 && day == 17) return Palette.sanPatricio;
  if (m == 4 && day == 22) return Palette.diaTierra;
  if (m == 6 && day >= 20 && day <= 24) return Palette.intiRaymi;
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

  /// En temporada, la primera apertura del dia muestra si o si su tema; las
  /// siguientes siguen la rotacion (con rotacion "Fija" la temporada se queda).
  bool firstOpenToday = true;

  /// En "Al abrir" y en temporada, cada apertura tira una moneda: con cara sale
  /// el tema festivo aunque no sea la primera del día (antes salía muy poco).
  bool seasonDraw = false;

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
    final today = _dayKey(d) == _dayKey(DateTime.now());
    final launchSeason = rotation == ThemeRotation.launch && seasonDraw;
    if (season != null && (rotation == ThemeRotation.fixed || firstOpenToday || launchSeason || !today)) return season;
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
    String? lastOpenDay;
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
        lastOpenDay = j['lastOpenDay'];
        pauseOnUnplug = j['pauseOnUnplug'] ?? pauseOnUnplug;
        resumeSession = j['resumeSession'] ?? resumeSession;
        skipSilence = j['skipSilence'] ?? skipSilence;
        ignoreShort = j['ignoreShort'] ?? ignoreShort;
      } catch (_) {/* archivo corrupto: quedan los valores por defecto */}
    }
    launchPalette = launchPaletteAfter(lastLaunch);
    seasonDraw = Random().nextBool();
    firstOpenToday = lastOpenDay != _dayKey(DateTime.now());
    _openDay = _dayKey(DateTime.now());
    _save();
  }

  /// Volver a la app desde segundo plano cuenta como una apertura nueva: sortea
  /// otra paleta para "Al abrir" y, si cambió el día, vuelve a dar prioridad a
  /// la temporada.
  void newOpen() {
    final today = _dayKey(DateTime.now());
    firstOpenToday = _openDay != today;
    _openDay = today;
    launchPalette = launchPaletteAfter(launchPalette);
    seasonDraw = Random().nextBool();
    notifyListeners();
    _save();
  }

  String? _openDay;

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
        'lastOpenDay': _dayKey(DateTime.now()),
        'pauseOnUnplug': pauseOnUnplug,
        'resumeSession': resumeSession,
        'skipSilence': skipSilence,
        'ignoreShort': ignoreShort,
      }));
}
