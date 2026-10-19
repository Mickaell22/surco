import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../library.dart';
import '../main.dart';
import '../player.dart';
import '../theme.dart';
import 'decor.dart';
import 'widgets.dart';

class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});

  static Route<void> route() => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => const NowPlaying(),
    transitionsBuilder: (_, a, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
  );

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final s = player.current;
        if (s == null) return const Scaffold();
        return Stack(
          children: [
            Scaffold(
              backgroundColor: l.bg,
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  s.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: l.inkSoft),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: 'Temporizador',
                    onPressed: () => _sleepSheet(context),
                    icon: Icon(Icons.bedtime_outlined, color: player.sleepAt != null ? l.accent : l.ink),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _showLyrics
                              ? _Lyrics(key: ValueKey('lyr${s.path}'), song: s)
                              : Center(
                                  key: ValueKey('cov${s.path}'),
                                  child: LayoutBuilder(
                                    builder: (_, c) => Hero(
                                      tag: 'cover',
                                      child: Cover(s, size: c.biggest.shortestSide.clamp(120, 420), radius: 16),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.3,
                                color: l.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, color: l.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _Seek(),
                      const SizedBox(height: 4),
                      const _Controls(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => setState(() => _showLyrics = !_showLyrics),
                            icon: Icon(_showLyrics ? Icons.image_outlined : Icons.lyrics_outlined, size: 20),
                            label: Text(_showLyrics ? 'Portada' : 'Letra'),
                            style: TextButton.styleFrom(foregroundColor: _showLyrics ? l.accent : l.inkSoft),
                          ),
                          const SeasonBadge(),
                          TextButton.icon(
                            onPressed: () => _queueSheet(context),
                            icon: const Icon(Icons.queue_music_rounded, size: 20),
                            label: const Text('Cola'),
                            style: TextButton.styleFrom(foregroundColor: l.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: SeasonDecor(anchorTop: MediaQuery.paddingOf(context).top + kToolbarHeight)),
          ],
        );
      },
    );
  }
}

class _Seek extends StatefulWidget {
  const _Seek();
  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return StreamBuilder<Duration>(
      stream: player.audio.positionStream,
      builder: (_, snap) {
        final total = player.audio.duration ?? Duration.zero;
        final max = total.inMilliseconds.toDouble();
        final pos = (_drag ?? (snap.data?.inMilliseconds ?? 0).toDouble()).clamp(0.0, max <= 0 ? 0.0 : max);
        final style = TextStyle(fontSize: 12.5, color: l.muted, fontFeatures: tabular);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(padding: EdgeInsets.zero),
              child: Slider(
                value: pos,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0 ? null : (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  player.audio.seek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmtDur(Duration(milliseconds: pos.round())), style: style),
                Text(fmtDur(total), style: style),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return StreamBuilder<PlayerState>(
      stream: player.audio.playerStateStream,
      builder: (_, snap) {
        final playing = snap.data?.playing ?? false;
        final loading = snap.data?.processingState == ProcessingState.loading;
        final shuffle = player.audio.shuffleModeEnabled;
        final loop = player.audio.loopMode;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: shuffle ? 'Aleatorio activado' : 'Aleatorio',
              onPressed: player.toggleShuffle,
              icon: Icon(Icons.shuffle_rounded, color: shuffle ? l.accent : l.muted),
            ),
            IconButton(
              tooltip: 'Anterior',
              iconSize: 36,
              onPressed: player.previous,
              icon: Icon(Icons.skip_previous_rounded, color: l.ink),
            ),
            SizedBox.square(
              dimension: 72,
              child: Material(
                color: l.ink,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: player.toggle,
                  child: Semantics(
                    label: playing ? 'Pausar' : 'Reproducir',
                    button: true,
                    child: loading
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: l.bg),
                          )
                        : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 38, color: l.bg),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Siguiente',
              iconSize: 36,
              onPressed: player.next,
              icon: Icon(Icons.skip_next_rounded, color: l.ink),
            ),
            IconButton(
              tooltip: switch (loop) {
                LoopMode.off => 'Repetir',
                LoopMode.all => 'Repetir todo',
                LoopMode.one => 'Repetir una',
              },
              onPressed: player.cycleLoop,
              icon: Icon(
                loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: loop == LoopMode.off ? l.muted : l.accent,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Letra embebida en el archivo. Si trae tiempos (LRC) resalta y sigue la linea
/// actual; si es texto plano la muestra para leer. Tocar una linea salta ahi.
class _Lyrics extends StatefulWidget {
  const _Lyrics({super.key, required this.song});
  final Song song;
  @override
  State<_Lyrics> createState() => _LyricsState();
}

class _LyricsState extends State<_Lyrics> {
  late final Future<String?> _raw = Library.lyricsOf(widget.song);
  final _scroll = ScrollController();
  int _last = -2;
  static const _lineH = 44.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return FutureBuilder<String?>(
      future: _raw,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final raw = snap.data?.trim() ?? '';
        if (raw.isEmpty) {
          return const EmptyState(
            icon: Icons.lyrics_outlined,
            title: 'Sin letra',
            body: 'Este archivo no trae la letra embebida.',
          );
        }
        final lines = parseLrc(raw);
        if (lines == null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(raw, style: TextStyle(fontSize: 17, height: 1.6, color: l.ink)),
          );
        }
        return StreamBuilder<Duration>(
          stream: player.audio.positionStream,
          builder: (context, pos) {
            final idx = lrcIndexAt(lines, pos.data ?? Duration.zero);
            if (idx != _last) {
              _last = idx;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scroll.hasClients) return;
                final target = (idx * _lineH - _scroll.position.viewportDimension * .35).clamp(
                  0.0,
                  _scroll.position.maxScrollExtent,
                );
                _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
              });
            }
            return ListView.builder(
              controller: _scroll,
              itemExtent: _lineH,
              padding: const EdgeInsets.symmetric(vertical: 24),
              itemCount: lines.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => player.audio.seek(lines[i].at),
                borderRadius: BorderRadius.circular(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lines[i].text.isEmpty ? '·' : lines[i].text,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: i == idx ? 19 : 17,
                      fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500,
                      color: i == idx ? l.ink : l.muted,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

void _queueSheet(BuildContext context) {
  final l = Ledger.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .92,
      builder: (context, scroll) => ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          // El orden visible respeta el modo aleatorio.
          final order = player.audio.shuffleModeEnabled
              ? player.audio.effectiveIndices
              : List.generate(player.queue.length, (i) => i);
          final cur = player.audio.currentIndex;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Cola',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: l.ink),
                    ),
                    const Spacer(),
                    Text('${player.queue.length} canciones', style: TextStyle(fontSize: 13, color: l.muted)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                  itemExtent: 64,
                  itemCount: order.length,
                  itemBuilder: (_, i) {
                    final qi = order[i];
                    final s = player.queue[qi];
                    return Dismissible(
                      key: ValueKey('${s.path}#$qi'),
                      direction: qi == cur ? DismissDirection.none : DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: l.sunken,
                        child: Icon(Icons.remove_circle_outline_rounded, color: l.muted),
                      ),
                      onDismissed: (_) => player.removeAt(qi),
                      child: SongTile(song: s, playing: qi == cur, onTap: () => player.jumpTo(qi)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void _sleepSheet(BuildContext context) {
  final l = Ledger.of(context);
  final options = [15, 30, 45, 60, 90];
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                player.sleepAt == null
                    ? 'Pausar la música en...'
                    : 'Se pausa a las ${TimeOfDay.fromDateTime(player.sleepAt!).format(context)}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: l.ink),
              ),
            ),
          ),
          for (final m in options)
            ListTile(
              title: Text('$m minutos', style: TextStyle(color: l.ink)),
              onTap: () {
                player.setSleep(Duration(minutes: m));
                Navigator.pop(sheet);
              },
            ),
          if (player.sleepAt != null)
            ListTile(
              title: Text('Cancelar temporizador', style: TextStyle(color: l.accent)),
              onTap: () {
                player.setSleep(null);
                Navigator.pop(sheet);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
