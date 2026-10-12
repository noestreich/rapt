"""Vorlagen für die Funker-Porträts der neuen Minispiele: was die Figur in der Hand hält.
Pixel-Art im Stil des Spiels (Nietengrau, Rost, Neon), 32 × 32, 16-fach vergrößert.

Aufruf: python3 tools/prop_sketches.py   (benötigt Pillow)
Ausgabe: docs/assets/props/flak.png, katana.png, kurzschluss.png (512 × 512, transparent)
         und docs/assets/props/uebersicht.png (alle drei auf Nachthimmel)
"""
import math
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "docs/assets/props"
N = 32
SCALE = 16


def hexc(v, a=255):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255, a)


class Pix:
    def __init__(self):
        self.im = Image.new("RGBA", (N, N))
        self.px = self.im.load()

    def set(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.px[x, y] = hexc(c) if isinstance(c, int) else c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < N and 0 <= y < N else (0, 0, 0, 0)

    def outline(self, c=0x14121C):
        filled = {(x, y) for y in range(N) for x in range(N) if self.px[x, y][3] > 0}
        for y in range(N):
            for x in range(N):
                if (x, y) in filled:
                    continue
                if any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.set(x, y, c)


def along(x0, y0, x1, y1):
    """Punkte entlang einer Linie (ein Schritt je Pixel)."""
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        t = i / n if n else 0
        yield i, t, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)


def flak():
    """Flugabwehrrakete schräg nach oben: rote Spitze, Nietengrau mit Rost, Warnring, Leitwerk, Feuerstrahl."""
    p = Pix()
    ax, ay, bx, by = 6, 26, 25, 7          # Heck → Spitze
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length       # Längsrichtung
    nx, ny = -uy, ux                         # quer
    for y in range(N):
        for x in range(N):
            rx, ry = x + .5 - ax, y + .5 - ay
            s = rx * ux + ry * uy            # entlang
            q = rx * nx + ry * ny            # quer
            if not (0 <= s <= length):
                continue
            nose = s > length - 7
            half = 1.9 if not nose else 1.9 * (length - s) / 7 + .3
            if abs(q) > half:
                continue
            light = q > .6
            if nose:
                c = 0xFF6A3D if light else 0xE0452B
            elif length - 10 < s <= length - 7:
                c = 0xFFD23A if (int(s) % 2) else 0x14121C   # Warnring
            else:
                c = 0xB8BCC8 if light else 0x7E8494
                if (x * 7 + y * 13) % 11 == 0:
                    c = 0x8A4A2A                              # Rost
            p.set(x, y, c)
    # Leitwerk am Heck: zwei dreieckige Flossen, nach hinten gepfeilt
    for y in range(N):
        for x in range(N):
            rx, ry = x + .5 - ax, y + .5 - ay
            s = rx * ux + ry * uy
            q = abs(rx * nx + ry * ny)
            if 0 <= s <= 6 and 1.9 < q <= 1.9 + (6 - s) * .75:
                p.set(x, y, 0xB8321F if q > 3.4 else 0x4A4B56)
    p.outline()
    # Feuerstrahl hinter dem Heck
    for i in range(6):
        fx, fy = ax - ux * (2 + i), ay - uy * (2 + i)
        c = [0xFFFFFF, 0xFFE2B0, 0xFFB347, 0xFF8A3D, 0xE0452B, 0x8A2A10][i]
        for w in range(-1 if i < 4 else 0, 2 if i < 4 else 1):
            p.set(round(fx + nx * w * (1 - i / 6)), round(fy + ny * w * (1 - i / 6)), c)
    return p


def katana():
    """Katana schräg: helle Klinge mit Glanzkante und Hamon, goldenes Stichblatt, Griff mit Rautenwicklung."""
    p = Pix()
    # Klinge von Stichblatt (11,20) zur Spitze (29,2), leicht gebogen
    for i, t, x, y in along(11, 20, 29, 2):
        bend = round(math.sin(t * math.pi) * 1.2)
        x += bend
        p.set(x, y, 0xFFFFFF)
        p.set(x + 1, y, 0xD8FAFF)
        p.set(x + 1, y + 1, 0x7E8494 if t < .97 else 0xD8FAFF)
        if i % 5 == 2 and t < .9:
            p.set(x + 1, y, 0xFFFFFF)        # Hamon-Glanz
    # Stichblatt (Tsuba) quer
    for i, t, x, y in along(8, 19, 13, 24):
        p.set(x, y, 0xE8B23A)
        p.set(x + 1, y, 0xB8862A)
    p.set(10, 21, 0xFFE2B0)
    # Griff mit Rautenwicklung
    for i, t, x, y in along(10, 22, 3, 29):
        p.set(x, y, 0x15121C)
        p.set(x + 1, y, 0xB8321F if i % 2 else 0x15121C)
        p.set(x, y + 1, 0x2A2236)
    p.set(2, 30, 0xE8B23A)                    # Knauf
    p.set(3, 30, 0xE8B23A)
    p.outline(0x0B0A11)
    # Neonschimmer an der Spitze
    for x, y in ((30, 1), (28, 0), (31, 3)):
        p.set(x, y, 0x3FD8FF)
    return p


def kurzschluss():
    """Tesla-Spule für die Hand: Griff, Kupferwicklung, leuchtende Kugel, Blitze nach außen."""
    p = Pix()
    cx = 16
    # Griff und Sockel
    for y in range(24, 31):
        for x in range(cx - 2, cx + 2):
            p.set(x, y, 0x4A4B56 if x < cx else 0x7E8494)
    for x in range(cx - 4, cx + 4):
        p.set(x, 23, 0x22232B)
        p.set(x, 22, 0x7E8494)
    p.set(cx - 3, 22, 0x3FD8FF)               # Warnlicht
    # Kupferwicklung
    for y in range(13, 22):
        for x in range(cx - 3, cx + 3):
            c = 0xC8743A if y % 2 else 0x8A4A2A
            if x == cx + 2:
                c = 0x5A2E1E
            if x == cx - 3 and y % 2:
                c = 0xFFB37A
            p.set(x, y, c)
    # Kugel oben
    r = 4.6
    for y in range(N):
        for x in range(N):
            d = math.hypot(x + .5 - cx, y + .5 - 8.5)
            if d <= r:
                c = 0x3FD8FF
                if d > r - 1.2:
                    c = 0x1E6E9A
                if (x - cx) + (y - 8) < -3:
                    c = 0xD8FAFF
                p.set(x, y, c)
    p.outline()
    # Blitze von der Kugel nach außen
    bolts = [[(12, 6), (9, 4), (8, 6), (4, 3), (2, 4)],
             [(20, 6), (23, 3), (24, 5), (28, 2)],
             [(21, 10), (24, 12), (23, 14), (28, 16), (30, 15)],
             [(11, 11), (7, 13), (8, 15), (3, 17)]]
    for bolt in bolts:
        for (x0, y0), (x1, y1) in zip(bolt, bolt[1:]):
            for _, _, x, y in along(x0, y0, x1, y1):
                p.set(x, y, 0xFFFFFF)
                for qx, qy in ((x + 1, y), (x, y + 1)):
                    if p.get(qx, qy)[3] == 0:
                        p.set(qx, qy, (63, 216, 255, 170))
    return p


ITEMS = {"flak": flak, "katana": katana, "kurzschluss": kurzschluss}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    big = {}
    for name, make in ITEMS.items():
        im = make().im.resize((N * SCALE, N * SCALE), Image.NEAREST)
        im.save(OUT / f"{name}.png")
        big[name] = im
        print("✓", OUT / f"{name}.png")
    # Übersicht auf Nachthimmel
    w = N * SCALE
    sheet = Image.new("RGBA", (w * 3 + 64, w + 32))
    sp = sheet.load()
    for y in range(sheet.height):
        k = y / sheet.height
        for x in range(sheet.width):
            sp[x, y] = (int(11 + 16 * k), int(10 + 8 * k), int(17 + 26 * k), 255)
    for i, im in enumerate(big.values()):
        sheet.alpha_composite(im, (16 + i * (w + 16), 16))
    sheet.convert("RGB").save(OUT / "uebersicht.png")


if __name__ == "__main__":
    main()
