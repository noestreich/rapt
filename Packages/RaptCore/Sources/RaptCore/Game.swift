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

/// Eine Stufe der Auflösung: Reihen verschwinden, Steine fallen, neue rutschen nach.
public struct CascadeStep: Equatable, Sendable {
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
    public let isGameOver: Bool

    public static let invalid = SwapResult(isValid: false, steps: [], isGameOver: false)

    public var points: Int { steps.reduce(0) { $0 + $1.points } }
}

/// Endlos-Modus: Spielen, bis kein Zug mehr möglich ist.
public struct Game: Sendable {
    public static let pointsPerGem = 50
    public static let bonusPerExtraGem = 100
    public static let pointsPerPlanStep = 1500

    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var isOver = false
    private var rng: SplitMix64

    public init(seed: UInt64, cols: Int = 8, rows: Int = 8) {
        rng = SplitMix64(seed: seed)
        board = Board.random(cols: cols, rows: rows, using: &rng)
    }

    public init(board: Board, seed: UInt64) {
        self.board = board
        rng = SplitMix64(seed: seed)
        isOver = !board.hasValidMove
    }

    /// Tauscht zwei Nachbarn. Ergibt der Tausch keine Reihe, bleibt das Brett unverändert.
    public mutating func swap(_ a: Pos, _ b: Pos) -> SwapResult {
        guard !isOver, board.isValidMove(a, b) else { return .invalid }
        board.swapAt(a, b)
        var steps: [CascadeStep] = []
        var combo = 0
        while true {
            let runs = board.runs()
            if runs.isEmpty { break }
            combo += 1
            let cleared = Set(runs.flatMap(\.cells))
            let points = Self.points(for: runs, combo: combo)
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
        isOver = !board.hasValidMove
        return SwapResult(isValid: true, steps: steps, isGameOver: isOver)
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

    // MARK: Plan (Stufen im Endlos-Modus)

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
}
