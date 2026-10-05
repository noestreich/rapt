/// Belohnungen für erfüllte Pläne. Die Figur auf den Dächern bestimmt, welches es gibt.
public enum PowerUp: String, CaseIterable, Sendable {
    /// Sprengt ein 3×3-Feld.
    case bombe
    /// Entfernt alle Steine einer Farbe.
    case farbtilger
    /// Zwei Farben versteinern, zehn Sekunden lang frisst ein Automat alle anderen Steine.
    case fresser
}

/// Ergebnis eines erfüllten Plans.
public struct PlanReward: Equatable, Sendable {
    /// Der neu erreichte Plan.
    public let plan: Int
    /// Dach, auf das die Figur springt (1 ... roofCount - 1).
    public let roof: Int
    /// `nil`, wenn das Lager voll war; dann gibt es stattdessen `bonusPoints`.
    public let powerUp: PowerUp?
    public let bonusPoints: Int
    /// Die Figur hat das letzte Dach erreicht und beginnt danach wieder vorne.
    public let reachedTop: Bool
}

/// Eine Runde Fresser: welche Farben versteinert sind und wo der Automat startet.
public struct FresserRound: Equatable, Sendable {
    public static let duration = 10.0
    public let stones: Set<Gem>
    public let start: Pos
}
