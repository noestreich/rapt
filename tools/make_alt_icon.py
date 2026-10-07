"""Erzeugt die alternativen App-Icons aus den Vorlagen in tools/:
  icon_alt_source.png  → „AppIconAlt“  (Icon 2, Porträt mit Visor)  + Bild „IconAltImage“ (Dock auf dem Mac)
  icon_alt2_source.png → „AppIconAlt2“ (Icon 3, R-Logo)             + Bild „IconAlt2Image“
Aufruf: python3 tools/make_alt_icon.py"""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"
TOOLS = Path(__file__).resolve().parent
ICONS = [
    ("icon_alt_source.png", "AppIconAlt", "IconAltImage", "app_icon_alternativ.png"),
    ("icon_alt2_source.png", "AppIconAlt2", "IconAlt2Image", "app_icon_alternativ2.png"),
]


def build(source: str, iconset: str, imageset: str, doc: str):
    big = Image.open(TOOLS / source).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    out = ASSETS / f"{iconset}.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    big.save(out / "icon-1024.png")
    for s in (16, 32, 64, 128, 256, 512):
        big.resize((s, s), Image.LANCZOS).save(out / f"mac-{s}.png")
    # gleiche Größen-Zuordnung wie beim Standard-Icon
    shutil.copy(ASSETS / "AppIcon.appiconset/Contents.json", out / "Contents.json")

    image = ASSETS / f"{imageset}.imageset"
    image.mkdir(parents=True, exist_ok=True)
    name = f"{imageset.lower()}-512.png"
    big.resize((512, 512), Image.LANCZOS).save(image / name)
    (image / "Contents.json").write_text(json.dumps({
        "images": [{"filename": name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
    big.save(ROOT / "docs/assets" / doc)


def main():
    shutil.copy(ASSETS / "AppIcon.appiconset/icon-1024.png", ROOT / "docs/assets/app_icon_standard.png")
    for icon in ICONS:
        build(*icon)


if __name__ == "__main__":
    main()
