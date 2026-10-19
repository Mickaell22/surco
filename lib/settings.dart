import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum Palette {
  papel('Papel', 'Calido, el original'),
  grafito('Grafito', 'Gris neutro con azul'),
  bosque('Bosque', 'Verdes tranquilos'),
  oceano('Oceano', 'Azul petroleo'),
  vino('Vino', 'Burdeos suave'),
  lavanda('Lavanda', 'Violeta apagado');

  const Palette(this.label, this.hint);
  final String label, hint;
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
  bool pauseOnUnplug = true;
  bool resumeSession = true;
  bool skipSilence = false;
  bool ignoreShort = true;
  LibraryScope scope = LibraryScope.music;
  SongSort sort = SongSort.title;

  File? _file;

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
      'pauseOnUnplug': pauseOnUnplug,
      'resumeSession': resumeSession,
      'skipSilence': skipSilence,
      'ignoreShort': ignoreShort,
    }));
  }
}
