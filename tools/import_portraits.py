"""Rechnet Porträts für die Funk-Einblendungen auf das Pixelraster des Spiels herunter.

Aufruf: python3 tools/import_portraits.py <Ordner mit portrait_*.png>
Erwartet Querformat-Bilder (ca. 3:2). Ausgabe: App/Resources/portrait_<id>.png in 184 × 121 Kunst-Pixeln,
Palette auf 128 Farben reduziert, damit sie neben der übrigen Pixel-Art bestehen.
Dateinamen werden auf die Kontakt-IDs abgebildet (mama-zora → zora, robo-7 → robo).
"""
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

OUT = Path(__file__).resolve().parent.parent / "App/Resources"
SIZE = (184, 121)
ALIASES = {"mama-zora": "zora", "mamazora": "zora", "robo-7": "robo", "robo7": "robo", "k-9": "k9"}
IDS = {"kira", "boris", "juki", "zora", "k9", "robo"}


def convert(src: Path) -> Path | None:
    name = src.stem.lower().removeprefix("portrait_")
    cid = ALIASES.get(name, name)
    if cid not in IDS:
        print(f"übersprungen: {src.name} (unbekannter Kontakt)")
        return None
    im = Image.open(src).convert("RGB")
    # auf Seitenverhältnis zuschneiden, mittig
    target = SIZE[0] / SIZE[1]
    w, h = im.size
    if w / h > target:
        nw = round(h * target)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = round(w / target)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    small = im.resize(SIZE, Image.LANCZOS)
    small = ImageEnhance.Contrast(small).enhance(1.08)
    small = ImageEnhance.Color(small).enhance(1.1)
    pixel = small.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = OUT / f"portrait_{cid}.png"
    pixel.save(out)
    print(f"{src.name} → {out.relative_to(OUT.parent.parent)}")
    return out


def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    for src in sorted(folder.glob("portrait_*.png")):
        convert(src)


if __name__ == "__main__":
    main()
