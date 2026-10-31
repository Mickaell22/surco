import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'library.dart';
import 'native.dart';
import 'player.dart';
import 'settings.dart';

/// Comandos de voz del modo manos libres.
sealed class VoiceCommand {
  const VoiceCommand();
}

class Next extends VoiceCommand {
  const Next();
}

class Previous extends VoiceCommand {
  const Previous();
}

class Pause extends VoiceCommand {
  const Pause();
}

class Resume extends VoiceCommand {
  const Resume();
}

class Volume extends VoiceCommand {
  const Volume(this.up);
  final bool up;
}

class Shuffle extends VoiceCommand {
  const Shuffle();
}

class RepeatOne extends VoiceCommand {
  const RepeatOne();
}

class StopListening extends VoiceCommand {
  const StopListening();
}

/// Solo la palabra de activación: "Surco" y nada más.
class Wake extends VoiceCommand {
  const Wake();
}

/// Nombró a Surco con algo que no es un comando fijo: puede ser una lista,
/// un artista o un atajo propio ([text], ya normalizado).
class Unknown extends VoiceCommand {
  const Unknown([this.text = '']);
  final String text;
}

/// Palabras que no sirven para reconocer una lista ("Para entrenar" → entrenar).
const _filler = {'para', 'de', 'del', 'y', 'con', 'los', 'las', 'el', 'la', 'en', 'mis', 'mi'};

/// Palabras clave de un nombre de lista: las que pueden decirse solas.
List<String> keywords(String name) =>
    fold(name).split(' ').where((w) => w.length >= 3 && !_filler.contains(w)).toList();

/// "pon X": canción, artista o lista.
class PlayQuery extends VoiceCommand {
  const PlayQuery(this.query);
  final String query;
}

/// Frases de comando que entiende manos libres (sin la palabra "surco").
const voiceCommandPhrases = [
  'siguiente', 'la siguiente', 'pasa', 'salta', 'otra', //
  'anterior', 'atrás', 'la de antes', 'regresa',
  'pausa', 'para', 'detente', 'silencio', 'stop',
  'sigue', 'dale', 'continúa', 'play', 'reproduce', 'pon música',
  'sube el volumen', 'sube', 'súbele', 'más fuerte',
  'baja el volumen', 'baja', 'bájale', 'más bajo',
  'aleatorio', 'mezcla', 'repite', 'otra vez', 'apágate', 'desactiva',
];

String fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll(RegExp(r'[^a-z0-9ñ ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// El reconocedor a veces escribe la palabra de activación de otra forma.
final _wake = RegExp(r'\b(surco|surcos|surko|zurco|zurko|sulco|turco)\b');

/// Interpreta una frase. Solo cuenta si nombra a Surco ("Surco, siguiente"):
/// así una conversación normal no maneja la música.
/// Con [awake] (justo después de un "Surco" solo) no hace falta nombrarlo.
VoiceCommand? parseVoice(String text, {bool awake = false}) {
  final t = fold(text);
  final m = _wake.firstMatch(t);
  if (m == null && !awake) return null;
  final c = m == null ? t : t.substring(m.end).trim();
  if (c.isEmpty) return const Wake();
  bool has(String pattern) => RegExp('\\b($pattern)\\b').hasMatch(c);
  if (RegExp(r'^(pon|ponme|reproduce|toca|busca) (.+)$').firstMatch(c) case final p?) {
    final q = p.group(2)!.replaceFirst(RegExp(r'^(la cancion|la lista|algo de|a|el|la) '), '').trim();
    if (q.isNotEmpty && !RegExp(r'^(musica|la musica|aleatorio)$').hasMatch(q)) return PlayQuery(q);
  }
  if (has('apagate|desactiva|deja de escuchar|ya no escuches')) return const StopListening();
  if (has('sube|subele|mas fuerte|mas alto')) return const Volume(true);
  if (has('baja|bajale|mas bajo|mas suave|mas despacio')) return const Volume(false);
  if (has('repite|repetir|otra vez')) return const RepeatOne();
  if (has('siguiente|proxima|salta|pasa|otra')) return const Next();
  if (has('anterior|atras|regresa|la de antes')) return const Previous();
  if (has('aleatorio|mezcla|cualquiera|random')) return const Shuffle();
  if (has('pausa|pausar|para|parar|deten|detente|stop|silencio|calla')) return const Pause();
  if (has('sigue|seguir|continua|dale|play|reproduce|pon musica|pon la musica')) return const Resume();
  return Unknown(c);
}

/// Modo manos libres: prendido a mano, se apaga solo si la música lleva
/// [Settings.voiceIdleMinutes] en pausa.
class Voice extends ChangeNotifier {
  Voice(this.player, this.library, this.settings) {
    player.audio.playingStream.listen((playing) {
      _idle?.cancel();
      if (active && !playing) {
        _idle = Timer(Duration(minutes: settings.voiceIdleMinutes), stop);
      }
    });
  }

  final Player player;
  final Library library;
  final Settings settings;
  bool active = false;
  Timer? _idle;

  /// Última frase entendida, para mostrarla en pantalla.
  String? lastHeard;

  /// Tras un "Surco" solo, el siguiente comando no necesita nombrarlo.
  DateTime? _awakeUntil;

  Future<void> start() async {
    await startListening(phrases: grammar(), onText: _onText, onStopped: _onStopped);
    active = true;
    if (!player.audio.playing) _idle = Timer(Duration(minutes: settings.voiceIdleMinutes), stop);
    notifyListeners();
  }

  Future<void> stop() async {
    _idle?.cancel();
    await stopListening();
    _onStopped();
  }

  void _onStopped() {
    active = false;
    _idle?.cancel();
    notifyListeners();
  }

  void _onText(List<String> alternatives) {
    final awake = _awakeUntil != null && DateTime.now().isBefore(_awakeUntil!);
    // Entre las alternativas del reconocedor gana la que sea un comando real.
    VoiceCommand? best;
    String? heard;
    for (final text in alternatives) {
      final cmd = parseVoice(text, awake: awake);
      if (cmd == null) continue;
      if (best == null || best is Wake || best is Unknown) (best, heard) = (cmd, text);
      if (cmd is! Wake && cmd is! Unknown) break;
    }
    if (best == null) return;
    lastHeard = heard;
    _awakeUntil = null;
    switch (best) {
      case Wake():
        _awakeUntil = DateTime.now().add(const Duration(seconds: 6));
        playTone(Tone.listening);
      case Unknown(:final text):
        final songs = songsFor(text);
        if (songs == null) {
          playTone(Tone.error);
        } else {
          playTone(Tone.ok);
          player.playList(songs, 0, shuffle: true);
        }
      default:
        playTone(Tone.ok);
        _run(best);
    }
    notifyListeners();
  }

  Future<void> _run(VoiceCommand cmd) async {
    switch (cmd) {
      case Next():
        await player.next();
      case Previous():
        await player.previous();
      case Pause():
        await player.audio.pause();
      case Resume():
        if (player.queue.isEmpty && library.songs.isNotEmpty) {
          await player.playList(library.songs, 0, shuffle: true);
        } else {
          player.audio.play();
        }
      case Volume(:final up):
        await changeVolume(up: up, steps: 2);
      case Shuffle():
        if (library.songs.isNotEmpty) await player.playList(library.songs, 0, shuffle: true);
      case RepeatOne():
        await player.audio.setLoopMode(LoopMode.one);
      case StopListening():
        await stop();
      case PlayQuery(:final query):
        await _play(query);
      case Wake() || Unknown():
        break;
    }
  }

  /// Vocabulario cerrado para Vosk: con frases exactas reconoce mucho mejor
  /// que transcribiendo libre, sobre todo con ruido (viento en la moto).
  List<String> grammar() {
    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-záéíóúüñ0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final names = {for (final p in library.playlists) clean(p.name), for (final s in library.songs) clean(s.artist)}
      ..removeWhere((n) => n.isEmpty);
    // Listas dichas directo ("surco entrenar") y atajos propios.
    final direct = {
      for (final p in library.playlists) ...[
        clean(p.name),
        for (final w in clean(p.name).split(' '))
          if (w.length >= 3 && !_filler.contains(fold(w))) w,
      ],
      for (final k in settings.voiceShortcuts.keys) clean(k),
    };
    final commands = [...voiceCommandPhrases, for (final n in names) 'pon $n', ...direct];
    return [
      'surco',
      for (final c in commands) ...['surco $c', c],
    ];
  }

  /// Canciones para lo que se dijo después de "Surco" cuando no es un comando
  /// fijo: atajo propio, palabra clave de una lista o artista. Null si nada.
  List<Song>? songsFor(String said) {
    final c = fold(said);
    if (c.isEmpty) return null;
    for (final e in settings.voiceShortcuts.entries) {
      if (fold(e.key) == c) return _target(e.value);
    }
    final words = c.split(' ').where((w) => !_filler.contains(w)).toSet();
    for (final p in library.playlists) {
      if (fold(p.name) == c || keywords(p.name).any(words.contains)) return p.songs;
    }
    if (c.length >= 3) {
      final byArtist = library.songs.where((s) => fold(s.artist).contains(c)).toList();
      if (byArtist.isNotEmpty) return byArtist;
    }
    return null;
  }

  /// Destino de un atajo: "lista:Nombre" o "artista:Nombre".
  List<Song>? _target(String target) {
    final i = target.indexOf(':');
    final kind = target.substring(0, i), name = target.substring(i + 1);
    final songs = kind == 'lista'
        ? library.playlists.where((p) => p.name == name).firstOrNull?.songs
        : library.songs.where((s) => s.artist == name).toList();
    return songs == null || songs.isEmpty ? null : songs;
  }

  /// Busca en listas, artistas y títulos, en ese orden.
  Future<void> _play(String query) async {
    final q = fold(query);
    for (final p in library.playlists) {
      if (fold(p.name).contains(q)) return player.playList(p.songs, 0, shuffle: true);
    }
    final byArtist = library.songs.where((s) => fold(s.artist).contains(q)).toList();
    if (byArtist.isNotEmpty) return player.playList(byArtist, 0, shuffle: true);
    final byTitle = library.songs.where((s) => fold(s.title).contains(q)).toList();
    if (byTitle.isNotEmpty) return player.playList(byTitle, 0);
  }
}
