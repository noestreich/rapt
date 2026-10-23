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
| `tools/upload.sh` | Archiviert und lädt nach App Store Connect hoch (`ios`, `mac` oder beide; `--bump` erhöht vorher die Build-Nummer) |
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
  dasselbe hintereinander (Bombe 30, Farbtilger 21, Strudel 16, Atombombe 12, Fresser 9, Invasion 6, Abrissbirne 6, Flak 6, Katana 6, Kurzschluss 6). Jeder sechste Sprung
  bringt garantiert ein seltenes Power-up (Fresser, Atombombe, Invasion, Abrissbirne, Flak, Katana oder Kurzschluss, gleich verteilt), dazu Feuerwerk „HELD DER ARBEIT!“. Ist das Lager voll, gibt es 500 Bonuspunkte.
- Kurz vor dem Absturz leuchtet der ganze Bildschirmrand pulsierend rot, die Figur glüht, ein leises Netzbrummen
  setzt ein, dazu ein dezentes Tick–Tack wie ein Parksensor, das schneller wird (Sound-Labor-Plätze `danger` und
  `dangerTick`); die Musik wird nur ganz leicht zurückgenommen.
- Abstimmung von Tempo und Startposition: `Packages/RaptCore/Sources/RaptCore/City.swift`.
- Nach 7 Sekunden ohne Zug blinkt ein Hinweis.
- **Aufträge** (beide Modi): Jeder Sprung bringt einen kleinen Auftrag, angezeigt unter der Punktzahl („AUFTRAG: RÄUME
  15 KRISTALLE AB 7/15“, „BAUE 2 SPEZIALSTEINE“, „ZÜNDE 3 SPEZIALSTEINE“, „KASKADE STUFE 3“). Plan 1 ist immer eine
  Farbe. Es zählt alles, auch Spezialsteine, Power-ups und Minispiele. Erfüllt: Zeile blinkt „AUFTRAG ERFÜLLT +375“,
  Bonus ein Viertel des aktuellen Sprungs; bis zum nächsten Sprung kommt kein neuer, ein unerfüllter verfällt beim
  Sprung. Fest aus Seed und Plan (`Order.make`), darum im Tageslauf für alle gleich. Code: `RaptCore/Order.swift`.
- **Tageslauf** (dritter Knopf in der Moduswahl): ein Dächerlauf mit festem Seed pro Kalendertag (`DailyRun.seed`,
  FNV-1a über das Datum) – Brett, Stadt und Belohnungen sind an diesem Tag für alle gleich. Eigener Tagesbestwert
  („TAGESBEST“ statt „HOCHPUNKTE“, `rapt.daily.best.<tag>`) und eine **Serie**: jeder Tag, an dem ein Tageslauf
  gestartet wird, zählt; eine Lücke setzt sie auf 1 zurück. Menü und Spielende zeigen Bestwert und Serie.
- **Ergebnis teilen:** Nach Spielende steht links unten im Menü „TEILEN“: eine Pixel-Karte (160 × 100, sechsfach
  vergrößert) mit Logo, Punkten, Modus, Sprung, „NEUER REKORD!“, einer Reihe Steine und der Skyline mit Fernsehturm,
  dazu ein kurzer Text, über das System-Teilen-Menü (iPhone: Teilen-Blatt, Mac: Teilen-Auswahl). Für „Bild sichern“
  steht `NSPhotoLibraryAddUsageDescription` in `project.yml`. Code: `App/Sources/ShareCard.swift`.
- **Weiterspielen:** Nach jedem Zug und beim Wechsel in den Hintergrund (Mac: auch beim Beenden) wird das laufende Spiel
  gesichert (`GameSnapshot` in RaptCore: Brett mit Spezialsteinen, Punkte, Lager, Stadt und Zufallsgeneratoren, als
  JSON in den UserDefaults, `SavedGame`). Gesichert wird nur ein ruhiger Stand – läuft gerade ein Zug, ein Minispiel oder
  der Fresser, bleibt der letzte ruhige Stand (ein dafür verbrauchtes Power-up liegt danach wieder im Lager). Beim
  nächsten Start steht im Moduswahl-Menü oben **WEITERSPIELEN** mit Modus und Punkten (mit vier Knöpfen etwas flacher,
  ohne Rekordzeile); eine neue Wahl verwirft den
  Stand, ebenso das Spielende.

### Minispiele

Fünf Power-ups starten ein kurzes Arcade-Minispiel. Davor knallt ein Manga-Auftakt ins Bild: weißer Blitz,
Schwarz-Weiß-Flackern (normal und invertiert), Konzentrationslinien, Zoom aufs Brett und der Titel mit Farbsaum.
Sprung-Leiste und Lager blenden aus; das Fluggerät steigt hinter den Häusern auf und fliegt frei über dem Nachthimmel unter dem Brett, der Läufer springt vom Dach in die Kabine und am Ende wieder zurück, das leere Gerät sinkt hinter die Häuser. Getroffene Steine zerplatzen sofort mit Konfetti und Glow;
wird ein Spezialstein getroffen (Laser, Abrissbirne, Fresser), löst er sofort aus: Strahl über Zeile oder Spalte,
3 × 3-Explosion oder Blitze in die häufigste Farbe; alles, was er trifft, zählt als Treffer, auch in Ketten. In der
Abrechnung danach gehen diese Spezialsteine nicht noch einmal los (`Game.detonation(at:excluding:)`, `detonated:`).
Nach Ablauf der Zeit fallen neue Steine nach, Kaskaden laufen wie gewohnt.

| Power-up | Vorbild | Ablauf |
|---|---|---|
| **Invasion** (9 s) | Space Invaders | Der Läufer sitzt in einem dunklen Neon-Gleiter (ziehen; gleitet mit Trägheit, Seitendüsen zeigen den Schub) und schießt automatisch aus der Kanone nach oben; jeder Schuss trifft den untersten Stein seiner Spalte. Die Steine marschieren im Takt, der schneller wird, und werfen Zickzack-Geschosse (Treffer lähmen kurz). Zweimal fliegt ein UFO vorbei: Abschuss → Blitze in sechs Steine. |
| **Abrissbirne** (12 s) | Arkanoid, Raptor | Der Läufer steuert einen kastigen, rostigen Glider (ziehen, folgt dem Finger direkt); vom flachen Dach prallt eine glühende Abrissbirne in die Steine, die mit jedem Treffer schneller wird. Bei jedem Aufprall taucht der Glider kurz ab und feuert zwei Leuchtspur-Salven. Manga-Lautmalerei bei Treffer-Serien. Fällt die Birne herunter, liegt kurz danach eine neue auf dem Dach. |
| **Flak** (10 s) | Missile Command | Der Läufer bemannt eine rostige Flakstellung mittig unter dem Brett (offene Luke, Warnlichter). Antippen feuert eine Rakete mit Rauchspur zum Ziel, das Rohr dreht sich zum Finger; die Explosion zerlegt alle Steine im Umkreis von 1,5 Feldern (etwa 3 × 3). Sieben Raketen, als kleine Raketen neben der Stellung angezeigt; „DANEBEN“ bei einem Fehlschuss, „BUMM!“ ab sieben Treffern. |
| **Katana** (8 s) | Fruit Ninja | Der Läufer steht auf einem Schwebebrett mit Neonlichtern, das dem Finger folgt. Wischen übers Brett zerschneidet die Steine (weiße Klingenspur), höchstens sieben pro Hieb, sechs Hiebe; ein bloßes Antippen kostet keinen. Ab drei Schnitten ein Katakana-Ruf („キリ!“, „サッ!“, „カタナ!“). |
| **Kurzschluss** (8 s) | SameGame | Der Läufer fährt einen Tesla-Wagen (Kugel mit Kupferwicklung, knisternde Funken), der dem Finger folgt. Antippen eines Steins schickt einen Blitz aus der Kugel; er springt Stufe für Stufe über alle Nachbarn derselben Farbe, auch schräg (höchstens 18 Steine). Fünf Ladungen; „BZZZT!“ ab acht Steinen, „PFFT“ bei einem einzelnen. |

**Sternenbahn** (12 s, in beiden Modi): Auslöser ist eine Reihe aus mindestens vier Kristallen (auch in Kaskaden) oder
im Dächerlauf jeder 10. Sprung (zusätzlich zum Power-up) – die erste im Spiel sofort, danach höchstens alle 5 Minuten
eine. Im Endlos-Modus gibt es nur Punkte (kein Lager). Per Funk reichen GRETA oder YANKO
(Ordner `Sternenbahn/`) das Raumschiff herüber, es fliegt zu einem Kristall. Alle Steine blenden
aus, ein Kristall gleitet in die untere Brettmitte und wird im Blitz zum grauen Raumschiff (Kristallform in Nietengrau,
Rostflecken, Cockpitfenster, zwei Heckdüsen); der Läufer springt hinein, Manga-Auftakt „STERNENBAHN!“. Von oben schiebt
sich während des Auftakts eine Rennbahn mit rot-schwarzen Banden ins Brett; sie wird schmaler und mit der Zeit und jeder
gesammelten Münze schneller. Ziehen lenkt; goldene Münzen (Donuts in halber Größe) einsammeln: alle zusammen bringen einen halben Sprung des
aktuellen Plans (anteilig nach Münzen, `Game.starRunPoints`), also nie mehr als einen Sprung;
alle 5 Münzen Kombo-Ruf („STARK x5“, „BRAVO x10“ …) und ein Schwert-Laut in Katakana. Banden schubsen nur zurück
(Funken, Serie reißt ab, 20 % der gesammelten Münzen springen davon, mindestens eine), kein Absturz. Am Ende wird das Schiff wieder zum Kristall und gleitet an seinen Platz; ab 80 % der Münzen gibt es ein
seltenes Power-up. In der Hilfe steht sie unter den Minispielen mit Schiff-Symbol und der Andeutung „VIER KRISTALLE IN
EINER REIHE ...“; antippen spielt den Funkspruch von Greta oder Yanko. Code: `App/Sources/StarRun.swift`, `Game.finishStarRun`.

Sprung-Leiste und Minispiele: Zu Beginn eines Minispiels (Invasion, Abrissbirne, Flak, Katana, Kurzschluss, Sternenbahn) bleibt die Leiste auf
ihrem Stand stehen. Danach füllt sie sich sichtbar Segment für Segment (leuchtende Spitze, leise Ticks, „+Punkte“);
über einen geschafften Sprung hinweg läuft sie voll, blitzt auf und beginnt neu (`freezePlanBar`, `revealPlanGain`).

Code: `App/Sources/Arcade.swift` (Invasion, Abrissbirne, Manga-Filter), `App/Sources/MoreArcades.swift` (Flak, Katana, Kurzschluss), Grafik: `App/Sources/Art/ArcadeArt.swift`.

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

**Funker-Album** (Einstellungen → FUNKER-ALBUM): alle Funker, die im Spiel auftauchen können (Porträts aus
`portraits.json`, ohne Zuordnung der zuständige Kontakt), drei pro Reihe, 15 pro Seite. Wer sich noch nicht gemeldet
hat, zeigt nur Rauschen und „KEIN SIGNAL“; beim ersten echten Funkspruch erscheint „NEU IM FUNKER-ALBUM“. Vorführungen
aus Hilfe und Album zählen nicht. Bekannte Funker antippen spielt ihren Funkspruch. Gespeichert in den UserDefaults
(`rapt.album.seen`), Code: `App/Sources/Settings/AlbumPanel.swift`.

| Kontakt | Liefert |
|---|---|
| KIRA | Linien-Stein, Invasion |
| BORIS | Bomben-Stein, Bombe, Abrissbirne |
| JUKI | Farbtilger, Katana |
| MAMA ZORA | Hyperstein, Strudel, Kurzschluss |
| K-9 | Fresser |
| ROBO-7 | Atombombe, Flak |

Die Gruppen der neuen Minispiele: **Flak** (Rakete) Juno, Mika, Vexa; **Katana** (Schwert) Kira, Ronan, Sora;
**Kurzschluss** (Tesla-Spule) Ada, Ivo, Nika. Insgesamt 55 Funker im Album.

- **Porträts:** liegen als `App/Resources/portrait_<id>.png` (`kira`, `boris`, `juki`, `zora`, `k9`, `robo`) im
  Querformat 184 × 121 und füllen die Einblendung in voller Breite. Neue Bilder (beliebige Größe, ca. 3:2) mit
  `python3 tools/import_portraits.py <Ordner>` aufs Pixelraster bringen, danach `xcodegen generate`.
  Fehlt eine Datei, erzeugt das Spiel einen 48 × 48-Platzhalter.
- **Varianten:** `portrait_<kontakt>--<name>--<stimme>.png` (z. B. `portrait_boris--ivan--mann-tief.png`) vertritt den
  Kontakt zufällig, mit eigenem Namen und eigener Stimme. Stimmen: `mann`, `mann-tief`, `frau`, `maedchen`, `junge`,
  `alt`, `hund`, `katze`, `roboter`. Ebenfalls mit `tools/import_portraits.py` einspielen.
- **Wer hält was:** Liegen die Bilder in Ordnern je Teil (`Atombombe/`, `Bombe/`, `Bombenstein/`, `Farbtilger/`,
  `Fresser/`, `Hyperstein/`, `Linienstein/`, `Strudel/`, `Invasion/`, `Abrissbirne/`, `Flak/`, `Katana/`, `Kurzschluss/`,
  `Sternenbahn/`), schreibt das Skript `App/Resources/portraits.json`.
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
| Fresser | Startet sofort: zwei Farben versteinern, 10 Sekunden lang lenkst du den Fressautomaten per Wischen und frisst alle anderen Steine; gefressene Spezialsteine lösen sofort aus (versteinerte Steine bleiben stehen) |

### Tastatur (Mac)

| Taste | Wirkung |
|---|---|
| Pfeile / WASD | Tastatur-Rahmen (Cyan) übers Brett bewegen; im Fresser lenken |
| Leertaste / Eingabe | Stein wählen, mit dem Nachbarn tauschen; mit scharfer Bombe/Atombombe/Farbtilger: zünden |
| Umschalt + Pfeil | Stein unter dem Rahmen sofort in diese Richtung tauschen |
| 1–3 | Power-up aus dem Lager |
| Esc | Auswahl abbrechen, sonst Einstellungen; schließt Einstellungen, Hilfe und Album |
| Menü: 1–4 / Eingabe | Knopf wählen (Eingabe: oberster) |
| Minispiele: ← → | lenken (halten); Leertaste wirft die Abrissbirne ab |

Ein lokaler Tasten-Monitor in `GameView` reicht die Tasten an `GameScene.handleKey` weiter; Kürzel mit ⌘ und
Texteingaben (Sound-Labor) bleiben unberührt. Ein Mausklick blendet den Rahmen aus. Die Hilfe zeigt auf dem Mac einen
Absatz „TASTATUR“.

## Game Center

Bestenlisten und Erfolge (`App/Sources/GameCenter.swift`, zum Abschalten `GameCenter.enabled = false`). Anmeldung beim
Start; ist man angemeldet, steht im Startmenü links unten **BESTENLISTE** (öffnet Game Center). Gemeldet wird beim
Spielende; Erfolge mit Fortschritt (z. B. 4 von 6 Minispielen) gehen laufend hinaus. Entitlement in
`App/Rapt.entitlements`, auf dem Mac zusätzlich ausgehende Verbindungen (`ENABLE_OUTGOING_NETWORK_CONNECTIONS`).

**Einmalig in App Store Connect anlegen** (App → Dienste → Game Center; danach in der Version unter „Game Center“
die Bestenlisten und Erfolge hinzufügen). Solange sie fehlen, passiert im Spiel einfach nichts.

| Bestenliste (klassisch, Ganzzahl, höchster Wert oben) | ID |
|---|---|
| Dächerlauf | `de.ncls.rapt.rooftop` |
| Endlos | `de.ncls.rapt.endless` |
| Tageslauf (**wiederkehrend**, Dauer 1 Tag, Start 00:00) | `de.ncls.rapt.daily` |

Bilder für die Bestenlisten: `docs/assets/gamecenter/leaderboard_rooftop.png`, `leaderboard_endless.png`,
`leaderboard_daily.png` (1024 × 1024, dazu `_512` mit 512 × 512): Läufer im Sprung über die Plattenbauten, Brett mit
Steinen, Abreißkalender mit Kristall.

| Erfolg | ID | Punkte | Beschreibung | Bild |
|---|---|---|---|---|
| Zehn Dächer | `de.ncls.rapt.jump10` | 25 | Erreiche Sprung 10. | `jump10.png` |
| Dachkönig | `de.ncls.rapt.jump25` | 50 | Erreiche Sprung 25. | `jump25.png` |
| Kettenreaktion | `de.ncls.rapt.cascade5` | 25 | Löse eine Kaskade der Stufe 5 aus. | `cascade5.png` |
| Planerfüller | `de.ncls.rapt.orders10` | 25 | Erfülle zehn Aufträge. | `orders10.png` |
| Spielhalle | `de.ncls.rapt.minigames` | 50 | Spiele jedes Minispiel einmal, auch die Sternenbahn. | `minigames.png` |
| Funkverkehr | `de.ncls.rapt.album` | 50 | Triff alle Funker im Funker-Album. | `album.png` |
| Sieben Nächte | `de.ncls.rapt.streak7` | 50 | Spiele den Tageslauf an sieben Tagen in Folge. | `streak7.png` |

Die Bilder (1024 × 1024, Platzhalter im Spielstil) liegen in `docs/assets/gamecenter/`, erzeugt mit
`python3 tools/gamecenter_images.py`. Für jeden Erfolg in App Store Connect eine deutsche Lokalisierung mit Name,
Beschreibung (vor und nach dem Erreichen gleich) und Bild anlegen.

## iPhone Duo, iPad und große Fenster

Die Szene passt sich jeder Fenstergröße an (`scaleMode = .resizeFill`, ganzzahlige Pixel-Skala, `layoutWorld`): Das
Spielfeld (200 × 373 Design-Pixel) steht mittig, links und rechts füllen Stadt, Himmel, Regen und Zug den Platz –
wie beim frei ziehbaren Mac-Fenster. Kein `UIScreen.main`, keine festen Bildschirmgrößen, keine Ausrichtungs-Logik;
die Pixelskala kommt aus `traitCollection.displayScale`. Auf- und Zuklappen der iPhone Duo löst nur einen
Größenwechsel aus (`didChangeSize`, neue Safe-Area).

- **Ausrichtung nach Fenstergröße** (`App/Sources/ScreenFit.swift`, AppDelegate): Fenster mit kürzerer Seite unter
  600 pt (normale iPhones, Außendisplay der Duo) bleiben im Hochformat; große Fenster (Duo aufgeklappt, iPad) drehen
  frei. In `project.yml` sind dafür alle Ausrichtungen eingetragen; `UIRequiresFullScreen` ist entfernt (von Apple als
  veraltet markiert, verhinderte das Mitwachsen des Fensters).
- **Querformat-Layout** (Duo aufgeklappt quer, iPad quer, breites Mac-Fenster; Fenster mindestens 10 % breiter als
  hoch und dadurch größer darstellbar): Brett, Sprung-Leiste und Lager links, die Punkteplatte samt Funk-Einblendung
  rechts daneben, oben bündig mit dem Brett (`topBar`, `hudShift` = 196 × 86 Design-Pixel). Der Block (400 × 286) wird
  so groß wie möglich gesetzt – auf der Duo quer wird das Brett rund 411 pt groß statt 293 pt –, die Stadt läuft unten
  über die ganze Breite, und die Bildschirmmitte (Knick der Duo) fällt genau in die Lücke zwischen Brett und Platte.
  Einstellungen, Hilfe und Album werden dort in ganzen Pixelstufen verkleinert und mittig gezeigt (`panelHost`).
  Hochformat und iPhone bleiben unverändert.
- **Kulissenhäuser:** Links vor der ersten Häuserreihe der Stadt stehen bis zum Bildrand weitere Plattenbauten (nur Bild,
  keine Spiellogik, `fillerBuildings`), damit zwischen Feuer und Häusern auf breiten Displays keine Lücke bleibt.
- **Manga-Auftakt:** Blitz und Konzentrationslinien wachsen mit dem Fenster, damit sie auch breite Displays füllen.
- **Bauen:** Mit dem iOS-27-SDK füllt die App das Innendisplay der Duo größtenteils (Statusleiste rechts bleibt frei),
  erst mit Xcode 27.1 (iOS-27.1-SDK) das ganze Display. Ältere SDKs zeigen die App als iPhone-Fenster mit Rand.
  Testen im iPhone-Duo-Simulator von Xcode 27.1.

## Veröffentlichen über GitHub Actions

Workflow **Veröffentlichen** (`.github/workflows/release.yml`), nur per Hand: Actions → Veröffentlichen → Run workflow.
Er läuft auf dem Runner `xcode-27` mit Xcode 27.1 (iOS-27.1-SDK, volles Duo-Innendisplay), erzeugt das Projekt mit
XcodeGen, archiviert für `generic/platform=iOS` (Release, automatische Signierung über den API-Schlüssel, Team aus
`project.yml`) und lädt mit `destination upload` direkt zu App Store Connect hoch; danach TestFlight, eingereicht wird
von Hand. Im Erfolgsfall stehen Version, Build und SDK in der Job-Zusammenfassung, bei Fehlern die Zeilen zu
Signieren, Profilen und Zertifikaten.

- **Secrets:** `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8` (ganze .p8-Datei). Der Schlüssel landet nur für den Lauf in
  `$RUNNER_TEMP/AuthKey_<KEY_ID>.p8` (chmod 600) und wird am Ende immer gelöscht. Rolle **Admin** nötig (Cloud-Signierung).
- **Buildnummer:** kommt aus `project.yml` und muss höher sein als jede bisher hochgeladene – vor jedem Lauf erhöhen
  und committen. Jeder Lauf legt ein Entwicklungszertifikat „Created via API“ an (harmlos).
- **Start erst nach dem Mergen:** GitHub bietet „Run workflow“ nur für Workflows auf dem Standard-Branch an.
- Der Mac-Build geht weiter über `tools/upload.sh mac`.

## Sprachen

Deutsch und Englisch. Alle Spieltexte stehen direkt im Code als `tr("DEUTSCH", "ENGLISH")`
(`App/Sources/Settings/GameSettings.swift`); die Sprache folgt beim ersten Start der Systemsprache (Deutsch, sonst
Englisch) und lässt sich in den Einstellungen unter **SPRACHE** (DE/EN) sofort umschalten – Einstellungen, Hilfe,
Album, Menü und Anzeigen bauen sich neu auf. Englische Namen: Dächerlauf → ROOFTOP RUN, Endlos → ENDLESS,
Tageslauf → DAILY RUN, Abrissbirne → WRECKER, Kurzschluss → OVERLOAD, Sternenbahn → STAR RUN, Fresser → CHOMPER,
Farbtilger → COLOR PURGE, Strudel → WHIRL, Funker-Album → RADIO ALBUM. Die Pixel-Schrift kennt nur Großbuchstaben,
Ziffern, Umlaute und `! % + - . / :` (kein Komma, kein Fragezeichen); englische Texte sind höchstens so breit wie
die verfügbare Fläche. `CFBundleLocalizations` (de, en) steht in `App/Info.plist`, die Fotos-Berechtigung ist in
`App/Resources/*.lproj/InfoPlist.strings` übersetzt. Debug-Zeilen und Sound-Labor bleiben deutsch.
In App Store Connect zusätzlich Englisch als Sprache anlegen (Beschreibung, Screenshots) und den Game-Center-Einträgen
eine englische Lokalisierung geben (z. B. Rooftop Run, Endless, Daily Run; Ten Roofs, Roof King, Chain Reaction,
Plan Fulfiller, Arcade Hall, Radio Traffic, Seven Nights).

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
- Stadt-Ereignisse (beide Modi, nur während des Spiels, etwa alle 70–150 Sekunden eins): **Nachtzug** – eine S-Bahn
  aus drei oder vier Wagen mit erleuchteten Fenstern, Scheinwerfer und Funken am Stromabnehmer fährt auf einer
  Hochbahn hinter der vorderen Häuserreihe durch (sichtbar in Lücken und über niedrigen Dächern), leises Schienenklacken;
  **Regen** (30 %) – 20–35 Sekunden schräge Striche vor den Häusern, hinter Anzeige und Brett, ein- und ausgeblendet,
  ein- bis zweimal Wetterleuchten mit fernem Donner. Debug: TEST → **ZUG**, **NASS**. Code: `App/Sources/CityEvents.swift`.
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
- Stromausfall nach der Atombombe (mit 33 % Wahrscheinlichkeit): alle Fenster der Häuser flackern hell auf und gehen
  flackernd aus, die Stadt bleibt 5 Sekunden dunkel und das Spielbrett grau (`BoardMonoFilter`), der Fernsehturm blinkt
  mit Notstrom rot weiter; danach springt der Strom flackernd wieder an. Abschalten: `PowerCut.enabled = false`.
- Läufer außer Sicht: Springt er auf ein Dach rechts außerhalb des Bildes, landet er stattdessen mit einem hohen
  Sprung auf der Oberkante des Spielfeldrahmens (beim ersten Mal „HOCH HINAUS!“). Je weiter sein Dach entfernt ist,
  desto weiter links steht er; die Stadt drängt ihn langsam nach rechts (Windlinien, er lehnt sich dagegen), und sobald sein Dach im
  Bild ist, springt er hinunter („ハッ!“). Rein optisch, die Spiellogik rechnet mit dem echten Haus (`standPoint`).
- Easteregg: das rot blinkende Licht auf dem Fernsehturm 5 Sekunden gedrückt halten (einmal pro Spiel).

## Musik

Elf Tracks aus dem „Action Pack 1“ von Luis Zuno ([@ansimuz](https://ansimuz.itch.io/)), frei auch für kommerzielle
Nutzung (Lizenz: `App/Resources/Music/LICENSE-music-ansimuz.txt`, Credit in den Einstellungen). Als AAC (`music_*.m4a`)
im Bundle, weil Apple-Geräte kein OGG abspielen. Pro Spiel läuft ein zufälliger Track nahtlos in Schleife, nie zweimal
derselbe hintereinander. Eine eigene Datei im Sound-Labor auf dem Platz „Hintergrundmusik“ hat Vorrang.

## Einstellungen

Zahnrad oben rechts auf der Punkteplatte (iPhone und Mac). Eigene Pixel-Ansicht über dem Spiel mit Schaltern und
Schiebereglern: Soundeffekte und Musik (je mit Lautstärke), Funksprüche, Hinweise, Haptik (iPhone), „Neues Spiel“ zur
Moduswahl, **Funker-Album** und **Hilfe**: ein zweites Fenster mit allen Power-ups (Häufigkeit und Wirkung) und Spezialsteinen.
Standard: Effekte, Musik, Funksprüche und Haptik an, Hinweise (blinkender Rahmen nach 7 Sekunden ohne Zug) aus.
Der Schalter **DEBUG-REGLER** ist versteckt: Er erscheint erst, wenn man 5 Sekunden auf die Überschrift
„EINSTELLUNGEN“ drückt, und bleibt bis zum Beenden der App (oder erneut 5 Sekunden drücken). Eingeschaltet blendet er
**Stadt-Tempo** (0,2–4 px/s), **Beschleunigung** (0–50 % pro Spielminute), **SPIEL** mit den Knöpfen **INV**, **ABR**,
**FLAK**, **KAT**, **KURZ** (Minispiel sofort starten) und **BAHN** (Sternenbahn sofort) sowie **TEST** mit **GRAU** (Spielbrett 5 Sekunden grau), **AUS** (Stromausfall sofort), **ZUG** (Nachtzug), **NASS** (Regen) und **+3** (drei Sprünge auf einmal) ein. Beim Ausblenden und bei jedem App-Start gelten die Standardwerte.
Die **Hilfe** hat vier Seiten: Power-ups, Minispiele (mit Sternenbahn), Spezialsteine (antippen spielt den Funkspruch
des Kontakts) mit den sieben normalen Steinen darunter (Bild und Name wie in den Aufträgen: ORDEN, ZAHNRÄDER, SIGNALE,
URANGLÄSER, KRISTALLE, RÖHREN, NIETEN) sowie Dächerlauf, Punkte und Credits.
Während die Einstellungen offen sind, steht die Stadt still.

### Vorlagen für neue Funker-Porträts

`docs/assets/props/` zeigt, was die Figur auf den Porträts der neuen Minispiele in der Hand hält (Pixel-Art 32 × 32,
16-fach, transparent; `uebersicht.png` alle drei auf Nachthimmel): **Flak** – Flugabwehrrakete mit roter Spitze,
Warnring, Leitwerk und Feuerstrahl; **Katana** – Schwert mit goldenem Stichblatt und rot gewickeltem Griff;
**Kurzschluss** – Tesla-Spule mit Kupferwicklung, leuchtender Kugel und Blitzen. Erzeugt mit
`python3 tools/prop_sketches.py`. Fertige Porträts kommen in die Ordner `Flak/`, `Katana/`, `Kurzschluss/` und werden mit
`tools/import_portraits.py` importiert.

### Abzüge und Webseiten-Export

- `docs/assets/abzug_grafiken.png`: alle Spielgrafiken (Steine, Spezialsteine, Power-ups, Läufer, Minispiele, App-Icons)
- `docs/assets/abzug_funker.png`: alle Funker-Porträts nach Power-up, mit Name und Stimme
  (neu bauen: `python3 tools/make_funker_sheet.py`)
- `docs/assets/web/export/`: aktueller Export für die Webseite (Porträts als JPG, Steine, Symbole, Minispiele, Läufer, App-Icons)
- `docs/assets/originale/portraits/<Teil>/`: alle 55 Funker-Porträts in voller Auflösung (1536 × 1024 PNG), nach dem
  Teil sortiert, das die Figur in der Hand hält. Daraus entstehen die Spiel-Porträts:
  `python3 tools/import_portraits.py docs/assets/originale/portraits` (schreibt `App/Resources/portrait_*.png`
  und `portraits.json`)
- `docs/assets/originale/powerups/`: Flak (Rakete), Katana (Schwert) und Kurzschluss (Tesla-Spule) als
  hochaufgelöste Gegenstände (1254 × 1254, transparent), Vorlage zu den Porträts; im Spiel bleiben die Pixel-Symbole
- `docs/assets/originale/keyart/startbildschirm.jpg`: Key-Art des Startbildschirms im Original (920 × 2000)
- `docs/assets/originale/sternenbahn/raumschiff.png`: Raumschiff der Sternenbahn als Vorlage (nicht im Spiel verwendet)
- `docs/assets/web/funk/`: Funksprüche als MP3 (`funk_<teil>_<name>_<1-3>.mp3`, erzeugt mit `tools/render_radio.py`)
