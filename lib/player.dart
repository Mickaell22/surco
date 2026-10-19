import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import 'library.dart';
import 'settings.dart';
import 'stats.dart';

/// Envoltorio fino sobre just_audio. La notificacion, la pantalla de bloqueo
/// y los botones de los audifonos Bluetooth los maneja just_audio_background.
class Player extends ChangeNotifier {
  Player(this.stats, this.settings) {
    audio.currentIndexStream.listen((_) {
      _commit();
      _saveSession();
      notifyListeners();
    });
    // Fin natural de una cancion (incluye "repetir una", donde el indice no cambia).
    audio.positionDiscontinuityStream.listen((d) {
      if (d.reason == PositionDiscontinuityReason.autoAdvance) _commit();
    });
    audio.playingStream.listen((playing) {
      playing ? _listened.start() : _listened.stop();
      if (!playing) _saveSession();
    });
    settings.addListener(() => audio.setSkipSilenceEnabled(settings.skipSilence));
    _initSession();
  }

  final Stats stats;
  final Settings settings;
  final audio = AudioPlayer();
  List<Song> queue = [];
  Timer? _sleep;
  DateTime? sleepAt;

  final _listened = Stopwatch();
  Song? _tracked;
  DateTime _trackedAt = DateTime.now();

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Desconectar audifonos (cable o Bluetooth) dispara "becoming noisy".
    session.becomingNoisyEventStream.listen((_) {
      if (settings.pauseOnUnplug) audio.pause();
    });
    await audio.setSkipSilenceEnabled(settings.skipSilence);
  }

  /// Registra cuanto se escucho de la cancion anterior y empieza a medir la actual.
  void _commit() {
    final prev = _tracked;
    if (prev != null) stats.record(prev, _trackedAt, _listened.elapsedMilliseconds);
    _listened.reset();
    if (audio.playing) _listened.start();
    _tracked = current;
    _trackedAt = DateTime.now();
  }

  // --- Sesion: cola, cancion y posicion para retomar al abrir la app ---

  Future<File> get _sessionFile async => File('${(await getApplicationSupportDirectory()).path}/session.json');

  Future<void> _saveSession() async {
    if (queue.isEmpty) return;
    (await _sessionFile).writeAsString(jsonEncode({
      'q': [for (final s in queue) s.path],
      'i': audio.currentIndex ?? 0,
      'pos': audio.position.inMilliseconds,
      'shuffle': audio.shuffleModeEnabled,
      'loop': audio.loopMode.name,
    }));
  }

  Future<void> restoreSession(Map<String, Song> byPath) async {
    if (!settings.resumeSession || queue.isNotEmpty) return;
    try {
      final j = jsonDecode(await (await _sessionFile).readAsString());
      final paths = (j['q'] as List).cast<String>();
      final idx = j['i'] as int;
      final songs = [for (final p in paths) byPath[p]].whereType<Song>().toList();
      if (songs.isEmpty) return;
      final start = idx < paths.length ? songs.indexWhere((s) => s.path == paths[idx]) : 0;
      queue = songs;
      await audio.setAudioSources(
        [for (final s in queue) AudioSource.file(s.path, tag: _media(s))],
        initialIndex: start < 0 ? 0 : start,
        initialPosition: start < 0 ? Duration.zero : Duration(milliseconds: j['pos'] ?? 0),
      );
      await audio.setLoopMode(LoopMode.values.asNameMap()[j['loop']] ?? LoopMode.off);
      if (j['shuffle'] == true) await audio.setShuffleModeEnabled(true);
      notifyListeners();
    } catch (_) {/* sin sesion previa o archivos movidos */}
  }

  Song? get current {
    final i = audio.currentIndex;
    return i == null || i >= queue.length ? null : queue[i];
  }

  Future<void> playList(List<Song> songs, int index, {bool shuffle = false}) async {
    queue = List.of(songs);
    await audio.setShuffleModeEnabled(shuffle);
    await audio.setAudioSources(
      [for (final s in queue) AudioSource.file(s.path, tag: _media(s))],
      initialIndex: shuffle ? null : index,
    );
    if (shuffle) await audio.shuffle();
    notifyListeners();
    audio.play();
  }

  MediaItem _media(Song s) => MediaItem(
        id: s.path,
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: s.durationMs > 0 ? s.duration : null,
        artUri: s.cover == null ? null : Uri.file(s.cover!),
      );

  void toggle() => audio.playing ? audio.pause() : audio.play();

  Future<void> next() => audio.hasNext ? audio.seekToNext() : audio.seek(Duration.zero, index: 0);

  /// Como en cualquier reproductor: si ya van 3 s, "anterior" reinicia la cancion.
  Future<void> previous() =>
      audio.position > const Duration(seconds: 3) || !audio.hasPrevious ? audio.seek(Duration.zero) : audio.seekToPrevious();

  Future<void> cycleLoop() => audio.setLoopMode(switch (audio.loopMode) {
        LoopMode.off => LoopMode.all,
        LoopMode.all => LoopMode.one,
        LoopMode.one => LoopMode.off,
      });

  Future<void> toggleShuffle() async {
    final on = !audio.shuffleModeEnabled;
    if (on) await audio.shuffle();
    await audio.setShuffleModeEnabled(on);
  }

  Future<void> jumpTo(int queueIndex) => audio.seek(Duration.zero, index: queueIndex);

  Future<void> playNext(Song s) async {
    if (queue.isEmpty) return playList([s], 0);
    final at = (audio.currentIndex ?? -1) + 1;
    queue.insert(at, s);
    await audio.insertAudioSource(at, AudioSource.file(s.path, tag: _media(s)));
    notifyListeners();
  }

  Future<void> enqueue(Song s) async {
    if (queue.isEmpty) return playList([s], 0);
    queue.add(s);
    await audio.addAudioSource(AudioSource.file(s.path, tag: _media(s)));
    notifyListeners();
  }

  Future<void> removeAt(int i) async {
    if (i == audio.currentIndex) return;
    queue.removeAt(i);
    await audio.removeAudioSourceAt(i);
    notifyListeners();
  }

  /// Temporizador de apagado; null lo cancela.
  void setSleep(Duration? d) {
    _sleep?.cancel();
    sleepAt = d == null ? null : DateTime.now().add(d);
    if (d != null) {
      _sleep = Timer(d, () {
        audio.pause();
        sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }
}

/// Linea de letra sincronizada (formato LRC: "[mm:ss.xx] texto").
class LrcLine {
  LrcLine(this.at, this.text);
  final Duration at;
  final String text;
}

final _stamp = RegExp(r'\[(\d+):(\d+(?:[.:]\d+)?)\]');

/// Devuelve las lineas con tiempo, o null si la letra es texto plano.
List<LrcLine>? parseLrc(String raw) {
  final out = <LrcLine>[];
  for (final line in raw.split('\n')) {
    final stamps = _stamp.allMatches(line).toList();
    if (stamps.isEmpty) continue;
    final text = line.substring(stamps.last.end).trim();
    for (final m in stamps) {
      final secs = double.parse(m.group(2)!.replaceAll(':', '.'));
      out.add(LrcLine(Duration(minutes: int.parse(m.group(1)!), milliseconds: (secs * 1000).round()), text));
    }
  }
  if (out.isEmpty) return null;
  return out..sort((a, b) => a.at.compareTo(b.at));
}

int lrcIndexAt(List<LrcLine> lines, Duration pos) {
  var i = -1;
  for (var j = 0; j < lines.length && lines[j].at <= pos; j++) {
    i = j;
  }
  return i;
}
