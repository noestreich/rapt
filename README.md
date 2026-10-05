# Rapt

Match-3-Spiel für iPhone und Mac im Neo-Pixel-Stil: Ostblock-Brutalismus, Plattenbauten, dunkler Nebel, Raptor-Optik.
Pixel-Art mit 22 px pro Stein, darüber modernes Licht, Partikel und Schockwellen. Stilvergleich: [docs/stilproben.html](docs/stilproben.html).

## Starten

Voraussetzungen: Mac mit Xcode 16 oder neuer, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Rapt.xcodeproj
```

1. In Xcode das Ziel **Rapt** wählen, unter *Signing & Capabilities* dein Team eintragen
   (oder `DEVELOPMENT_TEAM` in `project.yml` setzen). Bei Bedarf die Bundle-ID `de.rapt.game` ändern.
2. Oben als Ziel **My Mac** oder dein iPhone wählen und mit ⌘R starten.
3. Tests: ⌘U in Xcode, oder `swift test --package-path Packages/RaptCore`.

Nach Änderungen an `project.yml` oder neuen Dateien `xcodegen generate` erneut ausführen. Das Xcode-Projekt ist nicht eingecheckt.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `Packages/RaptCore` | Spiellogik ohne Grafik: Brett, Reihen, Züge, Schwerkraft, Kaskaden, Punkte, Plan-Stufen. Mit Tests. |
| `App/Sources/GameScene.swift` | SpriteKit-Szene: Eingabe, Ablauf, Effekt-Choreografie, Anzeige |
| `App/Sources/Effects.swift` | Pixel-Explosionen, Dampf, Schrapnell-Konfetti, Glutfunken, Strahlen, Warp-Ringe |
| `App/Sources/Art/` | Prozedurale Grafik: Steine, Nebel, Plattenbauten, Beton, Pixelschrift, Power-up-Symbole, Figur, Fresser |
| `App/Sources/Audio/` | Synthesizer, Sound-Plätze, Dateizuordnung, Musik |
| `App/Sources/SoundLabView.swift` | Sound-Labor (nur Mac, nur Debug-Build) |
| `tools/make_icon.py` | Erzeugt das App-Icon |

Die Grafik wird in einem Raster von 200 × 373 Kunst-Pixeln gebaut und **ganzzahlig** auf echte Bildschirmpixel
hochskaliert. Licht und Partikel rendern in voller Auflösung darüber.

## Spiel

- Endlos-Modus: Steine tauschen (wischen oder zweimal tippen). Das Spiel endet, wenn kein Zug **und** kein Power-up mehr übrig ist.
- Punkte: 50 pro Stein, +100 für jeden Stein über drei, multipliziert mit der Kaskadenstufe.
- „Plan“-Stufen: Plan n+1 braucht 1500 × n Punkte mehr. Jeder erfüllte Plan lässt die Figur auf den Plattenbauten
  ein Dach weiterspringen und legt ein Power-up ins Lager (drei Plätze unter der Plan-Leiste).
- Reihenfolge pro Runde über die Dächer: **Bombe → Farbtilger → Bombe → Fresser** (letztes Dach, mit Feuerwerk).
  Danach beginnt die Figur wieder vorne. Ist das Lager voll, gibt es 500 Bonuspunkte.
- Nach 7 Sekunden ohne Zug blinkt ein Hinweis.

### Power-ups

Im Lager antippen, dann:

| Power-up | Wirkung |
|---|---|
| Bombe | Feld antippen: sprengt 3 × 3 Steine |
| Farbtilger | Stein antippen: alle Steine dieser Farbe verschwinden |
| Fresser | Startet sofort: zwei Farben versteinern, 10 Sekunden lang lenkst du den Fressautomaten per Wischen und frisst alle anderen Steine |

## Sound-Labor (Mac)

Im Debug-Build auf dem Mac: Menü **Entwickler → Sound-Labor öffnen** (⇧⌘L).

- Für jede Spielaktion gibt es einen Platz. Zieh eine WAV-, MP3-, M4A-, AIFF- oder CAF-Datei darauf.
  Der Sound gilt **sofort** im laufenden Spiel.
- Pro Platz: Probehören, Lautstärke (0–2), zurücksetzen auf den eingebauten Synthesizer-Sound.
- Der Platz **Treffer** wird pro Kaskadenstufe höher abgespielt (Moll-Pentatonik). Eine kurze, trockene Datei funktioniert am besten.
- **Exportieren …** legt einen Ordner `Rapt-Sounds-JJJJMMTT-HHMM` an: alle Dateien (benannt nach ihrem Platz)
  plus `manifest.json` mit Platz, Auslöser, Originaldateiname und Lautstärke. Diesen Ordner an Claude zurückgeben;
  die Dateien kommen dann ins App-Bundle und gelten auch auf dem iPhone.

Reihenfolge der Quellen pro Platz: eigene Datei aus dem Sound-Labor → Datei im Bundle (z. B. `explosion.mp3`) → Synthesizer.

| Platz | Auslöser |
|---|---|
| `select` | Stein antippen |
| `swap` | Zwei Steine tauschen |
| `invalid` | Tausch ohne Treffer |
| `match` | Jede verschwindende Reihe, höher pro Kaskadenstufe |
| `cascade` | Ab der zweiten Kaskadenstufe, zusätzlich |
| `land` | Nachrutschende Steine setzen auf |
| `shrapnel` | Splitter bei jedem Treffer |
| `steam` | Dampfwolke bei Kaskaden |
| `explosion` | Reihe ab vier Steinen |
| `warp` | Schockwelle (Viererreihe, Kaskade ab Stufe 3) |
| `plan` | Plan erfüllt |
| `jump` | Figur springt aufs nächste Dach |
| `powerUp` | Power-up landet im Lager |
| `bomb` | Bombe zündet |
| `purge` | Farbtilger schlägt ein |
| `chomp` | Fresser frisst einen Stein (wird pro Bissen höher) |
| `gameOver` | Kein Zug und kein Power-up mehr |
| `music` | Hintergrundmusik in Schleife |

## Einstellungen

iPhone: Zahnrad oben rechts. Mac: ⌘, (Rapt → Einstellungen). Soundeffekte, Musik (je mit Lautstärke) und Haptik (iPhone)
lassen sich abschalten.
