"""Erzeugt das alternative App-Icon (Porträt mit Visor vor der Plattenbau-Kulisse) aus tools/icon_alt_source.png:
App-Icon-Satz „AppIconAlt“ plus Bild „IconAltImage“ für das Dock auf dem Mac. Aufruf: python3 tools/make_alt_icon.py"""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"
SOURCE = Path(__file__).resolve().parent / "icon_alt_source.png"


def main():
    big = Image.open(SOURCE).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    out = ASSETS / "AppIconAlt.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    big.save(out / "icon-1024.png")
    for s in (16, 32, 64, 128, 256, 512):
        big.resize((s, s), Image.LANCZOS).save(out / f"mac-{s}.png")
    # gleiche Größen-Zuordnung wie beim Standard-Icon
    shutil.copy(ASSETS / "AppIcon.appiconset/Contents.json", out / "Contents.json")

    image = ASSETS / "IconAltImage.imageset"
    image.mkdir(parents=True, exist_ok=True)
    big.resize((512, 512), Image.LANCZOS).save(image / "icon-alt-512.png")
    (image / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon-alt-512.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")

    docs = ROOT / "docs/assets"
    shutil.copy(ASSETS / "AppIcon.appiconset/icon-1024.png", docs / "app_icon_standard.png")
    big.save(docs / "app_icon_alternativ.png")


if __name__ == "__main__":
    main()
