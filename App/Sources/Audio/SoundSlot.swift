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
    case gameOver
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
        case .gameOver: return "Keine Züge mehr"
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
        case .gameOver: return "Kein Zug mehr möglich, Spielende."
        case .music: return "Läuft in Schleife, solange Musik eingeschaltet ist."
        }
    }

    var isMusic: Bool { self == .music }

    static let audioExtensions = ["wav", "mp3", "m4a", "aif", "aiff", "caf"]
}
