/// Belohnungen für erfüllte Pläne. Die Figur auf den Dächern bestimmt, welches es gibt.
public enum PowerUp: String, CaseIterable, Sendable {
    /// Sprengt ein 3×3-Feld.
    case bombe
    /// Entfernt alle Steine einer Farbe.
    case farbtilger
    /// Mischt das Brett neu, sodass wieder Züge möglich sind.
    case strudel
    /// Sprengt ein 5×5-Feld.
    case atom
    /// Zwei Farben versteinern, zehn Sekunden lang frisst ein Automat alle anderen Steine.
    case fresser
}

/// Ergebnis des Strudels.
public struct ShuffleResult: Equatable, Sendable {
    public let isValid: Bool
    /// Alte Position → neue Position jedes Steins.
    public let moves: [Pos: Pos]
    /// Mischen hat nichts gebracht; das Brett wurde komplett neu gefüllt.
    public let replacedBoard: Bool
    public let isGameOver: Bool

    public static let invalid = ShuffleResult(isValid: false, moves: [:], replacedBoard: false, isGameOver: false)
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
