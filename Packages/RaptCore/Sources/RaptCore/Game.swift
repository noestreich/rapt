/// Ein Stein, der nach unten rutscht. Bei neuen Steinen liegt `from.row` oberhalb des Bretts (negativ).
public struct Fall: Equatable, Sendable {
    public let gem: Gem
    public let from: Pos
    public let to: Pos

    public init(gem: Gem, from: Pos, to: Pos) {
        self.gem = gem
        self.from = from
        self.to = to
    }
}

/// Eine Stufe der Auflösung: Steine verschwinden, andere fallen, neue rutschen nach.
public struct CascadeStep: Equatable, Sendable {
    /// Leer, wenn die Steine durch ein Power-up verschwinden statt durch eine Reihe.
    public let runs: [Run]
    public let cleared: [Pos]
    public let falls: [Fall]
    public let spawns: [Fall]
    /// 1 für den direkten Treffer, 2 für die erste Kettenreaktion usw.
    public let combo: Int
    public let points: Int
}

public struct SwapResult: Equatable, Sendable {
    public let isValid: Bool
    public let steps: [CascadeStep]
    public let rewards: [PlanReward]
    public let isGameOver: Bool

    public static let invalid = SwapResult(isValid: false, steps: [], rewards: [], isGameOver: false)

    public var points: Int { steps.reduce(0) { $0 + $1.points } }
}

/// Endlos-Modus: Spielen, bis weder ein Zug noch ein Power-up übrig ist.
public struct Game: Sendable {
    public static let pointsPerGem = 50
    public static let bonusPerExtraGem = 100
    public static let pointsPerPlanStep = 1500
    /// Anzahl der Dächer. Die Figur startet auf Dach 0; das letzte Dach bringt den Fresser.
    public static let roofCount = 5
    public static let maxPowerUps = 3
    public static let fullStorageBonus = 500

    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var isOver = false
    public private(set) var powerUps: [PowerUp] = []
    /// Dach, auf dem die Figur gerade steht.
    public private(set) var roof = 0
    private var rewardedPlan = 1
    private var rng: SplitMix64

    public init(seed: UInt64, cols: Int = 8, rows: Int = 8) {
        rng = SplitMix64(seed: seed)
        board = Board.random(cols: cols, rows: rows, using: &rng)
    }

    public init(board: Board, seed: UInt64) {
        self.board = board
        rng = SplitMix64(seed: seed)
        updateOver()
    }

    public var hasValidMove: Bool { board.hasValidMove }

    // MARK: Züge

    /// Tauscht zwei Nachbarn. Ergibt der Tausch keine Reihe, bleibt das Brett unverändert.
    public mutating func swap(_ a: Pos, _ b: Pos) -> SwapResult {
        guard !isOver, board.isValidMove(a, b) else { return .invalid }
        board.swapAt(a, b)
        return finish(resolve(initial: nil))
    }

    // MARK: Power-ups

    /// Sprengt das 3×3-Feld um `center`.
    public mutating func useBomb(at center: Pos) -> SwapResult {
        guard board.contains(center), powerUps.contains(.bombe) else { return .invalid }
        var cells = Set<Pos>()
        for dc in -1...1 {
            for dr in -1...1 {
                let p = Pos(center.col + dc, center.row + dr)
                if board.contains(p) { cells.insert(p) }
            }
        }
        take(.bombe)
        return finish(resolve(initial: cells))
    }

    /// Entfernt alle Steine der Farbe `color`.
    public mutating func usePurge(_ color: Gem) -> SwapResult {
        guard powerUps.contains(.farbtilger) else { return .invalid }
        let cells = Set(board.positions.filter { board[$0] == color })
        guard !cells.isEmpty else { return .invalid }
        take(.farbtilger)
        return finish(resolve(initial: cells))
    }

    /// Startet eine Fresser-Runde: zwei zufällige Farben versteinern, der Automat startet auf einem freien Feld.
    public mutating func startFresser() -> FresserRound? {
        guard powerUps.contains(.fresser) else { return nil }
        var kinds = Gem.allCases.filter { kind in board.positions.contains { board[$0] == kind } }
        guard kinds.count >= 3 else { return nil }
        kinds.shuffle(using: &rng)
        let stones = Set(kinds.prefix(2))
        let free = board.positions.filter { p in board[p].map { !stones.contains($0) } ?? false }
        guard let start = free.randomElement(using: &rng) else { return nil }
        take(.fresser)
        return FresserRound(stones: stones, start: start)
    }

    /// Beendet die Fresser-Runde. Versteinerte Steine in `eaten` werden ignoriert.
    public mutating func finishFresser(_ round: FresserRound, eaten: Set<Pos>) -> SwapResult {
        let cells = eaten.filter { p in board.contains(p) && board[p].map { !round.stones.contains($0) } ?? false }
        guard !cells.isEmpty else {
            updateOver()
            return SwapResult(isValid: true, steps: [], rewards: [], isGameOver: isOver)
        }
        return finish(resolve(initial: cells))
    }

    private mutating func take(_ kind: PowerUp) {
        if let i = powerUps.firstIndex(of: kind) { powerUps.remove(at: i) }
    }

    // MARK: Auflösung

    /// Löst Reihen und Kettenreaktionen auf. `initial` sind Felder, die vorab verschwinden (Power-ups).
    private mutating func resolve(initial: Set<Pos>?) -> [CascadeStep] {
        var steps: [CascadeStep] = []
        var combo = 0
        var forced = initial
        while true {
            let runs: [Run]
            let cleared: Set<Pos>
            let points: Int
            if let cells = forced {
                forced = nil
                combo += 1
                runs = []
                cleared = cells
                points = cells.count * Self.pointsPerGem
            } else {
                let found = board.runs()
                if found.isEmpty { break }
                combo += 1
                runs = found
                cleared = Set(found.flatMap(\.cells))
                points = Self.points(for: found, combo: combo)
            }
            for p in cleared { board[p] = nil }
            let (falls, spawns) = collapse()
            score += points
            steps.append(CascadeStep(
                runs: runs,
                cleared: cleared.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                falls: falls,
                spawns: spawns,
                combo: combo,
                points: points
            ))
        }
        return steps
    }

    private mutating func finish(_ steps: [CascadeStep]) -> SwapResult {
        let rewards = collectRewards()
        updateOver()
        return SwapResult(isValid: true, steps: steps, rewards: rewards, isGameOver: isOver)
    }

    private mutating func updateOver() {
        isOver = !board.hasValidMove && powerUps.isEmpty
    }

    public static func points(for runs: [Run], combo: Int) -> Int {
        runs.reduce(0) { sum, run in
            sum + (run.length * pointsPerGem + max(0, run.length - 3) * bonusPerExtraGem) * combo
        }
    }

    /// Lässt Steine in Lücken fallen und füllt von oben auf.
    private mutating func collapse() -> (falls: [Fall], spawns: [Fall]) {
        var falls: [Fall] = []
        var spawns: [Fall] = []
        for col in 0..<board.cols {
            var write = board.rows - 1
            for row in stride(from: board.rows - 1, through: 0, by: -1) {
                guard let g = board[col: col, row: row] else { continue }
                if row != write {
                    board[col: col, row: write] = g
                    board[col: col, row: row] = nil
                    falls.append(Fall(gem: g, from: Pos(col, row), to: Pos(col, write)))
                }
                write -= 1
            }
            let missing = write + 1
            for row in 0..<missing {
                let g = Gem.random(using: &rng)
                board[col: col, row: row] = g
                spawns.append(Fall(gem: g, from: Pos(col, row - missing), to: Pos(col, row)))
            }
        }
        return (falls, spawns)
    }

    public func hint() -> Move? {
        board.validMoves().first
    }

    // MARK: Plan und Belohnungen

    /// Punkte, die nötig sind, um Plan `n` zu erreichen. Plan 1 beginnt bei 0.
    static func planThreshold(_ n: Int) -> Int {
        pointsPerPlanStep * n * (n - 1) / 2
    }

    public var plan: Int {
        var n = 1
        while score >= Self.planThreshold(n + 1) { n += 1 }
        return n
    }

    /// Fortschritt innerhalb des aktuellen Plans, 0...1.
    public var planProgress: Double {
        let n = plan
        let lo = Self.planThreshold(n)
        let hi = Self.planThreshold(n + 1)
        return Double(score - lo) / Double(hi - lo)
    }

    /// Jeder neue Plan: Figur springt ein Dach weiter und bringt ein Power-up.
    /// Dächer 1 und 3 bringen eine Bombe, Dach 2 den Farbtilger, das letzte Dach den Fresser.
    private mutating func collectRewards() -> [PlanReward] {
        var rewards: [PlanReward] = []
        while plan > rewardedPlan {
            rewardedPlan += 1
            roof += 1
            let top = roof >= Self.roofCount - 1
            let kind: PowerUp = top ? .fresser : (roof % 2 == 0 ? .farbtilger : .bombe)
            var granted: PowerUp?
            var bonus = 0
            if powerUps.count < Self.maxPowerUps {
                powerUps.append(kind)
                granted = kind
            } else {
                bonus = Self.fullStorageBonus
                score += bonus
            }
            rewards.append(PlanReward(plan: rewardedPlan, roof: roof, powerUp: granted, bonusPoints: bonus, reachedTop: top))
            if top { roof = 0 }
        }
        return rewards
    }

    /// Für Tests: Punkte gutschreiben und Belohnungen auswerten.
    mutating func award(points: Int) -> [PlanReward] {
        score += points
        let rewards = collectRewards()
        updateOver()
        return rewards
    }
}
