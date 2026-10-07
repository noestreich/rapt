"""Rechnet Porträts für die Funk-Einblendungen auf das Pixelraster des Spiels herunter.

Aufruf: python3 tools/import_portraits.py <Ordner mit portrait_*.png>
Erwartet Querformat-Bilder (ca. 3:2). Ausgabe: App/Resources/portrait_<id>.png in 184 × 121 Kunst-Pixeln,
Palette auf 128 Farben reduziert, damit sie neben der übrigen Pixel-Art bestehen.
Dateinamen werden auf die Kontakt-IDs abgebildet (mama-zora → zora, robo-7 → robo).

Ordner je Teil in der Hand (empfohlen): <Ordner>/<Teil>/portrait_*.png, z. B. Bombe/, Bombenstein/, Strudel/, Invasion/, Abrissbirne/.
Dann schreibt das Skript App/Resources/portraits.json: welches Porträt welches Teil hält. Ein Funkspruch zeigt
nur Porträts, die genau das übergebene Teil in der Hand haben.

Varianten (alternative Porträts, die einen Kontakt zufällig vertreten):
    portrait_<kontakt>--<name>--<stimme>.png    z. B. portrait_boris--ivan--mann-tief.png
Stimmen: mann, mann-tief, frau, maedchen, junge, alt, hund, katze, roboter
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

OUT = Path(__file__).resolve().parent.parent / "App/Resources"
SIZE = (184, 121)
ALIASES = {"mama-zora": "zora", "mamazora": "zora", "robo-7": "robo", "robo7": "robo", "k-9": "k9"}
IDS = {"kira", "boris", "juki", "zora", "k9", "robo"}
# Ordnername → Schlüssel im Spiel (PowerUp.rawValue bzw. Spezialstein)
ITEMS = {"atombombe": "atom", "atom": "atom", "bombe": "bombe", "farbtilger": "farbtilger", "fresser": "fresser",
         "strudel": "strudel", "bombenstein": "bombenstein", "hyperstein": "hyperstein", "linienstein": "linienstein",
         "invasion": "invasion", "abrissbirne": "abriss", "abriss": "abriss"}
# Spezialstein → Power-up-Gruppe, deren Porträts er nutzt, wenn sein Ordner fehlt
BORROW = {"hyperstein": "farbtilger", "bombenstein": "bombe", "linienstein": "invasion"}
# Korrekturen an Dateinamen (Momo ist eine Katze)
RENAME = {"k9--momo--hund": "k9--momo--katze"}
VOICES = {"mann", "mann-tief", "frau", "maedchen", "junge", "alt", "hund", "katze", "roboter"}


def convert(src: Path, key: str = "", taken: set[str] | None = None) -> str | None:
    name = src.stem.lower().removeprefix("portrait_")
    parts = name.split("--")
    cid = ALIASES.get(parts[0], parts[0])
    if cid not in IDS:
        print(f"übersprungen: {src.name} (unbekannter Kontakt „{parts[0]}“)")
        return None
    if len(parts) == 3:
        variant = parts[1].replace(" ", "-").replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
        voice = parts[2].replace("ä", "ae")
        if voice not in VOICES:
            print(f"übersprungen: {src.name} (unbekannte Stimme „{voice}“, erlaubt: {', '.join(sorted(VOICES))})")
            return None
        cid = RENAME.get(f"{cid}--{variant}--{voice}", f"{cid}--{variant}--{voice}")
        # Gleiche Figur in zwei Ordnern (z. B. Vera bei Strudel und Hyperstein): Ordner als Zusatz nach „_“,
        # der im Spiel nicht angezeigt wird
        if taken is not None and cid in taken:
            base, name, voice = cid.split("--")
            cid = f"{base}--{name}_{key}--{voice}"
    elif len(parts) != 1:
        print(f"übersprungen: {src.name} (Format: portrait_<kontakt>--<name>--<stimme>.png)")
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
    return cid


def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    holders: dict[str, list[str]] = {}
    taken: set[str] = set()
    for sub in sorted(p for p in folder.iterdir() if p.is_dir() and not p.name.startswith("__")):
        key = ITEMS.get(sub.name.lower())
        if key is None:
            print(f"Ordner übersprungen: {sub.name} (bekannt: {', '.join(sorted(ITEMS))})")
            continue
        for src in sorted(sub.glob("portrait_*.png")):
            if cid := convert(src, key, taken):
                taken.add(cid)
                holders.setdefault(key, []).append(cid)
    # Spezialsteine ohne eigenen Ordner leihen sich die Porträts einer passenden Power-up-Gruppe
    for special, donor in BORROW.items():
        if special not in holders and donor in holders:
            holders[special] = list(holders[donor])
            print(f"{special}: keine eigenen Porträts, nutzt die von {donor}")
    if holders:
        (OUT / "portraits.json").write_text(json.dumps(holders, indent=2, ensure_ascii=False) + "\n")
        print(f"portraits.json: {', '.join(f'{k} {len(v)}' for k, v in sorted(holders.items()))}")
    else:
        for src in sorted(folder.glob("portrait_*.png")):
            convert(src)


if __name__ == "__main__":
    main()
