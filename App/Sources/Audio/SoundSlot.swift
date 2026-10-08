/// Alle Stellen im Spiel, an denen ein Geräusch erklingt. Die `rawValue` ist zugleich der Dateiname
/// (z. B. `explosion.wav`) im Sound-Labor-Export und im App-Bundle.
enum SoundSlot: String, CaseIterable, Identifiable, Codable {
    case select
    case swap
    case invalid
    case match
    case cascade
    case land
    case shrapnel
    case steam
    case explosion
    case warp
    case plan
    case jump
    case powerUp
    case bomb
    case purge
    case chomp
    case slam
    case laser
    case march
    case ufo
    case paddle
    case brick
    case danger
    case dangerTick
    case glitch
    case gameOver
    case voiceKira
    case voiceBoris
    case voiceJuki
    case voiceZora
    case voiceK9
    case voiceRobo
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "Auswahl"
        case .swap: return "Tausch"
        case .invalid: return "Ungültiger Zug"
        case .match: return "Treffer"
        case .cascade: return "Kaskade"
        case .land: return "Aufsetzen"
        case .shrapnel: return "Schrapnell"
        case .steam: return "Dampf"
        case .explosion: return "Explosion"
        case .warp: return "Warp"
        case .plan: return "Plan erfüllt"
        case .jump: return "Sprung"
        case .powerUp: return "Power-up erhalten"
        case .bomb: return "Bombe"
        case .purge: return "Farbtilger"
        case .chomp: return "Fresser frisst"
        case .slam: return "Minispiel-Auftakt"
        case .laser: return "Invasion: Schuss"
        case .march: return "Invasion: Marsch"
        case .ufo: return "Invasion: UFO"
        case .paddle: return "Abrissbirne: Schiff"
        case .brick: return "Abrissbirne: Treffer"
        case .danger: return "Absturz-Alarm"
        case .dangerTick: return "Absturz-Ticken"
        case .glitch: return "Bildstörung"
        case .gameOver: return "Keine Züge mehr"
        case .voiceKira: return "Funk: KIRA"
        case .voiceBoris: return "Funk: BORIS"
        case .voiceJuki: return "Funk: JUKI"
        case .voiceZora: return "Funk: MAMA ZORA"
        case .voiceK9: return "Funk: K-9"
        case .voiceRobo: return "Funk: ROBO-7"
        case .music: return "Hintergrundmusik"
        }
    }

    /// Wann das Geräusch ausgelöst wird.
    var trigger: String {
        switch self {
        case .select: return "Ein Stein wird angetippt und markiert."
        case .swap: return "Zwei Steine tauschen die Plätze."
        case .invalid: return "Tausch ohne Treffer, die Steine springen zurück."
        case .match: return "Jede Reihe, die verschwindet. Wird pro Kaskadenstufe höher abgespielt."
        case .cascade: return "Ab der zweiten Stufe einer Kettenreaktion, zusätzlich zum Treffer."
        case .land: return "Nachrutschende Steine setzen auf."
        case .shrapnel: return "Splitter fliegen bei jedem Treffer."
        case .steam: return "Dampfwolke bei Kaskaden."
        case .explosion: return "Reihe ab vier Steinen, mit Strahl und Schockwelle."
        case .warp: return "Schockwelle bei Viererreihen und Kaskaden ab Stufe 3."
        case .plan: return "Ein Plan (Stufe) ist erfüllt."
        case .jump: return "Die Figur springt aufs nächste Hochhausdach."
        case .powerUp: return "Ein Power-up landet im Lager."
        case .bomb: return "Die Bombe zündet (zusätzlich zur Explosion)."
        case .purge: return "Der Farbtilger schlägt in alle Steine einer Farbe ein."
        case .chomp: return "Der Fresser frisst einen Stein. Wird mit jedem Bissen etwas höher."
        case .slam: return "Manga-Blitz und Titel zu Beginn von Invasion und Abrissbirne."
        case .laser: return "Der Läufer schießt bei der Invasion nach oben."
        case .march: return "Marschtakt der Steine bei der Invasion; vier Töne, wird schneller."
        case .ufo: return "Das UFO fliegt über das Brett (wird wiederholt)."
        case .paddle: return "Die Abrissbirne prallt vom Raumschiff ab."
        case .brick: return "Die Abrissbirne zerschlägt einen Stein. Wird mit jedem Treffer etwas höher."
        case .danger: return "Läuft in Schleife, solange die Figur am linken Rand steht; wird lauter, je näher der Absturz."
        case .dangerTick: return "Leises Tick–Tack bei Absturzgefahr, wird schneller, je näher die Figur am Rand ist."
        case .glitch: return "Funkrauschen bei jeder Bildstörung kurz vor dem Absturz (glitch.wav im App-Bundle)."
        case .gameOver: return "Kein Zug und kein Power-up mehr, Spielende."
        case .voiceKira: return "KIRA übergibt einen Linien-Stein. Eigene Aufnahmen bekommen automatisch Funkklang."
        case .voiceBoris: return "BORIS übergibt einen Bomben-Stein oder eine Bombe."
        case .voiceJuki: return "JUKI übergibt den Farbtilger."
        case .voiceZora: return "MAMA ZORA übergibt einen Hyperstein oder den Strudel."
        case .voiceK9: return "K-9 übergibt den Fresser."
        case .voiceRobo: return "ROBO-7 übergibt die Atombombe."
        case .music: return "Läuft in Schleife, solange Musik eingeschaltet ist."
        }
    }

    var isMusic: Bool { self == .music }

    /// Stimmen bekommen Funkklang und haben keinen eingebauten Ersatzton (der Plapper-Synthesizer springt ein).
    var isVoice: Bool { rawValue.hasPrefix("voice") }

    static let audioExtensions = ["wav", "mp3", "m4a", "aif", "aiff", "caf"]
}
