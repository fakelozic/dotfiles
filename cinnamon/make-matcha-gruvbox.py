#!/usr/bin/env python3
"""Build a gruvbox-hard-dark or gruvbox-charcoal recolour of Matcha-dark-pueril.

Shapes, spacing and assets stay Matcha; only colours change:
  - greys are mapped by lightness onto the variant's neutral ramp
  - the green accent family is shifted to the chosen accent
  - other saturated colours snap to the nearest palette hue
gruvbox-charcoal also keeps its accent to solid lines and indicators: in CSS, an
accent fill for a selected or pressed state becomes the menu-hover grey, and a
translucent accent becomes the same translucency of the muted grey.
The source theme (Matcha-dark-pueril from github.com/vinceliuice/Matcha-gtk-theme,
GPL-3.0) must be in ~/.themes and is never modified. The result goes to
cinnamon/themes/ next to this script, rebuilt from scratch on every run, and the
installer copies it to ~/.themes.

usage: make-matcha-gruvbox.py [variant]
  variant = aqua (default) | yellow | orange | green   gruvbox, with that accent
          | charcoal                                    gruvbox-charcoal: neutral greys, accent #fb8500
"""
import colorsys
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

SRC = Path.home() / ".themes/Matcha-dark-pueril"
ACCENTS = {"aqua": "#8ec07c", "yellow": "#fabd2f", "orange": "#fe8019", "green": "#b8bb26",
           "charcoal": "#fb8500"}
accent_name = sys.argv[1] if len(sys.argv) > 1 else "aqua"
ACCENT = ACCENTS[accent_name]
CHARCOAL = accent_name == "charcoal"
NAME = "Matcha-dark-gruvbox" if accent_name == "aqua" else f"Matcha-dark-gruvbox-{accent_name}"
DST = Path(__file__).resolve().parent / "themes" / NAME

# The GTK assets use pueril's green; the Cinnamon CSS uses Matcha's sea teal.
MATCHA_ACCENT = "#97bb72"
MATCHA_ACCENTS = [MATCHA_ACCENT, "#2eb398"] if CHARCOAL else [MATCHA_ACCENT]

# (Matcha grey, gruvbox colour) anchors, interpolated by lightness.
GRUVBOX_RAMP = [
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

# (Matcha grey, gruvbox-charcoal colour) anchors: neutral greys built up from #17191a.
CHARCOAL_RAMP = [
    ("#000000", "#000000"),
    ("#1a1a1a", "#17191a"),  # background
    ("#222222", "#1f2122"),  # surface
    ("#2d2d2d", "#2a2c2e"),  # raised
    ("#3b3b3b", "#3a3d40"),  # border
    ("#595959", "#5a5f63"),
    ("#8c8c8c", "#899095"),  # muted text
    ("#aaaaaa", "#dde1e3"),  # text
    ("#ffffff", "#ffffff"),
]
RAMP = CHARCOAL_RAMP if CHARCOAL else GRUVBOX_RAMP

# Colours other saturated colours snap to: gruvbox brights; gruvbox-charcoal uses
# them too, with its accent as the orange.
GRUVBOX_PALETTE = ["#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"]
CHARCOAL_PALETTE = ["#fb4934", "#fb8500", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"]
PALETTE = CHARCOAL_PALETTE if CHARCOAL else GRUVBOX_PALETTE

# Matcha's teal greys are further from neutral than its plain ones.
GREY_CHROMA = 40 if CHARCOAL else 14


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
MA_HLS = [hls(rgb(a)) for a in MATCHA_ACCENTS]
GA_H, GA_L, GA_S = hls(rgb(ACCENT))


def hue_dist(a, b):
    d = abs(a - b) % 1
    return min(d, 1 - d)


def accent_source(c):
    """The Matcha accent c belongs to, as (h, l, s), or None."""
    if max(c) - min(c) < GREY_CHROMA:
        return None
    h, _, s = hls(c)
    for ma in MA_HLS:
        if hue_dist(h, ma[0]) < 40 / 360 and s > 0.12:
            return ma
    return None


def mapc(c):
    r, g, b = c
    if max(c) - min(c) < GREY_CHROMA:  # neutral grey
        if max(c) <= 8 or min(c) >= 250:  # keep pure black (shadows) / white highlights
            return c
        _, l, _ = hls(c)
        for (l0, c0), (l1, c1) in zip(RAMP_L, RAMP_L[1:]):
            if l <= l1:
                t = 0 if l1 == l0 else (l - l0) / (l1 - l0)
                return tuple(round(a + (b2 - a) * t) for a, b2 in zip(c0, c1))
        return RAMP_L[-1][1]
    h, l, s = hls(c)
    ma = accent_source(c)
    if ma:  # Matcha accent family
        ma_h, ma_l, ma_s = ma
        return from_hls(GA_H + (h - ma_h), l + (GA_L - ma_l), s * GA_S / ma_s)
    ph, pl, ps = min(PAL_HLS, key=lambda p: hue_dist(p[0], h))
    return from_hls(ph, l, ps)


def hexc(c):
    return "#%02x%02x%02x" % c


HEX6 = re.compile(r"#([0-9a-fA-F]{6})\b")
HEX3 = re.compile(r"#([0-9a-fA-F]{3})(?=[;\"'),\s])")
RGBA = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*[\d.]+\s*)?\)")


def recolour_text(t, mapper=None):
    mapper = mapper or (lambda c, translucent: mapc(c))
    t = HEX6.sub(lambda m: hexc(mapper(rgb(m.group(1)), False)), t)
    t = HEX3.sub(lambda m: hexc(mapper(rgb(m.group(1)), False)), t)

    def rgba(m):
        alpha = m.group(4)
        c = mapper(tuple(int(m.group(i)) for i in (1, 2, 3)), bool(alpha) and float(alpha.strip(" ,")) < 1)
        return f"rgba({c[0]}, {c[1]}, {c[2]}{alpha})" if alpha else f"rgb({c[0]}, {c[1]}, {c[2]})"

    return RGBA.sub(rgba, t)


# gruvbox-charcoal CSS: the accent only as a solid line or indicator.
FILL_PROPS = {"background", "background-color", "background-gradient-start", "background-gradient-end",
              "selection-background-color", "-arrow-background-color"}
INDICATOR = re.compile(r"slider|level|badge|progress")
SELECTED_GREY = mapc(rgb("#313e43"))  # what Matcha's menu hover becomes
MUTED = rgb("#899095")
BLOCK = re.compile(r"([^{}]*)\{([^{}]*)\}")


def recolour_css_charcoal(t):
    def value(sel, prop, val):
        def mapper(c, translucent):
            if accent_source(c):
                if translucent:
                    return MUTED
                if prop in FILL_PROPS and not INDICATOR.search(sel + prop):
                    return SELECTED_GREY
            return mapc(c)
        # A trailing ';' so HEX3 also matches a colour at the end of the value.
        return recolour_text(val + ";", mapper)[:-1]

    def block(m):
        sel, body = m.group(1), m.group(2)
        decls = []
        for d in body.split(";"):
            prop, colon, val = d.partition(":")
            decls.append(prop + colon + value(sel, prop.strip(), val) if colon else recolour_text(d))
        return recolour_text(sel) + "{" + ";".join(decls) + "}"

    out, pos = [], 0
    for m in BLOCK.finditer(t):
        out += [recolour_text(t[pos:m.start()]), block(m)]
        pos = m.end()
    return "".join(out) + recolour_text(t[pos:])


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
    if CHARCOAL and f.suffix == ".css":
        f.write_text(recolour_css_charcoal(f.read_text()))
    elif f.suffix in (".css", ".svg", ".xml", ".rc") or f.name == "gtkrc":
        f.write_text(recolour_text(f.read_text()))
    elif f.suffix == ".png":
        recolour_png(f)

# The panel matches Alacritty's background, a shade darker than Matcha's panel grey.
panel_fill = hexc(mapc(rgb("#222222")))
for f in (DST / "cinnamon/common-assets/panel").glob("panel-*.svg"):
    f.write_text(f.read_text().replace(f"fill:{panel_fill};", "fill:#17191a;"))

print(f"built {DST} (accent {accent_name} {ACCENT})")
