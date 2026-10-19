#!/usr/bin/env python3
"""Genera el icono de Surco (mismo dibujo que SurcoMark en lib/ui/brand.dart).

Uso: python3 tool/make_icon.py   (desde la raiz del proyecto; requiere Pillow)
Escribe los PNG de mipmap (legacy, adaptativo y monocromo) y docs/logo.png.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

INK, PAPER, ACCENT = (26, 23, 20), (246, 241, 232), (224, 123, 46)
SS = 4  # supersampling para bordes suaves


def mark(size, disc=INK, groove=PAPER, label=ACCENT, scale=1.0, bg=None):
    S = size * SS
    img = Image.new("RGBA", (S, S), bg + (255,) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c, r = S / 2, S / 2 * scale
    if disc:
        d.ellipse([c - r, c - r, c + r, c + r], fill=disc + (255,))
    gw = max(1, round(r * 0.07))
    # Mezcla manual al 55 % (Pillow reemplaza pixeles, no compone alfa) = lo que pinta la app.
    g = tuple(round(gc * .55 + dc * .45) for gc, dc in zip(groove, disc)) + (255,) if disc else groove + (255,)
    for f, start in ((0.82, -0.4), (0.66, 2.1), (0.50, 4.0)):
        rr = r * f
        a0 = math.degrees(start)
        d.arc([c - rr, c - rr, c + rr, c + rr], a0, a0 + 360 * 0.78, fill=g, width=gw)
    lr = r * 0.27
    d.ellipse([c - lr, c - lr, c + lr, c + lr], fill=label + (255,))
    hr = r * 0.06
    d.ellipse([c - hr, c - hr, c + hr, c + hr], fill=(disc or (0, 0, 0)) + (255 if disc else 0,))
    return img.resize((size, size), Image.LANCZOS)


res = Path("android/app/src/main/res")
for dpi, k in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
    out = res / f"mipmap-{dpi}"
    out.mkdir(parents=True, exist_ok=True)
    # Legacy: disco a pantalla completa sobre transparente.
    mark(round(48 * k), scale=0.92).save(out / "ic_launcher.png")
    # Adaptativo (108 dp, zona segura 66 dp): solo el disco, el fondo va en color.
    mark(round(108 * k), scale=0.56).save(out / "ic_launcher_foreground.png")
    # Monocromo (Android 13 iconos tematicos): siluetas en blanco opaco.
    mark(round(108 * k), disc=None, groove=(255, 255, 255), label=(255, 255, 255), scale=0.56).save(
        out / "ic_launcher_monochrome.png")

any_dpi = res / "mipmap-anydpi-v26"
any_dpi.mkdir(exist_ok=True)
(any_dpi / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
    '</adaptive-icon>\n')
(res / "values" / "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#F6F1E8</color>\n</resources>\n')

Path("docs").mkdir(exist_ok=True)
mark(512, scale=0.92).save("docs/logo.png")
print("iconos generados")
