"""Baut die Übersicht aller Funker-Porträts (docs/assets/abzug_funker.png) aus den Originalen neu:
je Teil eine Zeile mit Überschrift und Anzahl, darunter die Porträts mit Name und Stimme.

Aufruf: python3 tools/make_funker_sheet.py   (benötigt Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/assets/originale/portraits"
OUT = ROOT / "docs/assets/abzug_funker.png"
ORDER = ["Hyperstein", "Bombe", "Farbtilger", "Atombombe", "Strudel", "Fresser", "Invasion", "Abrissbirne",
         "Flak", "Katana", "Kurzschluss", "Sternenbahn"]
COLS, TW, TH, GAP, PAD = 6, 276, 184, 7, 16
NAMES = {"boris": "BORIS", "juki": "JUKI", "k9": "K-9", "robo-7": "ROBO-7", "mama-zora": "MAMA ZORA", "kira": "KIRA"}


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    for base in ("/usr/share/fonts/truetype/dejavu", "/Library/Fonts", "/System/Library/Fonts/Supplemental"):
        try:
            return ImageFont.truetype(f"{base}/{name}", size)
        except OSError:
            continue
    return ImageFont.load_default()


def caption(stem):
    parts = stem.removeprefix("portrait_").split("--")
    if len(parts) == 3:
        return f"{parts[1].replace('-', ' ').upper()} · {parts[2]}"
    return f"{NAMES.get(parts[0], parts[0].upper())} · eigene Stimme"


def main():
    groups = []
    for teil in ORDER:
        files = sorted((SRC / teil).glob("portrait_*.png"))
        # Grundkontakt (eigene Stimme) ans Ende der Gruppe
        files.sort(key=lambda f: "--" not in f.stem)
        if files:
            groups.append((teil, files))
    head, cap = 26, 22
    height = PAD
    for _, files in groups:
        rows = (len(files) + COLS - 1) // COLS
        height += head + rows * (TH + cap)
    height += PAD
    width = PAD * 2 + COLS * TW + (COLS - 1) * GAP
    sheet = Image.new("RGB", (width, height), (14, 13, 20))
    d = ImageDraw.Draw(sheet)
    title, small = font(17, True), font(12)
    y = PAD
    for teil, files in groups:
        d.text((PAD, y + 4), f"{teil.upper()}  ({len(files)})", fill=(255, 179, 71), font=title)
        y += head
        for i, f in enumerate(files):
            x = PAD + (i % COLS) * (TW + GAP)
            yy = y + (i // COLS) * (TH + cap)
            sheet.paste(Image.open(f).convert("RGB").resize((TW, TH), Image.LANCZOS), (x, yy))
            d.text((x + 2, yy + TH + 4), caption(f.stem), fill=(200, 202, 214), font=small)
        y += ((len(files) + COLS - 1) // COLS) * (TH + cap)
    sheet.save(OUT, optimize=True)
    print(f"✓ {OUT.relative_to(ROOT)} ({width} × {height}, {sum(len(f) for _, f in groups)} Porträts)")


if __name__ == "__main__":
    main()
