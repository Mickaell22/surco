import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'home.dart';
import 'widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

enum _Range {
  week('7 dias', Duration(days: 7)),
  month('30 dias', Duration(days: 30)),
  all('Siempre', null);

  const _Range(this.label, this.window);
  final String label;
  final Duration? window;
}

class _StatsPageState extends State<StatsPage> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Estadisticas')),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: stats,
        builder: (context, _) {
          final w = _range.window;
          final events = stats.since(w).toList();
          final top = stats.topSongs(library.byPath, window: w, limit: 10);
          final artists = stats.topArtists(library.byPath, window: w, limit: 5);
          final totalMs = events.fold<int>(0, (a, e) => a + e.ms);
          final distinct = events.map((e) => e.path).toSet().length;

          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            SegmentedButton<_Range>(
              showSelectedIcon: false,
              segments: [for (final r in _Range.values) ButtonSegment(value: r, label: Text(r.label))],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const SizedBox(height: 20),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Aun no hay escuchas',
                  body: 'Una cancion cuenta cuando la escuchas hasta la mitad o 4 minutos. Saltarla antes no suma.',
                ),
              )
            else ...[
              Row(children: [
                Expanded(child: _Tile(value: _hours(totalMs), label: 'escuchado')),
                const SizedBox(width: 10),
                Expanded(child: _Tile(value: '${events.length}', label: 'escuchas')),
                const SizedBox(width: 10),
                Expanded(child: _Tile(value: '$distinct', label: 'canciones')),
              ]),
              const SizedBox(height: 28),
              const _Heading('Minutos por dia'),
              const SizedBox(height: 12),
              _WeekBars(stats.minutesByWeekday(window: w)),
              const SizedBox(height: 28),
              const _Heading('Canciones mas escuchadas'),
              const SizedBox(height: 4),
              for (final (i, c) in top.indexed)
                _RankRow(
                  rank: i + 1,
                  leading: Cover(c.song, size: 40, radius: 6),
                  title: c.song.title,
                  subtitle: c.song.artist,
                  value: c.plays,
                  max: top.first.plays,
                  onTap: () => player.playList([for (final t in top) t.song], i),
                ),
              const SizedBox(height: 24),
              const _Heading('Artistas'),
              const SizedBox(height: 4),
              for (final (i, a) in artists.indexed)
                _RankRow(
                  rank: i + 1,
                  title: a.name,
                  subtitle: _hours(a.ms),
                  value: a.plays,
                  max: artists.first.plays,
                ),
            ],
            if (events.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Datos solo en este telefono.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: l.muted)),
            ],
          ]);
        },
      ),
    );
  }
}

String _hours(int ms) {
  final m = ms ~/ 60000;
  return m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Ledger.of(context).ink));
}

/// Cifra protagonista: numero grande en tinta, etiqueta pequena debajo.
class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: l.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: l.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4, color: l.ink, fontFeatures: tabular)),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12.5, color: l.inkSoft)),
      ]),
    );
  }
}

/// 7 barras verticales de un solo tono, con el valor escrito encima (son pocas:
/// etiqueta directa en vez de tooltip) y el dia debajo.
class _WeekBars extends StatelessWidget {
  const _WeekBars(this.minutes);
  final List<int> minutes;
  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _full = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final peak = minutes.reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: 'Minutos por dia: ${[for (var i = 0; i < 7; i++) '${_full[i]} ${minutes[i]}'].join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 150,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(minutes[i] == 0 ? '' : '${minutes[i]}',
                      style: TextStyle(fontSize: 11.5, color: l.inkSoft, fontFeatures: tabular)),
                  const SizedBox(height: 4),
                  Container(
                    height: peak == 0 ? 2 : (100 * minutes[i] / peak).clamp(2, 100),
                    decoration: BoxDecoration(
                      color: minutes[i] == 0 ? l.line : l.accent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_days[i], style: TextStyle(fontSize: 12.5, color: l.muted)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Fila de ranking con medidor fino proporcional al primero de la lista.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.max,
    this.leading,
    this.onTap,
  });
  final int rank, value, max;
  final String title, subtitle;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: l.muted, fontFeatures: tabular)),
          ),
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: l.ink)),
                ),
                const SizedBox(width: 8),
                Text('$value', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: l.ink, fontFeatures: tabular)),
              ]),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: l.inkSoft)),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 4,
                    width: c.maxWidth * (max == 0 ? 0 : value / max),
                    decoration: BoxDecoration(color: l.accent, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
