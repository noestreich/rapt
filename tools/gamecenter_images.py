"""Erzeugt Bilder (1024 × 1024, Bestenlisten zusätzlich 512 × 512) für Game Center im Stil des Spiels.
Erfolge: Nachthimmel, Warnstreifen, ein Stein in der Mitte und ein Bernstein-Ring.
Bestenlisten: Dächerlauf (Läufer springt über die Plattenbauten), Endlos (Brett mit Steinen),
Tageslauf (Abreißkalender mit Kristall unter dem Mond). Zum Hochladen in App Store Connect.

Aufruf: python3 tools/gamecenter_images.py   (benötigt Pillow)
Ausgabe: docs/assets/gamecenter/<erfolg>.png, docs/assets/gamecenter/leaderboard_<liste>[_512].png
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_assets import gem_sprite  # noqa: E402
from PIL import Image  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "docs/assets/gamecenter"
SIZE = 64          # Pixelraster, wird 16-fach vergrößert
SCALE = 1024 // SIZE

ACHIEVEMENTS = {
    "jump10": "orden",
    "jump25": "kristall",
    "cascade5": "uranglas",
    "orders10": "zahnrad",
    "minigames": "signal",
    "album": "roehre",
    "streak7": "niete",
}


def card(gem):
    im = Image.new("RGBA", (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        k = y / SIZE
        for x in range(SIZE):
            px[x, y] = (int(11 + 16 * k), int(10 + 8 * k), int(17 + 26 * k), 255)
    # Sterne
    for i in range(40):
        x = (i * 37 + 11) % SIZE
        y = (i * 53 + 7) % (SIZE // 2)
        px[x, y] = (200, 206, 235, 255)
    # Warnstreifen oben und unten
    for y in list(range(0, 4)) + list(range(SIZE - 4, SIZE)):
        for x in range(SIZE):
            px[x, y] = (184, 50, 31, 255) if ((x + y) >> 2) & 1 else (26, 20, 24, 255)
    # Ring
    c = SIZE / 2 - .5
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - c, y - c)
            if 22 <= d < 24.5:
                px[x, y] = (255, 179, 71, 255) if d < 23.5 else (122, 62, 20, 255)
            elif 20.5 <= d < 22:
                px[x, y] = (11, 10, 17, 255)
    # Stein mittig im Ring
    stone = gem_sprite(gem, 32).im
    im.alpha_composite(stone, ((SIZE - 32) // 2, (SIZE - 32) // 2))
    return im.resize((SIZE * SCALE, SIZE * SCALE), Image.NEAREST)


# ---------- Bestenlisten ----------

def hexc(v, a=255):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255, a)


def rect(px, x, y, w, h, c):
    for yy in range(max(0, y), min(SIZE, y + h)):
        for xx in range(max(0, x), min(SIZE, x + w)):
            px[xx, yy] = c


def night():
    """Nachthimmel mit Verlauf, Sternen und Warnstreifen oben und unten (wie die Erfolge)."""
    im = Image.new("RGBA", (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        k = y / SIZE
        for x in range(SIZE):
            px[x, y] = (int(11 + 16 * k), int(10 + 8 * k), int(17 + 26 * k), 255)
    for i in range(34):
        x = (i * 37 + 11) % SIZE
        y = 6 + (i * 53 + 7) % 30
        px[x, y] = (200, 206, 235, 255)
    for y in list(range(0, 4)) + list(range(SIZE - 4, SIZE)):
        for x in range(SIZE):
            px[x, y] = (184, 50, 31, 255) if ((x + y) >> 2) & 1 else (26, 20, 24, 255)
    return im, px


def glow(im, cx, cy, r, color, strength=0.35):
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x + .5 - cx, y + .5 - cy) / r
            if d >= 1:
                continue
            a = strength * (1 - d) ** 2
            p = px[x, y]
            px[x, y] = tuple(min(255, int(p[i] + color[i] * a)) for i in range(3)) + (255,)


# Läufer im Sprung (wie PowerUpArt.figureFrames().jump)
RUNNER = ["G.HHh.G", "jHHHHhj", ".HHVvVC", "..Hff..", ".jNJJj.",
          "..JJJ..", "..JCJ..", ".P...P.", "P.....P", "B.....B"]
RUNNER_PAL = {"H": 0x4A4468, "h": 0x7A70A8, "V": 0x3FD8FF, "v": 0xD8FAFF, "f": 0xD9A27A, "J": 0x3A3552,
              "j": 0x564E78, "N": 0xFF4FA8, "C": 0x3FD8FF, "P": 0x2E2C44, "B": 0x14121C, "G": 0x8E94AA}


def building(px, x, top, w, seed):
    rect(px, x, top, w, SIZE - 4 - top, hexc(0x232330))
    rect(px, x, top, w, 1, hexc(0x33333F))
    rect(px, x + w - 2, top + 1, 2, SIZE - 4 - top, hexc(0x1B1B26))
    for wy in range(top + 4, SIZE - 8, 5):
        for wx in range(x + 3, x + w - 4, 4):
            lit = ((wx * 7 + wy * 13 + seed) % 5) < 2
            rect(px, wx, wy, 2, 2, hexc(0xE8A94A) if lit else hexc(0x15141E))


def rooftop():
    im, px = night()
    # Mond und hintere Reihe mit Fernsehturm
    glow(im, 14, 14, 12, (220, 225, 255), .35)
    rect(px, 11, 11, 6, 6, hexc(0xE8ECFF))
    rect(px, 10, 12, 1, 4, hexc(0xE8ECFF))
    rect(px, 17, 12, 1, 4, hexc(0xE8ECFF))
    for x, h in [(0, 30), (9, 24), (17, 34), (27, 22), (40, 30), (50, 26)]:
        rect(px, x, SIZE - 4 - h, 9, h, hexc(0x14131C))
    rect(px, 52, 14, 2, SIZE - 18, hexc(0x191822))
    rect(px, 49, 24, 8, 3, hexc(0x191822))
    rect(px, 53, 9, 1, 5, hexc(0x191822))
    px[53, 8] = hexc(0xFF4030)
    glow(im, 53.5, 8.5, 6, (255, 70, 40), .6)
    # vordere Plattenbauten
    building(px, 2, 40, 22, 1)
    building(px, 40, 34, 22, 4)
    # Läufer im Sprung zwischen den Dächern, doppelt groß, mit Leuchtspur
    glow(im, 31, 26, 13, (63, 216, 255), .35)
    for i, (tx, ty) in enumerate([(14, 38), (18, 34), (22, 31), (26, 29)]):
        px[tx, ty] = (63, 216, 255, 255) if i % 2 else (216, 250, 255, 255)
    for y, row in enumerate(RUNNER):
        for x, ch in enumerate(row):
            if ch in RUNNER_PAL:
                rect(px, 24 + x * 2, 16 + y * 2, 2, 2, hexc(RUNNER_PAL[ch]))
    return im


def endless():
    im, px = night()
    # Brett: dunkles Feld mit Raster, Betonrahmen, darin 3 × 3 Steine
    gems = [["orden", "kristall", "uranglas"], ["roehre", "signal", "orden"], ["zahnrad", "niete", "kristall"]]
    cell, x0 = 16, 8
    rect(px, x0 - 3, x0 - 3, cell * 3 + 6, cell * 3 + 6, hexc(0x4A4B56))
    rect(px, x0 - 2, x0 - 2, cell * 3 + 4, cell * 3 + 4, hexc(0x6A6B78))
    rect(px, x0, x0, cell * 3, cell * 3, hexc(0x0A0912))
    for i in range(1, 3):
        rect(px, x0 + i * cell, x0, 1, cell * 3, hexc(0x13111E))
        rect(px, x0, x0 + i * cell, cell * 3, 1, hexc(0x13111E))
    for r, row in enumerate(gems):
        for c, gem in enumerate(row):
            stone = gem_sprite(gem, 14).im
            im.alpha_composite(stone, (x0 + c * cell + 1, x0 + r * cell + 1))
    glow(im, 32, 32, 30, (255, 179, 71), .12)
    return im


def daily():
    im, px = night()
    # Mond oben rechts
    glow(im, 51, 13, 11, (220, 225, 255), .35)
    rect(px, 48, 10, 6, 6, hexc(0xE8ECFF))
    rect(px, 47, 11, 1, 4, hexc(0xE8ECFF))
    rect(px, 54, 11, 1, 4, hexc(0xE8ECFF))
    rect(px, 50, 10, 4, 3, hexc(0x8C93B8))
    # Abreißkalender: Kopf mit Warnstreifen, Ringe, cremefarbenes Blatt, Kristall darauf
    x, y, w, h = 13, 15, 38, 42
    rect(px, x + 1, y + 1, w, h, hexc(0x050409))
    rect(px, x, y + 6, w, h - 6, hexc(0xFFF3D6))
    rect(px, x, y + h - 3, w, 3, hexc(0xD8C9A8))
    for yy in range(y, y + 7):
        for xx in range(x, x + w):
            px[xx, yy] = (184, 50, 31, 255) if ((xx + yy) >> 2) & 1 else (122, 30, 20, 255)
    for rx in (x + 8, x + w - 10):
        rect(px, rx, y - 3, 2, 6, hexc(0xB8BCC8))
        rect(px, rx, y - 3, 2, 1, hexc(0xFFFFFF))
    stone = gem_sprite("kristall", 24).im
    im.alpha_composite(stone, (x + (w - 24) // 2, y + 11))
    # Strichliste der Serie unten auf dem Blatt
    for i in range(5):
        rect(px, x + 9 + i * 4, y + h - 8, 2, 3, hexc(0x4A4B56) if i < 4 else hexc(0xB8321F))
    return im


LEADERBOARDS = {"rooftop": rooftop, "endless": endless, "daily": daily}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, gem in ACHIEVEMENTS.items():
        card(gem).convert("RGB").save(OUT / f"{name}.png")
        print("✓", OUT / f"{name}.png")
    for name, make in LEADERBOARDS.items():
        small = make()
        small.resize((1024, 1024), Image.NEAREST).convert("RGB").save(OUT / f"leaderboard_{name}.png")
        small.resize((512, 512), Image.NEAREST).convert("RGB").save(OUT / f"leaderboard_{name}_512.png")
        print("✓", OUT / f"leaderboard_{name}.png")


if __name__ == "__main__":
    main()
