/// Kleiner Auftrag je Sprung (in beiden Modi). Erfüllt bringt er sofort Bonuspunkte: ein Viertel des Sprungs.
/// Wird er bis zum nächsten Sprung nicht erfüllt, verfällt er und ein neuer kommt.
public struct Order: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Steine dieser Farbe abräumen (auch über Spezialsteine und Power-ups).
        case clear(Gem)
        /// Spezialsteine bauen.
        case build
        /// Spezialsteine zünden.
        case ignite
        /// Eine Kaskade dieser Stufe erreichen (`target` ist die Stufe).
        case cascade
    }

    public let kind: Kind
    public let target: Int
    public internal(set) var progress = 0
    /// Für diesen Plan vergeben.
    public let plan: Int

    public var isDone: Bool { progress >= target }

    public init(kind: Kind, target: Int, plan: Int, progress: Int = 0) {
        self.kind = kind
        self.target = target
        self.plan = plan
        self.progress = progress
    }

    /// Bonus beim Erfüllen.
    public var bonus: Int { Game.pointsPerPlanStep * plan / 4 }

    /// Auftrag für einen Plan, fest aus `seed` und Plan (ohne Zufallszustand, darum leicht zu speichern).
    public static func make(plan: Int, seed: UInt64) -> Order {
        var rng = SplitMix64(seed: seed ^ (UInt64(truncatingIfNeeded: plan) &* 0x9E37_79B9_7F4A_7C15))
        let roll = rng.next()
        let n = max(1, plan)
        // Erster Plan: immer Steine einer Farbe, damit der Einstieg leicht ist
        let pick = n == 1 ? 0 : Int(roll % 5)
        switch pick {
        case 1:
            return Order(kind: .build, target: 2 + min(2, n / 5), plan: n)
        case 2:
            return Order(kind: .ignite, target: 2 + min(2, n / 5), plan: n)
        case 3:
            return Order(kind: .cascade, target: n >= 8 ? 4 : 3, plan: n)
        default:
            let gem = Gem.allCases[Int((roll >> 16) % UInt64(Gem.allCases.count))]
            return Order(kind: .clear(gem), target: 12 + 3 * min(n, 8), plan: n)
        }
    }

    /// Fortschritt aus einem Kaskadenschritt: abgeräumte Farben, gebaute und gezündete Spezialsteine, Stufe.
    mutating func record(cleared colors: [Gem: Int], created: Int, detonated: Int, combo: Int) {
        guard !isDone else { return }
        switch kind {
        case .clear(let gem): progress += colors[gem] ?? 0
        case .build: progress += created
        case .ignite: progress += detonated
        case .cascade: progress = max(progress, combo)
        }
        progress = min(progress, target)
    }
}
