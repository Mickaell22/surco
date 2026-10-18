import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'library.dart';

/// Envoltorio fino sobre just_audio. La notificacion, la pantalla de bloqueo
/// y los botones de los audifonos Bluetooth los maneja just_audio_background.
class Player extends ChangeNotifier {
  final audio = AudioPlayer();
  List<Song> queue = [];
  Timer? _sleep;
  DateTime? sleepAt;

  Player() {
    audio.currentIndexStream.listen((_) => notifyListeners());
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
