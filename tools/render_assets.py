"""Rendert die prozeduralen Spielgrafiken als PNG, damit man sie ansehen oder als Vorlage für Artists nutzen kann.
Spiegelt die Swift-Generatoren in App/Sources/Art (GemArt, SpecialArt, PowerUpArt, PortraitArt).

Aufruf: python3 tools/render_assets.py   (benötigt Pillow)
Ausgabe: docs/assets/  (Einzeldateien in Originalgröße, *_8x.png vergrößert, uebersicht.png)
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "docs/assets"
TAU = math.pi * 2


def clamp(x, a, b):
    return max(a, min(b, x))


def hx(v, a=255):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255, a)


def hsl(h, s, l, a=255):
    h %= 360
    s, l = s / 100, l / 100
    k_a = s * min(l, 1 - l)

    def f(n):
        k = (n + h / 30) % 12
        return l - k_a * max(-1, min(k - 3, 9 - k, 1))
    return tuple(clamp(round(f(n) * 255), 0, 255) for n in (0, 8, 4)) + (a,)


def h32(x, y, s):
    h = (x * 374761393 + y * 668265263 + s * 982451653) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return h / 4294967296


class Canvas:
    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.im = Image.new("RGBA", (w, h), fill)
        self.px = self.im.load()
        self.w, self.h = w, h

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else (0, 0, 0, 0)

    def fill(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def outline(self, color):
        inside = {(x, y) for y in range(self.h) for x in range(self.w) if self.px[x, y][3] > 0}
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) not in inside and any((x + dx, y + dy) in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.px[x, y] = color


# ---------- Steine (GemArt) ----------
LOOKS = {"orden": (356, 82, 52), "zahnrad": (334, 85, 62), "signal": (47, 92, 56), "uranglas": (96, 75, 48),
         "kristall": (200, 85, 54), "roehre": (286, 62, 58), "niete": (215, 10, 72)}
GEMS = list(LOOKS)


def poly(u, v, n, r, rot):
    return max(u * math.cos(rot + TAU * i / n) + v * math.sin(rot + TAU * i / n) for i in range(n)) - r


def field(gem, u, v):
    l = math.hypot(u, v)
    if gem == "orden":
        d = poly(u, v, 8, .8, TAU / 16)
    elif gem == "zahnrad":
        # Herz (früher Zahnrad)
        d = min(math.hypot(u + .32, v + .22) - .42, math.hypot(u - .32, v + .22) - .42, poly(u, v - .02, 4, .56, TAU / 8))
    elif gem == "signal":
        d = poly(u, v * .85, 4, .56, TAU / 8)
    elif gem == "uranglas":
        d = max(poly(u, v, 4, .66, 0), poly(u, v, 4, .85, TAU / 8))
    elif gem == "kristall":
        d = poly(u, v - .25, 3, .5, TAU / 4)
    elif gem == "roehre":
        vv = v - clamp(v, -.42, .42)
        d = math.hypot(u, vv) - .38
    else:
        d = poly(u, v, 6, .76, 0)
    h = clamp(-d / .3, 0, 1)
    if gem == "niete":
        h -= .55 * clamp((.32 - l) / .07, 0, 1)
    return d, h


def norm(x, y, z):
    l = math.sqrt(x * x + y * y + z * z)
    return x / l, y / l, z / l


def gem_sprite(gem, size=22):
    hue, sat, light = LOOKS[gem]
    ramp = [hsl(hue + (.5 - k) * 24, sat * (1 - .25 * k * k), clamp(light * (.36 + .95 * k) + (12 if k > .9 else 0), 0, 95))
            for k in (i / 4 for i in range(5))]
    c = Canvas(size, size)
    pad, e = 1.06, 2 / size * 1.06
    L = norm(-.55, -.7, .75)
    H = norm(L[0], L[1], L[2] + 1)
    for y in range(size):
        for x in range(size):
            u = ((x + .5) / size * 2 - 1) * pad
            v = ((y + .5) / size * 2 - 1) * pad
            if field(gem, u, v)[0] >= 0:
                continue
            gx = (field(gem, u + e / 2, v)[1] - field(gem, u - e / 2, v)[1]) / e
            gy = (field(gem, u, v + e / 2)[1] - field(gem, u, v - e / 2)[1]) / e
            n = norm(-gx * .32, -gy * .32, 1)
            diff = max(0, sum(a * b for a, b in zip(n, L)))
            spec = max(0, sum(a * b for a, b in zip(n, H))) ** 28
            em = math.exp(-u * u / .008) * clamp((.5 - abs(v)) / .1, 0, 1) * .9 if gem == "roehre" else 0
            q = .15 + .95 * diff - .12 * v + spec * .9 + em
            c.set(x, y, ramp[int(clamp((q - .3) / 1.1, 0, .999) * 5)])
    c.outline(hsl(hue, sat * .7, 7))
    return c


# ---------- Spezialsteine (SpecialArt) ----------
def line_overlay(horizontal, size=22):
    c = Canvas(size, size)
    core, edge = hx(0xFFFFFF), hx(0xFFF3D6, 170)
    for i in range(size):
        for off, col in ((9, edge), (10, core), (11, core), (12, edge)):
            c.set(i, off, col) if horizontal else c.set(off, i, col)
    for k in range(3):
        for d in range(-k, k + 1):
            a, b = 2 - k, size - 3 + k
            for p in ((a, 10 + d), (a, 11 + d), (b, 10 + d), (b, 11 + d)):
                c.set(*p, core) if horizontal else c.set(p[1], p[0], core)
    return c


def gem_ramp(gem):
    hue, sat, light = LOOKS[gem]
    return [hsl(hue + (.5 - k) * 24, sat * (1 - .25 * k * k), clamp(light * (.36 + .95 * k) + (12 if k > .9 else 0), 0, 95))
            for k in (i / 4 for i in range(5))]


def line_flames(gem, horizontal, f=0, size=22):
    ramp = gem_ramp(gem)
    long, short = size + 12, size
    c = Canvas(long, short) if horizontal else Canvas(short, long)
    mid = short / 2
    for side in range(2):
        length = 8.0 + 2.5 * h32(f, side, 11)
        for u in range(12):
            out = u - 3
            fade = 1 - max(0, out) / length
            if fade <= 0:
                continue
            half = 4.6 * fade + .6
            for v in range(short):
                dy = abs(v + .5 - mid)
                if dy > half * (.7 + .5 * h32(u + side * 31, v, f * 7 + 3)):
                    continue
                k = fade - dy / (half + 1) * .55
                col = hx(0xFFFFFF) if k > .84 else ramp[4] if k > .48 else ramp[3] if k > .26 else ramp[2]
                along = (6 + 2 - u) if side == 0 else (long - 6 - 3 + u)
                c.set(along, v, col) if horizontal else c.set(v, along, col)
        for k in range(2):
            if h32(f, side * 5 + k, 23) < .6:
                along = int(h32(f, k, 29) * 3) if side == 0 else long - 1 - int(h32(f, k, 29) * 3)
                across = int(mid) - 3 + int(h32(f, k, 31) * 6)
                c.set(along, across, ramp[4]) if horizontal else c.set(across, along, ramp[4])
    return c


def line_stone(gem, horizontal, f=0):
    flames = line_flames(gem, horizontal, f)
    out = Canvas(flames.w, flames.h)
    out.im.alpha_composite(flames.im)
    g = gem_sprite(gem)
    out.im.alpha_composite(g.im, (6, 0) if horizontal else (0, 6))
    out.px = out.im.load()
    return out


def bomb_overlay(size=22):
    c = Canvas(size, size)
    mid = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x + .5 - mid, y + .5 - mid
            d = math.hypot(dx, dy)
            spike = abs(math.sin(math.atan2(dy, dx) * 4)) > .93
            if 9.2 <= d < 10.6:
                c.set(x, y, hx(0x24222C))
            elif spike and 10.6 <= d < 11.6:
                c.set(x, y, hx(0xFF8A3D))
    for p, col in (((16, 3), 0xFFD27A), ((17, 2), 0xFFFFFF), ((18, 3), 0xFFD27A), ((17, 4), 0xFF8A3D)):
        c.set(*p, hx(col))
    return c


def hyper_frame(f=0, frames=8, size=22):
    c = Canvas(size, size)
    mid, r = size / 2, 9.6
    for y in range(size):
        for x in range(size):
            dx, dy = x + .5 - mid, y + .5 - mid
            d = math.hypot(dx, dy)
            if d >= r:
                continue
            angle = math.atan2(dy, dx) + f / frames * TAU + d * .35
            band = int(math.floor((angle / TAU + 1) * 7)) % 7
            hue, sat, light = LOOKS[GEMS[band]]
            shade = 1 - d / r * .55 - (dy / r) * .15
            col = hsl(hue, sat, clamp(light * shade, 8, 80))
            if d < 3.2:
                col = hx(0x0B0A11)
            if d < 1.6:
                col = hx(0xFFFFFF)
            c.set(x, y, col)
    c.outline(hx(0x050409))
    c.set(7, 6, hx(0xFFFFFF))
    c.set(8, 5, hx(0xFFFFFF))
    return c


def overlay(base, top):
    out = Canvas(base.w, base.h)
    out.im = Image.alpha_composite(base.im, top.im)
    out.px = out.im.load()
    return out


# ---------- Power-ups (PowerUpArt) ----------
def sprite(rows, pal):
    c = Canvas(max(len(r) for r in rows), len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                c.set(x, y, hx(pal[ch]))
    return c


def bomb_icon():
    c = Canvas(16, 16)
    ramp = [hx(v) for v in (0x6A1208, 0xA8200F, 0xD8341E, 0xFF6A4A)]
    cx, cy, r = 7.0, 9.5, 6.2
    for y in range(16):
        for x in range(16):
            dx, dy = x + .5 - cx, y + .5 - cy
            d = math.hypot(dx, dy)
            if d <= r:
                light = .55 - (dx + dy) / (r * 2.4) - d / r * .25
                c.set(x, y, ramp[clamp(int(light * 4), 0, 3)])
    c.outline(hx(0x1A0A06))
    for y, row in enumerate([".WWW.", "WKWKW", "WWWWW", ".WKW.", ".W.W."]):
        for x, ch in enumerate(row):
            if ch == "W":
                c.set(5 + x, 8 + y, hx(0xF3E6C8))
            if ch == "K":
                c.set(5 + x, 8 + y, hx(0x1A0A06))
    c.set(4, 6, hx(0xFFC0A8)); c.set(5, 5, hx(0xFFC0A8))
    c.fill(8, 2, 3, 2, hx(0x8E94AA)); c.fill(8, 2, 3, 1, hx(0xC9CEDD))
    c.set(11, 1, hx(0xC9B08A)); c.set(12, 0, hx(0xFFD27A)); c.set(13, 1, hx(0xFFD27A)); c.set(12, 1, hx(0xFFFFFF)); c.set(14, 0, hx(0xFF8A3D))
    return c


def purge_icon():
    c = Canvas(16, 16)
    colors = [hsl(h, s, l + 6) for h, s, l in LOOKS.values()]
    for y in range(16):
        for x in range(16):
            d = abs(x - 7.5) + abs(y - 7.5) * .9
            if d <= 7:
                col = colors[clamp((y - 1) * len(colors) // 14, 0, len(colors) - 1)]
                if x < 7.5 - (7 - abs(y - 7.5) * .9) + 2:
                    col = tuple(clamp(round(v * 1.2 + 30), 0, 255) for v in col[:3]) + (255,)
                c.set(x, y, col)
            elif d <= 8:
                c.set(x, y, hx(0x120E18))
    c.set(5, 4, hx(0xFFFFFF))
    c.set(6, 3, hx(0xFFFFFF))
    return c


def spiral_icon():
    c = Canvas(16, 16)
    ramp = [hx(v) for v in (0x2A1238, 0x6A2A8A, 0xA858D8, 0xE0B0FF)]
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            d = math.hypot(dx, dy)
            if d > 7.4:
                continue
            arm = math.sin(math.atan2(dy, dx) * 2 + d * .9)
            level = clamp(int((arm * .5 + .5) * 3.2 + (1 - d / 7.4) * 1.2), 0, 3)
            c.set(x, y, hx(0x120E18) if d > 6.6 else ramp[level])
    return c


def atom_icon():
    c = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            d = math.hypot(dx, dy)
            if d > 7.6:
                continue
            a = (math.atan2(dy, dx) + math.pi / 2 + math.pi / 6) % (TAU / 3)
            blade = a < math.pi / 3 and 2.6 < d < 6.4
            c.set(x, y, hx(0x120E18 if d > 6.8 else (0x1A1418 if d < 1.6 or blade else 0xF0C23A)))
    return c


def chomper(mouth, size=18):
    c = Canvas(size, size)
    r, mid = size / 2 - 1, size / 2
    ramp = [hx(v) for v in (0x7A2A10, 0xC8501F, 0xF08A2A, 0xFFD27A)]
    for y in range(size):
        for x in range(size):
            dx, dy = x + .5 - mid, y + .5 - mid
            d = math.hypot(dx, dy)
            if d > r:
                continue
            angle = abs(math.degrees(math.atan2(dy, dx)))
            if angle < mouth:
                continue
            light = (-dx - dy) / (r * 2) + .5 - (dx * dx + dy * dy) / (r * r) * .25
            col = ramp[clamp(int(light * 4), 0, 3)]
            if mouth > 1 and angle < mouth + 9 and d > 2:
                col = hx(0xC9CEDD) if h32(x, y, 4) < .5 else hx(0x8E94AA)
            c.set(x, y, col)
    c.outline(hx(0x1A0A06))
    for p, col in (((size // 2 + 1, size // 2 - 5), 0x1A0A06), ((size // 2 + 2, size // 2 - 5), 0x1A0A06), ((size // 2 + 1, size // 2 - 6), 0xFFF3D6)):
        c.set(*p, hx(col))
    return c


# ---------- Porträts (PortraitArt) ----------
CONTACTS = [
    ("kira", "KIRA", "bob", 0xE8B58A, 0x15121C, 0x1E2236, 0x3FD8FF),
    ("boris", "BORIS", "bald", 0xC98A66, 0x2A1D18, 0x3A2A22, 0xFF8A3D),
    ("juki", "JUKI", "mohawk", 0xF0C8A8, 0xFF4FA8, 0xE8C23A, 0xFF4FA8),
    ("zora", "MAMA ZORA", "bun", 0xD9A27A, 0xB8B8C8, 0x2A1238, 0xB070FF),
    ("k9", "K-9", "dog", 0x2A2226, 0x15121C, 0x3A3A46, 0x7AF0FF),
    ("robo", "ROBO-7", "robot", 0x8E94AA, 0x585A67, 0x474854, 0xFFD23A),
]


def shade(v, f):
    return tuple(clamp(round(c * f), 0, 255) for c in hx(v)[:3]) + (255,)


def to_signed(v):
    v &= 0xFFFFFFFFFFFFFFFF
    return v - (1 << 64) if v >= (1 << 63) else v


def portrait(cid, look, skin, hair, jacket, accent):
    s = 48
    c = Canvas(s, s)
    for y in range(s):
        t = y / s
        for x in range(s):
            c.set(x, y, (round(12 + 30 * t), round(8 + 10 * t), round(30 + 40 * t), 255))
    seed = 7
    for ch in cid:
        seed = to_signed(seed * 31 + ord(ch))
    x = 0
    while x < s:
        seed = to_signed(seed * 1103515245 + 12345)
        w = 6 + abs(seed >> 8) % 7
        h = 14 + abs(seed >> 12) % 18
        c.fill(x, s - h, w - 1, h, hx(0x1A1630))
        wy = s - h + 2
        while wy < s - 2:
            wx = x + 1
            while wx < x + w - 2:
                if h32(wx, wy, seed & 0xFFFF) < .3:
                    c.set(wx, wy, hx(accent) if h32(wx, wy, 3) < .5 else hx(0xFF4FA8))
                wx += 2
            wy += 3
        x += w
    cx, cy = 25.0, 20.0
    for y in range(30, s):
        for x in range(s):
            half, dx = 11 + (y - 30) * .9, abs(x + .5 - cx)
            if dx < half:
                c.set(x, y, shade(jacket, .55) if dx > half - 1.5 else shade(jacket, 1 - dx / half * .35))
    c.fill(int(cx) - 6, 30, 12, 2, hx(accent))
    c.fill(int(cx) - 3, 26, 6, 5, shade(skin, .75))
    hw = 9.5 if look == "bald" else (9.0 if look == "robot" else 8.0)
    hh = 8.5 if look == "dog" else 10.0
    for y in range(8, 30):
        for x in range(10, 40):
            dx, dy = (x + .5 - cx) / hw, (y + .5 - cy) / hh
            inside = (abs(dx) < 1 and abs(dy) < 1) if look == "robot" else dx * dx + dy * dy < 1
            if inside:
                c.set(x, y, shade(skin, clamp(1.05 - dx * .35 - dy * .2, .5, 1.15)))
    eye = hx(accent) if look in ("robot", "dog") else hx(0x15121C)
    if look == "bob":
        for y in range(8, 26):
            for x in range(14, 37):
                dx, dy = (x + .5 - cx) / 10, (y + .5 - 17) / 10
                if dx * dx + dy * dy < 1 and (y < 15 or abs(dx) > .62):
                    c.set(x, y, shade(hair, 1.4 if y < 11 else 1))
        c.fill(13, 18, 2, 6, hx(accent))
    elif look == "bald":
        c.fill(17, 25, 16, 5, shade(hair, 1)); c.fill(19, 24, 12, 1, shade(hair, 1)); c.fill(29, 13, 1, 5, shade(skin, .6))
    elif look == "mohawk":
        for y in range(3, 14):
            w = 3 - (1 if y < 6 else 0)
            c.fill(int(cx) - w // 2 - 1, y, w + 1, 1, shade(hair, 1.2 if y < 6 else 1))
        c.fill(18, 11, 2, 9, shade(hair, .8))
    elif look == "bun":
        for y in range(3, 16):
            for x in range(14, 37):
                bun = (x - cx) ** 2 + (y - 6) ** 2 < 16
                top = ((x - cx) / 9) ** 2 + ((y - 14) / 6) ** 2 < 1 and y < 14
                if bun or top:
                    c.set(x, y, shade(hair, 1.15 if bun else 1))
        c.fill(18, 18, 6, 2, hx(0x15121C)); c.fill(27, 18, 6, 2, hx(0x15121C)); c.fill(24, 18, 3, 1, hx(0x15121C))
    elif look == "dog":
        for i in range(6):
            c.fill(15 + i // 2, 6 + i, 3, 1, shade(skin, 1.1)); c.fill(33 - i // 2, 6 + i, 3, 1, shade(skin, 1.1))
        c.fill(21, 23, 9, 5, shade(skin, .9)); c.fill(24, 23, 3, 2, hx(0x050409)); c.fill(16, 16, 18, 4, hx(0x24222C))
    elif look == "robot":
        c.fill(15, 15, 20, 7, hx(0x1A1418)); c.fill(24, 6, 2, 4, shade(skin, .8)); c.set(24, 5, hx(accent)); c.fill(19, 25, 12, 1, hx(0x1A1418))
    if look == "robot":
        c.fill(18, 17, 4, 3, eye); c.fill(28, 17, 4, 3, eye)
    elif look == "dog":
        c.fill(18, 17, 14, 2, eye)
    elif look == "bun":
        c.fill(20, 18, 2, 2, hx(accent)); c.fill(29, 18, 2, 2, hx(accent))
    else:
        c.fill(20, 18, 2, 2, eye); c.fill(29, 18, 2, 2, eye); c.set(20, 18, hx(accent)); c.set(29, 18, hx(accent))
    for i in range(s):
        for p in ((i, 0), (i, s - 1), (0, i), (s - 1, i)):
            c.set(*p, hx(0x050409))
    return c


# ---------- Ausgabe ----------
def save(c, name):
    c.im.save(OUT / f"{name}.png")
    c.im.resize((c.w * 8, c.h * 8), Image.NEAREST).save(OUT / f"{name}_8x.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    base = gem_sprite("orden")
    items = {
        "linien_stein_waagerecht": line_stone("kristall", True),
        "linien_stein_senkrecht": line_stone("kristall", False),
        "bomben_stein": overlay(base, bomb_overlay()),
        "hyperstein": hyper_frame(0),
        "power_bombe": bomb_icon(),
        "power_farbtilger": purge_icon(),
        "power_strudel": spiral_icon(),
        "power_atombombe": atom_icon(),
        "power_fresser": chomper(30, 16),
    }
    for name, c in items.items():
        save(c, name)
    for i in range(8):
        save(hyper_frame(i), f"hyperstein_frame{i}")
    for gem in GEMS:
        save(gem_sprite(gem), f"stein_{gem}")
    portraits = {}
    for cid, *_rest in CONTACTS:
        args = _rest[1:]
        # Platzhalter-Porträts nur für den Übersichtsbogen; die echten liegen in App/Resources
        portraits[cid] = portrait(cid, *args)

    # Übersichtsbogen: pro Kontakt Porträt und die gelieferten Gegenstände
    deliveries = {
        "kira": [("LINIEN-STEIN", "linien_stein_waagerecht"), ("", "linien_stein_senkrecht")],
        "boris": [("BOMBEN-STEIN", "bomben_stein"), ("BOMBE", "power_bombe")],
        "juki": [("FARBTILGER", "power_farbtilger")],
        "zora": [("HYPERSTEIN", "hyperstein"), ("STRUDEL", "power_strudel")],
        "k9": [("FRESSER", "power_fresser")],
        "robo": [("ATOMBOMBE", "power_atombombe")],
    }
    scale, row_h, pad = 4, 48 * 4 + 40, 24
    sheet = Image.new("RGBA", (pad * 2 + 48 * scale + 3 * (22 * 8 + 40), pad * 2 + row_h * len(CONTACTS)), hx(0x0F0E12))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSansMono-Bold.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    for r, (cid, label, *_x) in enumerate(CONTACTS):
        y = pad + r * row_h
        sheet.alpha_composite(portraits[cid].im.resize((48 * scale, 48 * scale), Image.NEAREST), (pad, y))
        draw.text((pad, y + 48 * scale + 6), label, fill=(232, 121, 43, 255), font=font)
        x = pad + 48 * scale + 40
        for title, name in deliveries[cid]:
            c = items[name]
            k = 8 if max(c.w, c.h) >= 22 else 11
            k = 5 if max(c.w, c.h) > 22 else k
            img = c.im.resize((c.w * k, c.h * k), Image.NEAREST)
            sheet.alpha_composite(img, (x + (176 - img.width) // 2, y + 8))
            draw.text((x, y + 48 * scale + 6), title, fill=(235, 228, 216, 255), font=font)
            x += 22 * 8 + 40
    sheet.save(OUT / "uebersicht.png")


if __name__ == "__main__":
    main()
