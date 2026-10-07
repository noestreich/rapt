"""Erzeugt die App-Icons aus den Vorlagen in tools/:
  icon_alt_source.png  → „AppIcon“     (Standard: Frau mit Visor)
  rote Kugel           → „AppIconAlt“  (1. Alternative, vorher mit tools/make_icon.py erzeugen) + Dock-Bild „IconAltImage“
  icon_alt2_source.png → „AppIconAlt2“ (2. Alternative: R-Logo)                                  + Dock-Bild „IconAlt2Image“
Aufruf: python3 tools/make_icon.py && python3 tools/make_alt_icon.py"""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"
TOOLS = Path(__file__).resolve().parent
DOCS = ROOT / "docs/assets"
CONTENTS = json.loads((ASSETS / "AppIcon.appiconset/Contents.json").read_text())


def iconset(big: Image.Image, name: str):
    out = ASSETS / f"{name}.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    big.save(out / "icon-1024.png")
    for s in (16, 32, 64, 128, 256, 512):
        big.resize((s, s), Image.LANCZOS).save(out / f"mac-{s}.png")
    (out / "Contents.json").write_text(json.dumps(CONTENTS, indent=2) + "\n")


def dock_image(big: Image.Image, name: str):
    image = ASSETS / f"{name}.imageset"
    image.mkdir(parents=True, exist_ok=True)
    file = f"{name.lower()}-512.png"
    for old in image.glob("*.png"):
        old.unlink()
    big.resize((512, 512), Image.LANCZOS).save(image / file)
    (image / "Contents.json").write_text(json.dumps({
        "images": [{"filename": file, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGB").resize((1024, 1024), Image.LANCZOS)


def main():
    woman = load(TOOLS / "icon_alt_source.png")
    iconset(woman, "AppIcon")
    woman.save(DOCS / "app_icon_standard.png")

    gem = Image.open(ASSETS / "AppIconAlt.appiconset/icon-1024.png").convert("RGB")
    dock_image(gem, "IconAltImage")
    gem.save(DOCS / "app_icon_alternativ.png")

    letter = load(TOOLS / "icon_alt2_source.png")
    iconset(letter, "AppIconAlt2")
    dock_image(letter, "IconAlt2Image")
    letter.save(DOCS / "app_icon_alternativ2.png")


if __name__ == "__main__":
    main()
