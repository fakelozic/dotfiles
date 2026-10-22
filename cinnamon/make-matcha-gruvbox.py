#!/usr/bin/env python3
"""Build a gruvbox-hard-dark recolour of Matcha-dark-pueril.

Shapes, spacing and assets stay Matcha; only colours change:
  - greys are mapped by lightness onto the gruvbox neutral ramp
  - the green accent family is shifted to the chosen gruvbox accent
  - other saturated colours snap to the nearest gruvbox hue
The source theme (Matcha-dark-pueril from github.com/vinceliuice/Matcha-gtk-theme,
GPL-3.0) must be in ~/.themes and is never modified. The result goes to
cinnamon/themes/ next to this script, rebuilt from scratch on every run, and the
installer copies it to ~/.themes.

usage: make-matcha-gruvbox.py [accent]   accent = aqua (default) | yellow | orange | green
"""
import colorsys
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

SRC = Path.home() / ".themes/Matcha-dark-pueril"
ACCENTS = {"aqua": "#8ec07c", "yellow": "#fabd2f", "orange": "#fe8019", "green": "#b8bb26"}
accent_name = sys.argv[1] if len(sys.argv) > 1 else "aqua"
ACCENT = ACCENTS[accent_name]
NAME = "Matcha-dark-gruvbox" if accent_name == "aqua" else f"Matcha-dark-gruvbox-{accent_name}"
DST = Path(__file__).resolve().parent / "themes" / NAME

MATCHA_ACCENT = "#97bb72"

# (Matcha grey, gruvbox colour) anchors, interpolated by lightness.
RAMP = [
    ("#000000", "#000000"),
    ("#1a1a1a", "#17191a"),
    ("#222222", "#1d2021"),  # bg0_h
    ("#262626", "#282828"),  # bg0
    ("#363636", "#32302f"),
    ("#404040", "#3c3836"),  # bg1
    ("#525252", "#504945"),  # bg2
    ("#666666", "#665c54"),  # bg3
    ("#808080", "#7c6f64"),  # bg4
    ("#999999", "#928374"),  # gray
    ("#aaaaaa", "#a89984"),  # fg4
    ("#bababa", "#d5c4a1"),  # fg2 (text)
    ("#bfbfbf", "#ebdbb2"),  # fg
    ("#dddddd", "#f2e5bc"),
    ("#ffffff", "#fbf1c7"),  # fg0
]

# Gruvbox bright colours other saturated colours snap to.
PALETTE = ["#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"]


def rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hls(c):
    return colorsys.rgb_to_hls(*(v / 255 for v in c))


def from_hls(h, l, s):
    return tuple(round(max(0, min(1, v)) * 255) for v in colorsys.hls_to_rgb(h % 1, l, s))


RAMP_L = [(hls(rgb(a))[1], rgb(b)) for a, b in RAMP]
PAL_HLS = [hls(rgb(p)) for p in PALETTE]
MA_H, MA_L, MA_S = hls(rgb(MATCHA_ACCENT))
GA_H, GA_L, GA_S = hls(rgb(ACCENT))


def hue_dist(a, b):
    d = abs(a - b) % 1
    return min(d, 1 - d)


def mapc(c):
    r, g, b = c
    if max(c) - min(c) < 14:  # neutral grey
        if max(c) <= 8 or min(c) >= 250:  # keep pure black (shadows) / white highlights
            return c
        _, l, _ = hls(c)
        for (l0, c0), (l1, c1) in zip(RAMP_L, RAMP_L[1:]):
            if l <= l1:
                t = 0 if l1 == l0 else (l - l0) / (l1 - l0)
                return tuple(round(a + (b2 - a) * t) for a, b2 in zip(c0, c1))
        return RAMP_L[-1][1]
    h, l, s = hls(c)
    if hue_dist(h, MA_H) < 40 / 360 and s > 0.12:  # Matcha accent family
        return from_hls(GA_H + (h - MA_H), l + (GA_L - MA_L), s * GA_S / MA_S)
    ph, pl, ps = min(PAL_HLS, key=lambda p: hue_dist(p[0], h))
    return from_hls(ph, l, ps)


def hexc(c):
    return "#%02x%02x%02x" % c


HEX6 = re.compile(r"#([0-9a-fA-F]{6})\b")
HEX3 = re.compile(r"#([0-9a-fA-F]{3})(?=[;\"'),\s])")
RGBA = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*[\d.]+\s*)?\)")


def recolour_text(t):
    t = HEX6.sub(lambda m: hexc(mapc(rgb(m.group(1)))), t)
    t = HEX3.sub(lambda m: hexc(mapc(rgb(m.group(1)))), t)

    def rgba(m):
        c = mapc(tuple(int(m.group(i)) for i in (1, 2, 3)))
        alpha = m.group(4)
        return f"rgba({c[0]}, {c[1]}, {c[2]}{alpha})" if alpha else f"rgb({c[0]}, {c[1]}, {c[2]})"

    return RGBA.sub(rgba, t)


def recolour_png(p):
    im = Image.open(p)
    mode = im.mode
    im = im.convert("RGBA")
    cache = {}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = (r, g, b)
            if k not in cache:
                cache[k] = mapc(k)
            px[x, y] = (*cache[k], a)
    (im if mode == "RGBA" else im.convert(mode)).save(p)


if DST.exists():
    shutil.rmtree(DST)
DST.mkdir(parents=True)
for d in ("gtk-2.0", "gtk-3.0", "gtk-4.0", "cinnamon", "metacity-1"):
    shutil.copytree(SRC / d, DST / d, symlinks=True)
(DST / "index.theme").write_text(
    (SRC / "index.theme").read_text().replace("Matcha-dark-pueril", NAME)
)

for f in DST.rglob("*"):
    if f.is_symlink() or not f.is_file() or f.name == "thumbnail.png":
        continue
    if f.suffix in (".css", ".svg", ".xml", ".rc") or f.name == "gtkrc":
        f.write_text(recolour_text(f.read_text()))
    elif f.suffix == ".png":
        recolour_png(f)

print(f"built {DST} (accent {accent_name} {ACCENT})")
