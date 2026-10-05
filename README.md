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

1. Signing: Team **aketo GmbH**, Bundle-ID **de.ncls.rapt** – beides steht in `project.yml`
   (`DEVELOPMENT_TEAM` ist die 10-stellige Team-ID) und bleibt bei jedem `xcodegen generate` erhalten.
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
| `tools/import_portraits.py` | Rechnet Porträts auf 184 × 121 Pixel mit 128 Farben herunter |
| `tools/render_assets.py` | Rendert Steine, Spezialsteine, Power-up-Symbole und Porträts als PNG nach `docs/assets/` (Python-Spiegel der Swift-Generatoren) |

Die Grafik wird in einem Raster von 200 × 373 Kunst-Pixeln gebaut und **ganzzahlig** auf echte Bildschirmpixel
hochskaliert. Licht und Partikel rendern in voller Auflösung darüber.

## Spiel

Zwei Modi, Auswahl beim Start und nach jedem Spielende. Jeder Modus hat einen eigenen Rekord.

| Modus | Ablauf |
|---|---|
| **Endlos** | Klassisch: kein Zeitdruck, keine Figur, keine Power-ups. Ende, wenn kein Zug mehr möglich ist. |
| **Dächerlauf** | Die Plattenbau-Reihe wandert langsam nach links (0,9 px/s, +9 % pro Plan; im Debug-Build per Schieber in den Einstellungen), rechts entstehen neue Häuser. Jeder erfüllte Plan lässt die Figur ein Haus weiterspringen und bringt ein Power-up. Kommt die Figur dem linken Rand nahe, blinkt „ABSTURZGEFAHR!“; wird sie hinausgeschoben, stürzt sie ab und das Spiel ist vorbei. |

- Steine tauschen: wischen oder zweimal tippen. Im Dächerlauf endet das Spiel außerdem, wenn kein Zug **und** kein Power-up mehr übrig ist.
- Punkte: 50 pro Stein, +100 für jeden Stein über drei, multipliziert mit der Kaskadenstufe.
- „Plan“-Stufen: Plan n+1 braucht 1500 × n Punkte mehr.
- Dächerlauf: Power-ups landen im Lager (drei Plätze unter der Plan-Leiste), gewichtet zufällig und nie zweimal
  dasselbe hintereinander (Bombe 32, Farbtilger 22, Strudel 18, Atombombe 16, Fresser 12). Jeder sechste Sprung
  bringt garantiert Fresser oder Atombombe, dazu Feuerwerk „HELD DER ARBEIT!“. Ist das Lager voll, gibt es 500 Bonuspunkte.
- Kurz vor dem Absturz leuchtet der ganze Bildschirmrand pulsierend rot, die Figur glüht, ein leises Netzbrummen
  setzt ein und die Musik wird leiser; alles stärker je näher am Rand (Sound-Labor-Platz `danger`, läuft als Schleife).
- Abstimmung von Tempo und Startposition: `Packages/RaptCore/Sources/RaptCore/City.swift`.
- Nach 7 Sekunden ohne Zug blinkt ein Hinweis.

### Spezialsteine

| Entsteht aus | Spezialstein | Wirkung beim Abräumen |
|---|---|---|
| Viererreihe | Linien-Stein | räumt die ganze Zeile bzw. Spalte ab |
| L- oder T-Form | Bomben-Stein | sprengt 3 × 3 |
| Fünferreihe | Hyperstein | mit einem Nachbarn tauschen: alle Steine dieser Farbe verschwinden; zwei Hypersteine räumen das ganze Brett |

Spezialsteine lösen sich gegenseitig aus (Kettenreaktionen) und werden auch von Bombe und Atombombe gezündet.

### Funksprüche

Bei jedem Power-up und beim Hyperstein schiebt sich eine Funk-Einblendung über die Punkteplatte: ein Kontakt
reicht dir den Gegenstand, dazu ein unverständlicher Funkspruch auf eigenem Audiokanal (Effekte werden solange leiser).
Der Gegenstand fliegt aus der Hand ins Lager bzw. aufs Brett; erst dann ist er verfügbar. Das Spiel läuft dabei weiter.
Abschaltbar in den Einstellungen – dann fliegt das Power-up von der Figur ins Lager.

| Kontakt | Liefert |
|---|---|
| KIRA | Linien-Stein |
| BORIS | Bomben-Stein, Bombe |
| JUKI | Farbtilger |
| MAMA ZORA | Hyperstein, Strudel |
| K-9 | Fresser |
| ROBO-7 | Atombombe |

- **Porträts:** liegen als `App/Resources/portrait_<id>.png` (`kira`, `boris`, `juki`, `zora`, `k9`, `robo`) im
  Querformat 184 × 121 und füllen die Einblendung in voller Breite. Neue Bilder (beliebige Größe, ca. 3:2) mit
  `python3 tools/import_portraits.py <Ordner>` aufs Pixelraster bringen, danach `xcodegen generate`.
  Fehlt eine Datei, erzeugt das Spiel einen 48 × 48-Platzhalter.
- **Stimmen:** Ohne Datei spricht ein Synthesizer: KIRA und JUKI hell (Mädchen), MAMA ZORA (Frau, mit Vibrato),
  BORIS tief (Mann), K-9 bellt, knurrt und winselt, ROBO-7 spricht in Tonstufen mit Piepsern.
  Eigene Aufnahmen im Sound-Labor auf die Plätze `voiceKira` … `voiceRobo` ziehen; sie bekommen automatisch Funkklang
  (Bandpass, Verzerrung, Rauschen, Klicken der Sendetaste).

### Power-ups (Dächerlauf)

Im Lager antippen, dann:

| Power-up | Wirkung |
|---|---|
| Bombe | Feld antippen: sprengt 3 × 3 Steine |
| Farbtilger | Stein antippen: alle Steine dieser Farbe verschwinden |
| Strudel | Startet sofort: alle Steine wirbeln an neue Plätze, danach ist garantiert ein Zug möglich |
| Atombombe | Feld antippen: sprengt 5 × 5 Steine |
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
| `danger` | Absturz-Alarm, läuft in Schleife (lauter je näher am Rand) |
| `voiceKira` … `voiceRobo` | Funkspruch des jeweiligen Kontakts (bekommt automatisch Funkklang) |
| `gameOver` | Kein Zug und kein Power-up mehr |
| `music` | Hintergrundmusik in Schleife |

## Musik

Elf Tracks aus dem „Action Pack 1“ von Luis Zuno ([@ansimuz](https://ansimuz.itch.io/)), frei auch für kommerzielle
Nutzung (Lizenz: `App/Resources/Music/LICENSE-music-ansimuz.txt`, Credit in den Einstellungen). Als AAC (`music_*.m4a`)
im Bundle, weil Apple-Geräte kein OGG abspielen. Pro Spiel läuft ein zufälliger Track nahtlos in Schleife, nie zweimal
derselbe hintereinander. Eine eigene Datei im Sound-Labor auf dem Platz „Hintergrundmusik“ hat Vorrang.

## Einstellungen

Zahnrad oben rechts auf der Punkteplatte (iPhone und Mac). Eigene Pixel-Ansicht über dem Spiel mit Schaltern und
Schiebereglern: Soundeffekte und Musik (je mit Lautstärke), Funksprüche, Hinweise, Haptik (iPhone), „Neues Spiel“ zur
Moduswahl und **Hilfe**: ein zweites Fenster mit allen Power-ups (Häufigkeit und Wirkung) und Spezialsteinen.
Hinweise (blinkender Rahmen nach 7 Sekunden ohne Zug) lassen sich abschalten.
Im Debug-Build zusätzlich **Stadt-Tempo** (0,2–4 px/s) und **Beschleunigung** (0–50 % pro Spielminute, relativ zum
Tempo) zum Experimentieren; die Werte gelten sofort.
Während die Einstellungen offen sind, steht die Stadt still.
