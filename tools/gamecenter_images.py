"""Erzeugt Platzhalter-Bilder (1024 × 1024) für die Game-Center-Erfolge im Stil des Spiels:
Nachthimmel, Warnstreifen, ein Stein in der Mitte und ein Bernstein-Ring. Zum Hochladen in App Store Connect.

Aufruf: python3 tools/gamecenter_images.py   (benötigt Pillow)
Ausgabe: docs/assets/gamecenter/<erfolg>.png
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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, gem in ACHIEVEMENTS.items():
        card(gem).convert("RGB").save(OUT / f"{name}.png")
        print("✓", OUT / f"{name}.png")


if __name__ == "__main__":
    main()
