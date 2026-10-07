"""Erzeugt das erste Alternativ-Icon im Neo-Pixel-Stil (rote Kugel): Orden-Stein auf gedithertem Nebel,
32 px hart auf 1024 px skaliert, darüber weiches Leuchten. Danach tools/make_alt_icon.py laufen lassen.
Aufruf: python3 tools/make_icon.py (benötigt Pillow)."""
import math
from pathlib import Path
from PIL import Image, ImageChops

OUT = Path(__file__).resolve().parent.parent / "App/Resources/Assets.xcassets/AppIconAlt.appiconset"
ART = 32
BAYER = [(v + .5) / 16 for v in [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]]


def h32(x, y, s):
    h = (x * 374761393 + y * 668265263 + s * 982451653) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return h / 4294967296


def vnoise(x, y, s):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a, b, c, d = h32(xi, yi, s), h32(xi + 1, yi, s), h32(xi, yi + 1, s), h32(xi + 1, yi + 1, s)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, y, s, octaves):
    t, amp, f, n = 0, .5, 1, 0
    for i in range(octaves):
        t += amp * vnoise(x * f, y * f, s + i * 17)
        n += amp
        amp *= .5
        f *= 2
    return t / n


def hsl(h, s, l):
    h %= 360
    s, l = s / 100, l / 100
    a = s * min(l, 1 - l)

    def f(n):
        k = (n + h / 30) % 12
        return l - a * max(-1, min(k - 3, 9 - k, 1))
    return tuple(round(f(n) * 255) for n in (0, 8, 4))


def poly(u, v, n, r, rot):
    return max(u * math.cos(rot + 2 * math.pi * i / n) + v * math.sin(rot + 2 * math.pi * i / n) for i in range(n)) - r


def field(u, v):
    d = poly(u, v, 8, .8, math.pi * 2 / 16)
    return d, min(1, max(0, -d / .3))


def norm(x, y, z):
    l = math.sqrt(x * x + y * y + z * z)
    return x / l, y / l, z / l


def gem(size, hue=356, sat=82, light=52):
    ramp = []
    for i in range(5):
        k = i / 4
        ramp.append(hsl(hue + (.5 - k) * 24, sat * (1 - .25 * k * k), min(95, max(0, light * (.36 + .95 * k) + (12 if k > .9 else 0)))))
    px = {}
    pad, e = 1.06, 2 / size * 1.06
    L = norm(-.55, -.7, .75)
    H = norm(L[0], L[1], L[2] + 1)
    for y in range(size):
        for x in range(size):
            u = ((x + .5) / size * 2 - 1) * pad
            v = ((y + .5) / size * 2 - 1) * pad
            if field(u, v)[0] >= 0:
                continue
            hx = (field(u + e / 2, v)[1] - field(u - e / 2, v)[1]) / e
            hy = (field(u, v + e / 2)[1] - field(u, v - e / 2)[1]) / e
            n = norm(-hx * .32, -hy * .32, 1)
            diff = max(0, sum(a * b for a, b in zip(n, L)))
            spec = max(0, sum(a * b for a, b in zip(n, H))) ** 28
            q = .15 + .95 * diff - .12 * v + spec * .9
            px[(x, y)] = ramp[int(min(.999, max(0, (q - .3) / 1.1)) * 5)]
    outline = hsl(hue, sat * .7, 7)
    inside = set(px)
    for y in range(size):
        for x in range(size):
            if (x, y) not in inside and any((x + dx, y + dy) in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[(x, y)] = outline
    return px


def main():
    purple = [(7, 6, 13), (20, 12, 34), (42, 18, 56), (74, 26, 70), (122, 38, 72)]
    img = Image.new("RGB", (ART, ART))
    for y in range(ART):
        for x in range(ART):
            n = fbm(x / 14 + 3, y / 14 + 1, 21, 4)
            density = max(0, min(1, (n - .3) * 2.4)) ** 1.2
            level = max(0, min(4, int(density * 4.4 + BAYER[(y & 3) * 4 + (x & 3)])))
            img.putpixel((x, y), purple[level])
    for (x, y), c in gem(22).items():
        img.putpixel((x + 5, y + 5), c)
    big = img.resize((1024, 1024), Image.NEAREST)
    glow = Image.new("RGB", (1024, 1024))
    gp = glow.load()
    for y in range(0, 1024):
        for x in range(0, 1024):
            d = math.hypot(x - 512, y - 512) / 520
            a = max(0, 1 - d) ** 2.2 * 0.55
            gp[x, y] = (int(255 * a), int(70 * a), int(60 * a))
    big = ImageChops.add(big, glow)
    OUT.mkdir(parents=True, exist_ok=True)
    big.save(OUT / "icon-1024.png")
    for s in (16, 32, 64, 128, 256, 512):
        big.resize((s, s), Image.LANCZOS if s < 128 else Image.NEAREST).save(OUT / f"mac-{s}.png")


if __name__ == "__main__":
    main()
