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
| `App/Sources/Art/` | Prozedurale Grafik (der Stein `zahnrad` wird als petrolfarbener Donut gezeichnet, `GemArt.useGear` holt das Zahnrad zurück; Uranglas im Treppenschliff): Steine, Nebel, Plattenbauten, Beton, Pixelschrift, Power-up-Symbole, Figur, Fresser |
| `App/Sources/Audio/` | Synthesizer, Sound-Plätze, Dateizuordnung, Musik |
| `App/Sources/SoundLabView.swift` | Sound-Labor (nur Mac, nur Debug-Build) |
| `tools/make_icon.py` | Erzeugt das Alternativ-Icon „rote Kugel“ |
| `tools/make_alt_icon.py` | Erzeugt die App-Icons: Standard (Frau mit Visor), rote Kugel, R-Logo (in den Einstellungen 1/2/3) |
| `tools/import_portraits.py` | Rechnet Porträts auf 184 × 121 Pixel mit 128 Farben herunter |
| `tools/render_assets.py` | Rendert Steine, Spezialsteine, Power-up-Symbole und Porträts als PNG nach `docs/assets/` (Python-Spiegel der Swift-Generatoren) |

Die Grafik wird in einem Raster von 200 × 373 Kunst-Pixeln gebaut und **ganzzahlig** auf echte Bildschirmpixel
hochskaliert. Licht und Partikel rendern in voller Auflösung darüber.

## Spiel

Zwei Modi, Auswahl beim Start und nach jedem Spielende. Jeder Modus hat einen eigenen Rekord. Nach der Installation
ist der Dächerlauf vorausgewählt, danach der zuletzt gespielte Modus.

| Modus | Ablauf |
|---|---|
| **Dächerlauf** | Die Plattenbau-Reihe wandert langsam nach links (0,66 px/s, +9 % pro Plan, +6 % pro Spielminute; per Debug-Regler in den Einstellungen änderbar), rechts entstehen neue Häuser. Jeder erfüllte Plan lässt die Figur ein Haus weiterspringen und bringt ein Power-up. Kommt die Figur dem linken Rand nahe, blinkt „ABSTURZGEFAHR!“; wird sie hinausgeschoben, stürzt sie ab und das Spiel ist vorbei. |
| **Endlos** | Klassisch: kein Zeitdruck, keine Power-ups; der Läufer steht auf seinem Dach, die Stadt steht still; bei jedem geschafften Sprung hüpft er einmal hoch. Ende, wenn kein Zug mehr möglich ist. |

- Steine tauschen: wischen oder zweimal tippen. Im Dächerlauf endet das Spiel außerdem, wenn kein Zug **und** kein Power-up mehr übrig ist.
- Punkte: 50 pro Stein, +100 für jeden Stein über drei, multipliziert mit der Kaskadenstufe.
- Sprung-Leiste unter dem Brett: Sprung n braucht 1500 × n Punkte (Sprung 1: 1500, Sprung 2: +3000 …).
- Dächerlauf: Power-ups landen im Lager (drei Plätze unter der Plan-Leiste), gewichtet zufällig und nie zweimal
  dasselbe hintereinander (Bombe 30, Farbtilger 21, Strudel 16, Atombombe 12, Fresser 9, Invasion 6, Abrissbirne 6). Jeder sechste Sprung
  bringt garantiert ein seltenes Power-up (Fresser, Atombombe, Invasion oder Abrissbirne, je 25 %), dazu Feuerwerk „HELD DER ARBEIT!“. Ist das Lager voll, gibt es 500 Bonuspunkte.
- Kurz vor dem Absturz leuchtet der ganze Bildschirmrand pulsierend rot, die Figur glüht, ein leises Netzbrummen
  setzt ein, dazu ein dezentes Tick–Tack wie ein Parksensor, das schneller wird (Sound-Labor-Plätze `danger` und
  `dangerTick`); die Musik wird nur ganz leicht zurückgenommen.
- Abstimmung von Tempo und Startposition: `Packages/RaptCore/Sources/RaptCore/City.swift`.
- Nach 7 Sekunden ohne Zug blinkt ein Hinweis.

### Minispiele

Zwei Power-ups starten ein kurzes Arcade-Minispiel. Davor knallt ein Manga-Auftakt ins Bild: weißer Blitz,
Schwarz-Weiß-Flackern (normal und invertiert), Konzentrationslinien, Zoom aufs Brett und der Titel mit Farbsaum.
Sprung-Leiste und Lager blenden aus; das Fluggerät steigt hinter den Häusern auf und fliegt frei über dem Nachthimmel unter dem Brett, der Läufer springt vom Dach in die Kabine und am Ende wieder zurück, das leere Gerät sinkt hinter die Häuser. Getroffene Steine zerplatzen sofort mit Konfetti und Glow;
nach Ablauf der Zeit fallen neue Steine nach, Spezialsteine unter den Treffern zünden, Kaskaden laufen wie gewohnt.

| Power-up | Vorbild | Ablauf |
|---|---|---|
| **Invasion** (9 s) | Space Invaders | Der Läufer sitzt in einem dunklen Neon-Gleiter (ziehen; gleitet mit Trägheit, Seitendüsen zeigen den Schub) und schießt automatisch aus der Kanone nach oben; jeder Schuss trifft den untersten Stein seiner Spalte. Die Steine marschieren im Takt, der schneller wird, und werfen Zickzack-Geschosse (Treffer lähmen kurz). Zweimal fliegt ein UFO vorbei: Abschuss → Blitze in sechs Steine. |
| **Abrissbirne** (12 s) | Arkanoid, Raptor | Der Läufer steuert einen kastigen, rostigen Glider (ziehen, folgt dem Finger direkt); vom flachen Dach prallt eine glühende Abrissbirne in die Steine, die mit jedem Treffer schneller wird. Bei jedem Aufprall taucht der Glider kurz ab und feuert zwei Leuchtspur-Salven. Manga-Lautmalerei bei Treffer-Serien. Fällt die Birne herunter, liegt kurz danach eine neue auf dem Dach. |

Code: `App/Sources/Arcade.swift` (Runden, Manga-Filter), Grafik: `App/Sources/Art/ArcadeArt.swift`.

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
| KIRA | Linien-Stein, Invasion |
| BORIS | Bomben-Stein, Bombe, Abrissbirne |
| JUKI | Farbtilger |
| MAMA ZORA | Hyperstein, Strudel |
| K-9 | Fresser |
| ROBO-7 | Atombombe |

- **Porträts:** liegen als `App/Resources/portrait_<id>.png` (`kira`, `boris`, `juki`, `zora`, `k9`, `robo`) im
  Querformat 184 × 121 und füllen die Einblendung in voller Breite. Neue Bilder (beliebige Größe, ca. 3:2) mit
  `python3 tools/import_portraits.py <Ordner>` aufs Pixelraster bringen, danach `xcodegen generate`.
  Fehlt eine Datei, erzeugt das Spiel einen 48 × 48-Platzhalter.
- **Varianten:** `portrait_<kontakt>--<name>--<stimme>.png` (z. B. `portrait_boris--ivan--mann-tief.png`) vertritt den
  Kontakt zufällig, mit eigenem Namen und eigener Stimme. Stimmen: `mann`, `mann-tief`, `frau`, `maedchen`, `junge`,
  `alt`, `hund`, `katze`, `roboter`. Ebenfalls mit `tools/import_portraits.py` einspielen.
- **Wer hält was:** Liegen die Bilder in Ordnern je Teil (`Atombombe/`, `Bombe/`, `Bombenstein/`, `Farbtilger/`,
  `Fresser/`, `Hyperstein/`, `Linienstein/`, `Strudel/`), schreibt das Skript `App/Resources/portraits.json`.
  Ein Funkspruch zeigt dann nur Porträts, die genau das übergebene Teil in der Hand haben.
  Fehlt ein Ordner für einen Spezialstein, leiht er sich eine Gruppe: Hyperstein → Farbtilger,
  Bombenstein → Bombe, Linienstein → Invasion.
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
| `glitch` | Funkrauschen bei jeder Bildstörung kurz vor dem Absturz (mitgeliefert: `glitch.wav`) |
| `voiceKira` … `voiceRobo` | Funkspruch des jeweiligen Kontakts (bekommt automatisch Funkklang) |
| `gameOver` | Kein Zug und kein Power-up mehr |
| `music` | Hintergrundmusik in Schleife |

## Kleinigkeiten

- Der Runner zeigt im Stand alle paar Sekunden eine Geste: zurückschauen, strecken, hocken, winken, hüpfen,
  aufs Armband-Terminal schauen, Visier-Scan.
- iPhone: Ist die Spielmusik aus, laufen Musik oder Podcasts aus anderen Apps weiter und die Effekte liegen darüber.
- Feuerwand: links hinter den Häusern lodert im Dächerlauf ein Plasma-Feuer (Cyan, Blau, Magenta) mit Rauch,
  bei Absturzgefahr breiter; steht die Figur im Feuer, züngelt es bis zur Bildschirmmitte, beim Absturz mit Ausbruch.
  Spieler: Schalter „FEUER“ in den Einstellungen. Entwickler: `FireWall.enabled = false` entfernt es samt Schalter.
- Startbildschirm (iOS): Key-Art „RAPT“ (`LaunchImage`, 440 × 956 pt mittig, Titel auch auf dem iPhone SE ganz sichtbar, Rest in `LaunchBackground`),
  eingetragen in `App/Info.plist`. Zurück zum schwarzen Start: in `project.yml` die Zeile `INFOPLIST_FILE`
  durch `INFOPLIST_KEY_UILaunchScreen_Generation: YES` ersetzen und `xcodegen generate` ausführen.
- Vorspann nach dem Kaltstart: dasselbe Bild, der Titel glüht einmal auf, nach knapp einer Sekunde Überblendung
  ins Spiel; Antippen überspringt. Derzeit abgeschaltet (`LaunchSplash.enabled = false`), es erscheint nur der
  Startbildschirm; mit `true` wieder einschalten.
- Bildstörungen kurz vor dem Absturz (zweite Hälfte der Gefahrenzone): je etwa 280 ms (220–340) Farbversatz
  (Rot und Blau in zufällige Richtungen), Raster, zwei verschobene Zeilen (oben und unten) und/oder Flackern, mit
  Funkrauschen (`App/Resources/glitch.wav`, Slot `glitch`). Genau zwei Störungen pro Annäherung an
  den Rand, bei 70 % und 93 % der Gefahr (`GlitchFX.marks`; bei Standardtempo etwa 12 s auseinander, die letzte
  rund 4 s vor dem Absturz), die zweite stärker; nach einem rettenden Sprung zählt es neu. Bei „Bewegung reduzieren“ nur Flackern. Abschalten: `GlitchFX.enabled = false`.
  Debug-Regler: GLITCH schaltet Farbversatz (RGB), Raster (RAS), Zeile (ZEI) und Flackern (FLA) einzeln,
  darunter feste Dauer 50–1000 ms; DAUERTEST lässt die Störungen ständig laufen, auch ohne Absturzgefahr.
- Easteregg: das rot blinkende Licht auf dem Fernsehturm 5 Sekunden gedrückt halten (einmal pro Spiel).

## Musik

Elf Tracks aus dem „Action Pack 1“ von Luis Zuno ([@ansimuz](https://ansimuz.itch.io/)), frei auch für kommerzielle
Nutzung (Lizenz: `App/Resources/Music/LICENSE-music-ansimuz.txt`, Credit in den Einstellungen). Als AAC (`music_*.m4a`)
im Bundle, weil Apple-Geräte kein OGG abspielen. Pro Spiel läuft ein zufälliger Track nahtlos in Schleife, nie zweimal
derselbe hintereinander. Eine eigene Datei im Sound-Labor auf dem Platz „Hintergrundmusik“ hat Vorrang.

## Einstellungen

Zahnrad oben rechts auf der Punkteplatte (iPhone und Mac). Eigene Pixel-Ansicht über dem Spiel mit Schaltern und
Schiebereglern: Soundeffekte und Musik (je mit Lautstärke), Funksprüche, Hinweise, Haptik (iPhone), „Neues Spiel“ zur
Moduswahl und **Hilfe**: ein zweites Fenster mit allen Power-ups (Häufigkeit und Wirkung) und Spezialsteinen.
Standard: Effekte, Musik, Funksprüche und Haptik an, Hinweise (blinkender Rahmen nach 7 Sekunden ohne Zug) aus.
Der Schalter **DEBUG-REGLER** ist versteckt: Er erscheint erst, wenn man 5 Sekunden auf die Überschrift
„EINSTELLUNGEN“ drückt, und bleibt bis zum Beenden der App (oder erneut 5 Sekunden drücken). Eingeschaltet blendet er
**Stadt-Tempo** (0,2–4 px/s), **Beschleunigung** (0–50 % pro Spielminute), die Bildstörungs-Regler **GLITCH**
(Effekte einzeln, Dauer, **DAUERTEST**) und **TEST** mit den Knöpfen **INV** und **ABR** (Minispiel sofort starten)
sowie **GRAU** und **1BIT** (Spielbrett 5 Sekunden ohne Farbe: Graustufen oder hart schwarz-weiß; Stadt, Läufer und
Anzeige bleiben farbig; `BoardMonoFilter`) und **AUS** (Stromausfall: alle Fenster flackern hell auf und gehen
flackernd aus, die Häuser bleiben 5 Sekunden dunkel und das Brett grau, der Fernsehturm blinkt weiter; danach springt
der Strom wieder an) ein. Wann Stromausfall oder Graustufen im Spiel kommen, ist noch offen. Beim Ausblenden und bei jedem App-Start gelten die Standardwerte.
Die **Hilfe** hat drei Seiten: Power-ups, Spezialsteine (antippen spielt den Funkspruch des Kontakts) sowie
Dächerlauf, Punkte und Credits.
Während die Einstellungen offen sind, steht die Stadt still.

### Abzüge und Webseiten-Export

- `docs/assets/abzug_grafiken.png`: alle Spielgrafiken (Steine, Spezialsteine, Power-ups, Läufer, Minispiele, App-Icons)
- `docs/assets/abzug_funker.png`: alle Funker-Porträts nach Power-up, mit Name und Stimme
- `docs/assets/web/export/`: aktueller Export für die Webseite (Porträts als JPG, Steine, Symbole, Minispiele, Läufer, App-Icons)
- `docs/assets/originale/portraits/<Teil>/`: alle 44 Funker-Porträts in voller Auflösung (1536 × 1024 PNG), nach dem
  Teil sortiert, das die Figur in der Hand hält. Daraus entstehen die Spiel-Porträts:
  `python3 tools/import_portraits.py docs/assets/originale/portraits` (schreibt `App/Resources/portrait_*.png`
  und `portraits.json`)
- `docs/assets/originale/keyart/startbildschirm.jpg`: Key-Art des Startbildschirms im Original (920 × 2000)
- `docs/assets/web/funk/`: Funksprüche als MP3 (`funk_<teil>_<name>_<1-3>.mp3`, erzeugt mit `tools/render_radio.py`)
