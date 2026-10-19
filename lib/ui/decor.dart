import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../settings.dart';
import '../theme.dart';

/// Decoraciones de temporada dibujadas a mano (formas propias, sin imágenes).
/// Van encima de la pantalla con IgnorePointer: nunca bloquean un toque.
/// [anchorTop] es donde termina la barra superior (de ahí cuelgan la araña,
/// las luces o el papel picado).
class SeasonDecor extends StatefulWidget {
  const SeasonDecor({super.key, required this.anchorTop});
  final double anchorTop;

  @override
  State<SeasonDecor> createState() => _SeasonDecorState();
}

class _SeasonDecorState extends State<SeasonDecor> with SingleTickerProviderStateMixin {
  // Un ciclo largo y lento: casi nada de trabajo por cuadro.
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = settings.activePalette;
    if (!settings.decorations || !p.seasonal) return const SizedBox.shrink();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final l = Ledger.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DecorPainter(p, l, dark, widget.anchorTop, still ? const AlwaysStoppedAnimation(.3) : _c),
        ),
      ),
    );
  }
}

class _DecorPainter extends CustomPainter {
  _DecorPainter(this.p, this.l, this.dark, this.top, this.t) : super(repaint: t);
  final Palette p;
  final Ledger l;
  final bool dark;
  final double top;
  final Animation<double> t;

  @override
  void paint(Canvas c, Size s) {
    final v = t.value;
    switch (p) {
      case Palette.halloween:
        // Telarañas en las esquinas de la pantalla, lejos del contenido.
        _web(c, Offset(s.width, 0), 120, l.ink.withValues(alpha: .2));
        _web(c, Offset(0, s.height), 80, l.ink.withValues(alpha: .14), flip: true);
        // La araña se balancea en el hueco libre de la fila "Aleatorio".
        _spider(c, Offset(s.width * .62, top), 26 + 10 * sin(v * 2 * pi * 2), v);
        for (var i = 0; i < 2; i++) {
          final x = s.width * (1.15 - ((v + i * .5) % 1) * 1.3);
          _bat(c, Offset(x, top + 40 + i * 70 + 12 * sin((v + i) * 2 * pi * 3)), 10, v * 40 + i);
        }
      case Palette.navidad:
        _lights(c, s.width, top, v);
        _snow(c, s, v, 16);
      case Palette.muertos:
        _papelPicado(c, s.width, top, v);
      case Palette.anioNuevo:
        _confetti(c, s, v, 22, [l.accent, const Color(0xFFE2B84A), l.inkSoft]);
      case Palette.sanValentin:
        _hearts(c, s, v);
      case Palette.cumple:
        _balloons(c, s, v);
        _confetti(c, s, v, 14, [l.accent, const Color(0xFFF2B33D), const Color(0xFFE85C8A)]);
      case Palette.carnaval:
        _confetti(c, s, v, 30, const [
          Color(0xFFE0457B),
          Color(0xFFF5C518),
          Color(0xFF2BB5A5),
          Color(0xFF8E5BD8),
          Color(0xFFF28C28),
        ]);
      case Palette.sanPatricio:
        _falling(c, s, v, 10, (o, r) => _clover(c, o, r, const Color(0xFF3FA05A).withValues(alpha: .6)));
      case Palette.diaTierra:
        _falling(c, s, v, 10, (o, r) => _leaf(c, o, r, const Color(0xFF4E9A5F).withValues(alpha: .55)));
      case Palette.diaMadre:
        _falling(c, s, v, 9, (o, r) => _flower(c, o, r, l.accent.withValues(alpha: .6)));
      case Palette.intiRaymi:
        _sun(c, Offset(s.width - 10, top + 6), v);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) => old.p != p || old.l != l || old.dark != dark || old.top != top;

  // --- Halloween ---

  void _web(Canvas c, Offset corner, double r, Color color, {bool flip = false}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Radios desde la esquina hacia el interior de la pantalla.
    final base = flip ? -pi / 2 : pi / 2;
    final angles = [for (var i = 0; i <= 5; i++) base + i * (pi / 2) / 5];
    // Esquina superior derecha: angulos pi/2..pi (hacia la izquierda y abajo);
    // inferior izquierda: -pi/2..0 (hacia la derecha y arriba).
    Offset at(double a, double d) => corner + Offset(cos(a), sin(a)) * d;
    for (final a in angles) {
      c.drawLine(corner, at(a, r), paint);
    }
    for (var ring = 1; ring <= 4; ring++) {
      final d = r * ring / 4;
      final path = Path()..moveTo(at(angles.first, d).dx, at(angles.first, d).dy);
      for (var i = 1; i < angles.length; i++) {
        final mid = (angles[i - 1] + angles[i]) / 2;
        final sag = at(mid, d * .86); // hilo que cuelga entre radios
        final end = at(angles[i], d);
        path.quadraticBezierTo(sag.dx, sag.dy, end.dx, end.dy);
      }
      c.drawPath(path, paint);
    }
  }

  void _spider(Canvas c, Offset anchor, double len, double v) {
    final body = anchor + Offset(0, len);
    c.drawLine(
      anchor,
      body,
      Paint()
        ..color = l.ink.withValues(alpha: .35)
        ..strokeWidth = 1,
    );
    final ink = Paint()..color = dark ? const Color(0xFF0C0A0E) : l.ink;
    final outline = Paint()
      ..color = dark ? l.inkSoft.withValues(alpha: .7) : l.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Patas: cuatro por lado en abanico (de arriba-afuera a abajo-afuera), cada
    // una con rodilla alta y pie hacia abajo, y un leve pataleo.
    final wiggle = sin(v * 2 * pi * 6) * .12;
    for (var side = -1; side <= 1; side += 2) {
      for (var i = 0; i < 4; i++) {
        final ang = -0.9 + i * 0.55 + wiggle * (i.isEven ? 1 : -1);
        final hip = body + Offset(side * 3.0, 1.0 + i * 1.5);
        final knee = hip + Offset(side * cos(ang) * 10, sin(ang) * 10 - 4);
        final foot = knee + Offset(side * 5, 8);
        c.drawPath(
            Path()
              ..moveTo(hip.dx, hip.dy)
              ..lineTo(knee.dx, knee.dy)
              ..lineTo(foot.dx, foot.dy),
            outline);
      }
    }
    c.drawOval(Rect.fromCenter(center: body + const Offset(0, 4), width: 13, height: 15), ink);
    c.drawCircle(body - const Offset(0, 4), 5, ink);
    final eye = Paint()..color = l.accent;
    c.drawCircle(body + const Offset(-2, -4.5), 1.3, eye);
    c.drawCircle(body + const Offset(2, -4.5), 1.3, eye);
  }

  void _bat(Canvas c, Offset o, double w, double phase) {
    final flap = sin(phase * 2 * pi) * .5 + .5; // 0..1
    final paint = Paint()..color = l.ink.withValues(alpha: dark ? .55 : .45);
    final up = 6 * flap;
    final path = Path()
      ..moveTo(o.dx - w * 1.6, o.dy - up)
      ..quadraticBezierTo(o.dx - w * .9, o.dy - 2 - up * .3, o.dx - w * .7, o.dy + 3)
      ..quadraticBezierTo(o.dx - w * .4, o.dy + 1, o.dx - 2, o.dy + 4)
      ..lineTo(o.dx, o.dy - 3)
      ..lineTo(o.dx + 2, o.dy + 4)
      ..quadraticBezierTo(o.dx + w * .4, o.dy + 1, o.dx + w * .7, o.dy + 3)
      ..quadraticBezierTo(o.dx + w * .9, o.dy - 2 - up * .3, o.dx + w * 1.6, o.dy - up)
      ..quadraticBezierTo(o.dx + w * .6, o.dy - 4, o.dx, o.dy - 3)
      ..quadraticBezierTo(o.dx - w * .6, o.dy - 4, o.dx - w * 1.6, o.dy - up)
      ..close();
    c.drawPath(path, paint);
  }

  // --- Navidad ---

  void _lights(Canvas c, double w, double top, double v) {
    final wire = Paint()
      ..color = l.inkSoft.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const span = 90.0;
    const colors = [Color(0xFFE5484D), Color(0xFF46A758), Color(0xFFF5B83D), Color(0xFF3E8EDE)];
    var i = 0;
    for (var x = 0.0; x < w; x += span) {
      final a = Offset(x, top + 2), b = Offset(x + span, top + 2), mid = Offset(x + span / 2, top + 20);
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
        wire,
      );
      for (final f in [.2, .5, .8]) {
        // Punto sobre la curva cuadratica.
        final pt = Offset(
          (1 - f) * (1 - f) * a.dx + 2 * (1 - f) * f * mid.dx + f * f * b.dx,
          (1 - f) * (1 - f) * a.dy + 2 * (1 - f) * f * mid.dy + f * f * b.dy,
        );
        final glow = .55 + .45 * sin((v * 6 + i * .37) * 2 * pi);
        final col = colors[i % colors.length];
        c.drawCircle(pt + const Offset(0, 6), 7, Paint()..color = col.withValues(alpha: .18 * glow));
        c.drawOval(
          Rect.fromCenter(center: pt + const Offset(0, 6), width: 6, height: 9),
          Paint()..color = col.withValues(alpha: .6 + .4 * glow),
        );
        i++;
      }
    }
  }

  void _snow(Canvas c, Size s, double v, int n) {
    final paint = Paint()..color = (dark ? Colors.white : l.inkSoft).withValues(alpha: dark ? .45 : .22);
    for (var i = 0; i < n; i++) {
      final r = Random(i);
      final speed = .6 + r.nextDouble() * .8;
      final y = ((v * speed + r.nextDouble()) % 1) * (s.height + 20) - 10;
      final x = r.nextDouble() * s.width + 14 * sin((v * 3 + i) * 2 * pi);
      c.drawCircle(Offset(x, y), 1.5 + r.nextDouble() * 2, paint);
    }
  }

  // --- Día de Muertos ---

  void _papelPicado(Canvas c, double w, double top, double v) {
    const colors = [Color(0xFFE0457B), Color(0xFFF28C28), Color(0xFFF5C518), Color(0xFF2BB5A5), Color(0xFF8E5BD8)];
    final string = Paint()
      ..color = l.inkSoft.withValues(alpha: .5)
      ..strokeWidth = 1;
    c.drawLine(Offset(0, top + 1), Offset(w, top + 1), string);
    const fw = 34.0, fh = 30.0, gap = 8.0;
    var i = 0;
    for (var x = 6.0; x < w; x += fw + gap) {
      final sway = sin((v * 2 + i * .3) * 2 * pi) * .05;
      c.save();
      c.translate(x + fw / 2, top + 1);
      c.rotate(sway);
      final path = Path()
        ..moveTo(-fw / 2, 0)
        ..lineTo(fw / 2, 0)
        ..lineTo(fw / 2, fh);
      // Borde inferior en zigzag.
      for (var k = 0; k < 4; k++) {
        path.lineTo(fw / 2 - fw / 8 * (2 * k + 1), fh - 5);
        path.lineTo(fw / 2 - fw / 4 * (k + 1), fh);
      }
      path.close();
      final cut = Path()
        ..addOval(Rect.fromCenter(center: const Offset(0, 11), width: 9, height: 9))
        ..addPolygon([const Offset(-11, 7), const Offset(-8, 11), const Offset(-11, 15), const Offset(-14, 11)], true)
        ..addPolygon([const Offset(11, 7), const Offset(14, 11), const Offset(11, 15), const Offset(8, 11)], true)
        ..addOval(Rect.fromCenter(center: const Offset(0, 21), width: 4, height: 4));
      c.drawPath(
        Path.combine(PathOperation.difference, path, cut),
        Paint()..color = colors[i % colors.length].withValues(alpha: dark ? .75 : .85),
      );
      c.restore();
      i++;
    }
  }

  // --- Año Nuevo / Cumpleaños ---

  void _confetti(Canvas c, Size s, double v, int n, List<Color> colors) {
    for (var i = 0; i < n; i++) {
      final r = Random(100 + i);
      final y = ((v * (.7 + r.nextDouble() * .6) + r.nextDouble()) % 1) * (s.height + 30) - 15;
      final x = r.nextDouble() * s.width + 18 * sin((v * 2 + i) * 2 * pi);
      c.save();
      c.translate(x, y);
      c.rotate((v * 4 + r.nextDouble()) * 2 * pi);
      c.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3), Paint()..color = colors[i % colors.length].withValues(alpha: .7));
      c.restore();
    }
  }

  void _balloons(Canvas c, Size s, double v) {
    const colors = [Color(0xFFE85C8A), Color(0xFF4FD1C5), Color(0xFFF2B33D)];
    for (var i = 0; i < 3; i++) {
      final r = Random(200 + i);
      final x = (i.isEven ? .08 : .9) * s.width + r.nextDouble() * 20 + 8 * sin((v * 2 + i) * 2 * pi);
      final y = s.height - ((v * .8 + i / 3) % 1) * (s.height + 120) + 40;
      final col = colors[i % colors.length].withValues(alpha: .75);
      c.drawLine(
        Offset(x, y + 18),
        Offset(x - 4 + 6 * sin(v * 2 * pi * 3), y + 56),
        Paint()
          ..color = l.inkSoft.withValues(alpha: .45)
          ..strokeWidth = 1,
      );
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 26, height: 32), Paint()..color = col);
      c.drawPath(
        Path()
          ..moveTo(x - 3, y + 17)
          ..lineTo(x + 3, y + 17)
          ..lineTo(x, y + 13)
          ..close(),
        Paint()..color = col,
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x - 6, y - 7), width: 5, height: 8),
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
    }
  }

  // --- Formas que caen girando (tréboles, hojas, flores) ---

  void _falling(Canvas c, Size s, double v, int n, void Function(Offset o, double r) draw) {
    for (var i = 0; i < n; i++) {
      final r = Random(400 + i);
      final y = ((v * (.5 + r.nextDouble() * .5) + r.nextDouble()) % 1) * (s.height + 40) - 20;
      final x = r.nextDouble() * s.width + 20 * sin((v * 2 + i) * 2 * pi);
      c.save();
      c.translate(x, y);
      c.rotate(sin((v + i) * 2 * pi) * .8);
      draw(Offset.zero, 6 + r.nextDouble() * 5);
      c.restore();
    }
  }

  void _clover(Canvas c, Offset o, double r, Color color) {
    final p = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + i * 2 * pi / 3;
      c.drawCircle(o + Offset(cos(a), sin(a)) * r * .55, r * .5, p);
    }
    c.drawLine(o, o + Offset(r * .3, r * 1.2), p..strokeWidth = 1.4);
  }

  void _leaf(Canvas c, Offset o, double r, Color color) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx + r * .9, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx - r * .9, o.dy, o.dx, o.dy - r),
      Paint()..color = color,
    );
  }

  void _flower(Canvas c, Offset o, double r, Color color) {
    final p = Paint()..color = color;
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5;
      c.drawCircle(o + Offset(cos(a), sin(a)) * r * .55, r * .42, p);
    }
    c.drawCircle(o, r * .3, Paint()..color = const Color(0xFFF5C518).withValues(alpha: .8));
  }

  void _sun(Canvas c, Offset o, double v) {
    final ray = Paint()
      ..color = const Color(0xFFF6B23C).withValues(alpha: .45)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = v * 2 * pi * .5 + i * 2 * pi / 12;
      c.drawLine(o + Offset(cos(a), sin(a)) * 42, o + Offset(cos(a), sin(a)) * 62, ray);
    }
    c.drawCircle(o, 34, Paint()..color = const Color(0xFFF6B23C).withValues(alpha: .35));
  }

  // --- San Valentín ---

  void _hearts(Canvas c, Size s, double v) {
    for (var i = 0; i < 9; i++) {
      final r = Random(300 + i);
      final prog = (v * (.6 + r.nextDouble() * .5) + r.nextDouble()) % 1;
      final y = s.height - prog * (s.height * .7);
      final x = r.nextDouble() * s.width + 12 * sin((prog * 2 + i) * 2 * pi);
      final size = 7 + r.nextDouble() * 8;
      _heart(c, Offset(x, y), size, l.accent.withValues(alpha: .55 * (1 - prog)));
    }
  }
}

void _heart(Canvas c, Offset o, double size, Color color) {
  final path = Path()
    ..moveTo(o.dx, o.dy + size * .35)
    ..cubicTo(o.dx - size * 1.1, o.dy - size * .4, o.dx - size * .4, o.dy - size * 1.05, o.dx, o.dy - size * .45)
    ..cubicTo(o.dx + size * .4, o.dy - size * 1.05, o.dx + size * 1.1, o.dy - size * .4, o.dx, o.dy + size * .35)
    ..close();
  c.drawPath(path, Paint()..color = color);
}

/// Adorno estático chico para la pantalla de reproducción (entre Letra y Cola):
/// calabazas, flores, regalo, estrella, corazón o pastel según la temporada.
class SeasonBadge extends StatelessWidget {
  const SeasonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = settings.activePalette;
    if (!settings.decorations || !p.seasonal) return const SizedBox.shrink();
    return Semantics(
      label: 'Decoración de ${p.label}',
      child: CustomPaint(size: const Size(72, 40), painter: _BadgePainter(p, Ledger.of(context))),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.p, this.l);
  final Palette p;
  final Ledger l;

  @override
  void paint(Canvas c, Size s) {
    switch (p) {
      case Palette.halloween:
        _pumpkin(c, Offset(s.width * .34, s.height * .62), 15, face: true);
        _pumpkin(c, Offset(s.width * .7, s.height * .7), 11);
      case Palette.muertos:
        for (final (x, r) in [(.3, 10.0), (.55, 13.0), (.8, 9.0)]) {
          _marigold(c, Offset(s.width * x, s.height * .55), r);
        }
      case Palette.navidad:
        _gift(c, Offset(s.width / 2, s.height * .6), 15);
      case Palette.anioNuevo:
        _star(c, Offset(s.width / 2, s.height / 2), 14, const Color(0xFFE2B84A));
      case Palette.sanValentin:
        _heart(c, Offset(s.width / 2, s.height * .62), 14, l.accent);
      case Palette.cumple:
        _cake(c, Offset(s.width / 2, s.height * .62), 16);
      case Palette.carnaval:
        for (final (x, col) in [(.3, Color(0xFFE0457B)), (.5, Color(0xFFF5C518)), (.7, Color(0xFF2BB5A5))]) {
          _star(c, Offset(s.width * x, s.height * .5), 8, col);
        }
      case Palette.sanPatricio:
        _star(c, Offset(s.width / 2, s.height / 2), 0, const Color(0x00000000));
        final p = Paint()..color = const Color(0xFF3FA05A);
        final o = Offset(s.width / 2, s.height * .45);
        for (var i = 0; i < 4; i++) {
          final a = i * pi / 2 + pi / 4;
          c.drawCircle(o + Offset(cos(a), sin(a)) * 8, 7.5, p);
        }
        c.drawLine(o, o + const Offset(5, 17), p..strokeWidth = 2.4);
      case Palette.diaTierra:
        final o = Offset(s.width / 2, s.height / 2);
        c.drawCircle(o, 15, Paint()..color = const Color(0xFF3E8EDE));
        c.drawPath(
          Path()
            ..addOval(Rect.fromCenter(center: o + const Offset(-5, -4), width: 13, height: 9))
            ..addOval(Rect.fromCenter(center: o + const Offset(6, 6), width: 11, height: 8)),
          Paint()..color = const Color(0xFF4E9A5F),
        );
      case Palette.diaMadre:
        for (final (x, r) in [(.32, 9.0), (.55, 12.0), (.78, 8.0)]) {
          final o = Offset(s.width * x, s.height * .55);
          for (var i = 0; i < 5; i++) {
            final a = i * 2 * pi / 5;
            c.drawCircle(o + Offset(cos(a), sin(a)) * r * .55, r * .45, Paint()..color = l.accent);
          }
          c.drawCircle(o, r * .3, Paint()..color = const Color(0xFFF5C518));
        }
      case Palette.diaPadre:
        // Corbata.
        final o = Offset(s.width / 2, 4);
        final p = Paint()..color = l.accent;
        c.drawPath(
          Path()
            ..moveTo(o.dx - 6, o.dy)
            ..lineTo(o.dx + 6, o.dy)
            ..lineTo(o.dx + 3, o.dy + 7)
            ..lineTo(o.dx - 3, o.dy + 7)
            ..close(),
          p,
        );
        c.drawPath(
          Path()
            ..moveTo(o.dx - 3, o.dy + 7)
            ..lineTo(o.dx + 3, o.dy + 7)
            ..lineTo(o.dx + 8, o.dy + 28)
            ..lineTo(o.dx, o.dy + 35)
            ..lineTo(o.dx - 8, o.dy + 28)
            ..close(),
          p,
        );
      case Palette.intiRaymi:
        _star(c, Offset(s.width / 2, s.height / 2), 17, const Color(0xFFF6B23C));
        c.drawCircle(Offset(s.width / 2, s.height / 2), 9, Paint()..color = const Color(0xFFF28C28));
      default:
        break;
    }
  }

  void _pumpkin(Canvas c, Offset o, double r, {bool face = false}) {
    final body = Paint()..color = const Color(0xFFE8771E);
    final rib = Paint()..color = const Color(0xFFC95F10);
    c.drawOval(Rect.fromCenter(center: o, width: r * 2.3, height: r * 1.8), body);
    c.drawOval(Rect.fromCenter(center: o, width: r * 1.2, height: r * 1.8), rib);
    c.drawOval(Rect.fromCenter(center: o, width: r * .5, height: r * 1.75), body);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o - Offset(-r * .1, r * 1.0), width: r * .35, height: r * .6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF5C7A2E),
    );
    if (!face) return;
    final f = Paint()..color = const Color(0xFF2A1A0E);
    for (final dx in [-.45, .45]) {
      c.drawPath(
        Path()
          ..moveTo(o.dx + r * dx - r * .2, o.dy - r * .05)
          ..lineTo(o.dx + r * dx + r * .2, o.dy - r * .05)
          ..lineTo(o.dx + r * dx, o.dy - r * .4)
          ..close(),
        f,
      );
    }
    c.drawPath(
      Path()
        ..moveTo(o.dx - r * .6, o.dy + r * .25)
        ..quadraticBezierTo(o.dx, o.dy + r * .8, o.dx + r * .6, o.dy + r * .25)
        ..quadraticBezierTo(o.dx, o.dy + r * .5, o.dx - r * .6, o.dy + r * .25),
      f,
    );
  }

  void _marigold(Canvas c, Offset o, double r) {
    for (var ring = 0; ring < 2; ring++) {
      final paint = Paint()..color = ring == 0 ? const Color(0xFFF28C28) : const Color(0xFFF5B83D);
      final rr = r * (ring == 0 ? 1 : .65);
      for (var i = 0; i < 10; i++) {
        final a = i * 2 * pi / 10 + ring * .3;
        c.drawCircle(o + Offset(cos(a), sin(a)) * rr * .6, rr * .42, paint);
      }
    }
    c.drawCircle(o, r * .22, Paint()..color = const Color(0xFFB4530A));
  }

  void _gift(Canvas c, Offset o, double r) {
    final box = Rect.fromCenter(center: o + Offset(0, r * .2), width: r * 2, height: r * 1.5);
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = const Color(0xFFB0222F));
    final ribbon = Paint()..color = const Color(0xFFF5C518);
    c.drawRect(Rect.fromCenter(center: box.center, width: r * .35, height: box.height), ribbon);
    c.drawRect(Rect.fromLTWH(box.left, box.top - 2, box.width, r * .4), Paint()..color = const Color(0xFF8E1A24));
    for (final dx in [-1, 1]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(o.dx + dx * r * .35, box.top - r * .25), width: r * .7, height: r * .45),
        ribbon,
      );
    }
  }

  void _star(Canvas c, Offset o, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final d = i.isEven ? r : r * .45;
      final pt = o + Offset(cos(a), sin(a)) * d;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _cake(Canvas c, Offset o, double r) {
    final base = Rect.fromCenter(center: o + Offset(0, r * .3), width: r * 2.2, height: r * 1.1);
    c.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(4)), Paint()..color = const Color(0xFFF3D2B3));
    c.drawRect(Rect.fromLTWH(base.left, base.top, base.width, r * .3), Paint()..color = l.accent);
    c.drawRect(
      Rect.fromCenter(center: Offset(o.dx, base.top - r * .35), width: r * .18, height: r * .6),
      Paint()..color = const Color(0xFF7FB7E6),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(o.dx, base.top - r * .8), width: r * .25, height: r * .4),
      Paint()..color = const Color(0xFFF5B83D),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.p != p || old.l != l;
}
