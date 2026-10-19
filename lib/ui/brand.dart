import 'dart:math';

import 'package:flutter/material.dart';

import '../library.dart';
import '../main.dart';
import '../settings.dart';
import '../theme.dart';

/// Marca de Surco: un disco visto de frente. Los surcos son arcos abiertos (no
/// circulos completos) para que se lea como movimiento, y la etiqueta central
/// lleva el color de acento del tema activo.
class SurcoMark extends StatelessWidget {
  const SurcoMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(disc: l.ink, groove: l.bg, label: l.accent)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.disc, required this.groove, required this.label});
  final Color disc, groove, label;

  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide / 2;
    final o = s.center(Offset.zero);
    c.drawCircle(o, r, Paint()..color = disc);
    final g = Paint()
      ..color = groove.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * .07;
    // Tres surcos, cada uno con su hueco en un angulo distinto.
    for (final (f, start) in [(.82, -.4), (.66, 2.1), (.50, 4.0)]) {
      c.drawArc(Rect.fromCircle(center: o, radius: r * f), start, 2 * pi * .78, false, g);
    }
    c.drawCircle(o, r * .27, Paint()..color = label);
    c.drawCircle(o, r * .06, Paint()..color = disc);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.disc != disc || old.groove != groove || old.label != label;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const SurcoMark(size: 26),
      const SizedBox(width: 10),
      Text('surco', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.8, color: l.ink)),
      if (seasonIcon(settings.activePalette) case final icon?) ...[
        const SizedBox(width: 6),
        Icon(icon, size: 18, color: l.accent),
      ],
    ]);
  }
}

/// Identidad de cada lista: un icono y un tono propios segun su nombre, para
/// reconocerla de un vistazo. Las listas desconocidas toman un tono estable
/// derivado del nombre.
({IconData icon, double hue}) playlistLook(String name) {
  final n = _fold(name);
  const rules = [
    (['semana'], Icons.star_rounded, 38.0),
    (['mas escuchadas', 'top'], Icons.trending_up_rounded, 18.0),
    (['agregada', 'nueva'], Icons.new_releases_outlined, 160.0),
    (['reciente', 'historial'], Icons.history_rounded, 210.0),
    (['descubr', 'nunca'], Icons.explore_outlined, 280.0),
    (['entren', 'gym', 'ejercicio'], Icons.fitness_center_rounded, 8.0),
    (['feli', 'buen rollo', 'alegr'], Icons.wb_sunny_outlined, 45.0),
    (['trist', 'melanc'], Icons.water_drop_outlined, 220.0),
    (['romant', 'despecho', 'amor'], Icons.favorite_border_rounded, 345.0),
    (['concentr', 'estudi', 'instrumental'], Icons.psychology_outlined, 255.0),
    (['relaj', 'fondo', 'dormir', 'calma'], Icons.spa_outlined, 150.0),
    (['anime', 'videojuego', 'juego'], Icons.sports_esports_outlined, 295.0),
    (['rap', 'hip hop'], Icons.mic_none_rounded, 25.0),
    (['phonk', 'funk'], Icons.speed_rounded, 320.0),
    (['rock', 'metal'], Icons.bolt_rounded, 0.0),
    (['clasic', 'oldies', 'retro'], Icons.radio_outlined, 30.0),
  ];
  for (final (keys, icon, hue) in rules) {
    if (keys.any(n.contains)) return (icon: icon, hue: hue);
  }
  return (icon: Icons.queue_music_rounded, hue: (n.hashCode % 360).toDouble());
}

String _fold(String s) {
  const from = 'áéíóúüñ', to = 'aeiouun';
  final low = s.toLowerCase();
  return String.fromCharCodes(low.runes.map((r) {
    final i = from.indexOf(String.fromCharCode(r));
    return i < 0 ? r : to.codeUnitAt(i);
  }));
}

/// Portada de lista: fondo tenido con el tono de la lista y su icono.
class PlaylistArt extends StatelessWidget {
  const PlaylistArt({super.key, required this.name, required this.songs, this.size = 52});
  final String name;
  final List<Song> songs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final look = playlistLook(name);
    final bg = HSLColor.fromAHSL(1, look.hue, dark ? .28 : .42, dark ? .2 : .88).toColor();
    final fg = HSLColor.fromAHSL(1, look.hue, dark ? .55 : .5, dark ? .74 : .34).toColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .2),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: bg,
          child: Icon(look.icon, color: fg, size: size * .5),
        ),
      ),
    );
  }
}

/// Pequeno guino junto al logo cuando hay un tema de temporada activo.
IconData? seasonIcon(Palette p) => switch (p) {
      Palette.halloween => Icons.nights_stay_outlined,
      Palette.muertos => Icons.local_florist_outlined,
      Palette.navidad => Icons.park_outlined,
      Palette.anioNuevo => Icons.celebration_outlined,
      Palette.sanValentin => Icons.favorite_rounded,
      Palette.cumple => Icons.cake_outlined,
      _ => null,
    };
