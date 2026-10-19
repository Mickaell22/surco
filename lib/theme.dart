import 'package:flutter/material.dart';

import 'settings.dart';

/// Paleta "ledger" (la misma familia del Facturador): papel calido, tinta,
/// un solo acento tostado. Nada de degradados ni colores chillones.
class Ledger extends ThemeExtension<Ledger> {
  const Ledger({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.sunken,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
  });

  final Color bg, surface, surfaceAlt, sunken, ink, inkSoft, muted, line, accent, accentSoft;

  static const light = Ledger(
    bg: Color(0xFFF6F1E8),
    surface: Color(0xFFFFFCF5),
    surfaceAlt: Color(0xFFFBF7EB),
    sunken: Color(0xFFF0E8D8),
    ink: Color(0xFF1A1714),
    inkSoft: Color(0xFF5A5247),
    muted: Color(0xFF8B7E6A),
    line: Color(0xFFE2D8C5),
    accent: Color(0xFFB8530A),
    accentSoft: Color(0xFFFBE9D6),
  );

  static const dark = Ledger(
    bg: Color(0xFF1A1714),
    surface: Color(0xFF221E19),
    surfaceAlt: Color(0xFF2A2520),
    sunken: Color(0xFF15110E),
    ink: Color(0xFFF6F1E8),
    inkSoft: Color(0xFFC8BDA8),
    muted: Color(0xFF9A8D78),
    line: Color(0xFF3A332C),
    accent: Color(0xFFE07B2E),
    accentSoft: Color(0xFF3A2918),
  );

  /// Cada paleta = un tono base (neutros apenas tenidos) + un acento. Papel es
  /// la original a mano; el resto se deriva igual para que todas se sientan
  /// de la misma familia.
  static Ledger forPalette(Palette p, Brightness b, {bool pureBlack = false}) {
    final dark = b == Brightness.dark;
    Ledger base;
    if (p == Palette.papel) {
      base = dark ? Ledger.dark : Ledger.light;
    } else {
      final (hue, sat, accL, accD) = switch (p) {
        Palette.grafito => (215.0, .10, const Color(0xFF2F5F95), const Color(0xFF7FA7D6)),
        Palette.bosque => (100.0, .12, const Color(0xFF3D6F3F), const Color(0xFF7AB46E)),
        Palette.oceano => (190.0, .16, const Color(0xFF1F6670), const Color(0xFF5FB3BA)),
        Palette.vino => (350.0, .12, const Color(0xFF8E2F3C), const Color(0xFFD9707E)),
        Palette.lavanda => (265.0, .12, const Color(0xFF5B4A8C), const Color(0xFFA996DC)),
        Palette.papel => throw StateError('papel'),
      };
      Color n(double l, [double s = 1]) => HSLColor.fromAHSL(1, hue, sat * s, l).toColor();
      final acc = dark ? accD : accL;
      base = dark
          ? Ledger(
              bg: n(.085), surface: n(.11), surfaceAlt: n(.135), sunken: n(.06),
              ink: n(.95, .5), inkSoft: n(.78, .6), muted: n(.58, .6), line: n(.2),
              accent: acc, accentSoft: Color.alphaBlend(acc.withValues(alpha: .18), n(.085)),
            )
          : Ledger(
              bg: n(.955), surface: n(.985), surfaceAlt: n(.97), sunken: n(.925),
              ink: n(.1, 1.5), inkSoft: n(.32), muted: n(.47, .8), line: n(.86),
              accent: acc, accentSoft: Color.alphaBlend(acc.withValues(alpha: .12), n(.985)),
            );
    }
    if (dark && pureBlack) {
      base = Ledger(
        bg: Colors.black, surface: const Color(0xFF0E0E0E), surfaceAlt: const Color(0xFF151515),
        sunken: Colors.black, ink: base.ink, inkSoft: base.inkSoft, muted: base.muted,
        line: const Color(0xFF262626), accent: base.accent, accentSoft: base.accentSoft,
      );
    }
    return base;
  }

  static Ledger of(BuildContext c) => Theme.of(c).extension<Ledger>()!;

  @override
  Ledger copyWith() => this;

  @override
  Ledger lerp(Ledger? other, double t) => t < .5 ? this : (other ?? this);
}

ThemeData buildTheme(Brightness b, Palette p, {bool pureBlack = false}) {
  final l = Ledger.forPalette(p, b, pureBlack: pureBlack);
  final scheme = ColorScheme.fromSeed(seedColor: l.accent, brightness: b).copyWith(
    primary: l.accent,
    onPrimary: l.bg,
    surface: l.bg,
    onSurface: l.ink,
    onSurfaceVariant: l.inkSoft,
    outline: l.line,
    outlineVariant: l.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: l.bg,
    extensions: [l],
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: l.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: l.bg,
      foregroundColor: l.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: l.ink, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.3),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: l.ink,
      inactiveTrackColor: l.line,
      thumbColor: l.ink,
      overlayColor: l.ink.withValues(alpha: .08),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: l.surface,
      showDragHandle: true,
      dragHandleColor: l.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: l.sunken,
      hintStyle: TextStyle(color: l.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

/// Cifras tabulares para tiempos (no "bailan" mientras avanzan).
const tabular = [FontFeature.tabularFigures()];

String fmtDur(Duration? d) {
  if (d == null) return '--:--';
  final s = d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
}
