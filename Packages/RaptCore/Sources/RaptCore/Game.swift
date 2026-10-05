/// Ein Stein, der nach unten rutscht. Bei neuen Steinen liegt `from.row` oberhalb des Bretts (negativ).
public struct Fall: Equatable, Sendable {
    public let gem: Gem
    public let from: Pos
    public let to: Pos
    public let special: Special?

    public init(gem: Gem, from: Pos, to: Pos, special: Special? = nil) {
        self.gem = gem
        self.from = from
        self.to = to
        self.special = special
    }
}

/// Ein Spezialstein, der in dieser Stufe neu entsteht. Das Feld wird dabei nicht abgeräumt.
public struct Creation: Equatable, Sendable {
    public let pos: Pos
    public let gem: Gem
    public let special: Special
}

/// Ein Spezialstein, der in dieser Stufe auslöst, mit den Feldern, die er trifft.
public struct Detonation: Equatable, Sendable {
    public let pos: Pos
    public let special: Special
    /// Steinfarbe; beim Hyperstein die Farbe, die er löscht.
    public let gem: Gem
    public let cells: [Pos]
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
    public let created: [Creation]
    public let detonations: [Detonation]
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
    public static let pointsPerDetonation = 200
    /// Gewichte für zufällige Belohnungen. Seltene Power-ups sind wertvoller.
    public static let rewardWeights: [PowerUp: Double] = [.bombe: 32, .farbtilger: 22, .strudel: 18, .atom: 16, .fresser: 12]
    /// Jeder `roofCount - 1`. Sprung schließt einen Zyklus ab und bringt garantiert Fresser oder Atombombe.
    public static let roofCount = 7
    public static let maxPowerUps = 3
    public static let fullStorageBonus = 500

    public let mode: GameMode
    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var isOver = false
    public private(set) var powerUps: [PowerUp] = []
    /// Stelle im Belohnungszyklus.
    public private(set) var roof = 0
    /// Häuserzeile mit der Figur.
    public private(set) var city: City
    /// Die Figur wurde links aus dem Bild geschoben.
    public private(set) var hasFallen = false
    /// Grundgeschwindigkeit der Stadt (Design-Pixel pro Sekunde), z. B. vom Debug-Schieber.
    public var citySpeed = City.baseSpeed
    /// Zusätzliche Beschleunigung der Stadt pro Spielminute (0,1 = +10 % je Minute).
    public var cityAcceleration = City.defaultAccelerationPerMinute
    private var lastReward: PowerUp?
    private var rewardedPlan = 1
    private var rng: SplitMix64

    public init(seed: UInt64, mode: GameMode = .rooftop, cols: Int = 8, rows: Int = 8) {
        self.mode = mode
        rng = SplitMix64(seed: seed)
        city = City(seed: seed)
        board = Board.random(cols: cols, rows: rows, using: &rng)
    }

    public init(board: Board, seed: UInt64, mode: GameMode = .rooftop) {
        self.mode = mode
        self.board = board
        rng = SplitMix64(seed: seed)
        city = City(seed: seed)
        updateOver()
    }

    /// Lässt die Stadt `seconds` weiterwandern. Gibt `true` zurück, wenn die Figur gerade abgestürzt ist.
    public mutating func tick(_ seconds: Double) -> Bool {
        guard !isOver, mode == .rooftop else { return false }
        city.advance(by: seconds, plan: plan, base: citySpeed, accelerationPerMinute: cityAcceleration)
        guard city.isFigureLost else { return false }
        hasFallen = true
        isOver = true
        return true
    }

    /// Sorgt dafür, dass Häuser bis `x` (Bildschirmkoordinate) existieren, z. B. für breite Mac-Fenster.
    public mutating func extendCity(toScreenX x: Double) {
        city.extend(to: city.offset + x)
    }

    public var hasValidMove: Bool { board.hasValidMove }

    // MARK: Züge

    /// Tauscht zwei Nachbarn. Ergibt der Tausch keine Reihe, bleibt das Brett unverändert.
    public mutating func swap(_ a: Pos, _ b: Pos) -> SwapResult {
        guard !isOver, board.isValidMove(a, b),
              let ta = board[tile: a], let tb = board[tile: b] else { return .invalid }
        board.swapAt(a, b)
        guard ta.isHyper || tb.isHyper else {
            return finish(resolve(initial: nil, preferred: [b, a]))
        }
        // Hyperstein: liegt nach dem Tausch auf `b` (wenn er von `a` kam) bzw. `a`
        let hyperPos = ta.isHyper ? b : a
        let otherPos = ta.isHyper ? a : b
        var cells: Set<Pos>
        let target: Gem
        if ta.isHyper && tb.isHyper {
            cells = Set(board.positions)
            target = ta.gem
        } else {
            target = board[tile: otherPos]!.gem
            cells = Set(board.positions.filter { board.color(at: $0) == target })
            cells.insert(hyperPos)
        }
        board[tile: hyperPos]?.special = nil
        if ta.isHyper && tb.isHyper { board[tile: otherPos]?.special = nil }
        let blast = Detonation(pos: hyperPos, special: .hyper, gem: target, cells: cells.sorted(by: Self.reading))
        return finish(resolve(initial: cells, seed: [blast]))
    }

    // MARK: Power-ups

    /// Sprengt das 3×3-Feld um `center`.
    public mutating func useBomb(at center: Pos) -> SwapResult {
        useBlast(.bombe, radius: 1, at: center)
    }

    /// Sprengt das 5×5-Feld um `center`.
    public mutating func useAtom(at center: Pos) -> SwapResult {
        useBlast(.atom, radius: 2, at: center)
    }

    private mutating func useBlast(_ kind: PowerUp, radius: Int, at center: Pos) -> SwapResult {
        guard board.contains(center), powerUps.contains(kind) else { return .invalid }
        take(kind)
        return finish(resolve(initial: square(around: center, radius: radius)))
    }

    private func square(around center: Pos, radius: Int) -> Set<Pos> {
        var cells = Set<Pos>()
        for dc in -radius...radius {
            for dr in -radius...radius {
                let p = Pos(center.col + dc, center.row + dr)
                if board.contains(p) { cells.insert(p) }
            }
        }
        return cells
    }

    /// Mischt alle Steine (Spezialsteine bleiben erhalten), bis keine Reihe fertig ist und ein Zug existiert.
    public mutating func useShuffle() -> ShuffleResult {
        guard powerUps.contains(.strudel) else { return .invalid }
        take(.strudel)
        let positions = board.positions
        for _ in 0..<300 {
            var order = Array(positions.indices)
            order.shuffle(using: &rng)
            var next = Board(cols: board.cols, rows: board.rows)
            var moves: [Pos: Pos] = [:]
            for (i, source) in order.enumerated() {
                next[tile: positions[i]] = board[tile: positions[source]]
                moves[positions[source]] = positions[i]
            }
            if next.runs().isEmpty && next.hasValidMove {
                board = next
                updateOver()
                return ShuffleResult(isValid: true, moves: moves, replacedBoard: false, isGameOver: isOver)
            }
        }
        board = Board.random(cols: board.cols, rows: board.rows, using: &rng)
        updateOver()
        return ShuffleResult(isValid: true, moves: [:], replacedBoard: true, isGameOver: isOver)
    }

    /// Entfernt alle Steine der Farbe `color`.
    public mutating func usePurge(_ color: Gem) -> SwapResult {
        guard powerUps.contains(.farbtilger) else { return .invalid }
        let cells = Set(board.positions.filter { board.color(at: $0) == color })
        guard !cells.isEmpty else { return .invalid }
        take(.farbtilger)
        return finish(resolve(initial: cells))
    }

    /// Startet eine Fresser-Runde: zwei zufällige Farben versteinern, der Automat startet auf einem freien Feld.
    public mutating func startFresser() -> FresserRound? {
        guard powerUps.contains(.fresser) else { return nil }
        var kinds = Gem.allCases.filter { kind in board.positions.contains { board.color(at: $0) == kind } }
        guard kinds.count >= 3 else { return nil }
        kinds.shuffle(using: &rng)
        let stones = Set(kinds.prefix(2))
        let free = board.positions.filter { p in board.color(at: p).map { !stones.contains($0) } ?? false }
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

    /// Lesereihenfolge: Zeile für Zeile, links nach rechts.
    static func reading(_ a: Pos, _ b: Pos) -> Bool {
        (a.row, a.col) < (b.row, b.col)
    }

    /// Löst Reihen und Kettenreaktionen auf.
    /// - Parameters:
    ///   - initial: Felder, die vorab verschwinden (Power-ups, Hyperstein).
    ///   - preferred: Bevorzugte Felder für neue Spezialsteine (die beiden getauschten Felder).
    ///   - seed: Auslösung, die schon feststeht (Hyperstein-Tausch), für die Effekte.
    private mutating func resolve(initial: Set<Pos>?, preferred: [Pos] = [], seed: [Detonation] = []) -> [CascadeStep] {
        var steps: [CascadeStep] = []
        var combo = 0
        var forced = initial
        var seeded = seed
        var preferredCells = preferred
        while true {
            var runs: [Run] = []
            var cleared: Set<Pos>
            var points: Int
            var created: [Creation] = []
            if let cells = forced {
                forced = nil
                combo += 1
                cleared = cells
                points = cells.count * Self.pointsPerGem
            } else {
                let found = board.runs()
                if found.isEmpty { break }
                combo += 1
                runs = found
                cleared = Set(found.flatMap(\.cells))
                points = Self.points(for: found, combo: combo)
                created = plannedCreations(for: found, preferred: preferredCells)
                for c in created { cleared.remove(c.pos) }
            }
            preferredCells = []

            // Spezialsteine im abgeräumten Bereich lösen aus, auch in Ketten
            let createdCells = Set(created.map(\.pos))
            var detonations = seeded
            seeded = []
            var done = Set(detonations.map(\.pos))
            var queue = cleared.filter { board[tile: $0]?.special != nil && !done.contains($0) }
            while let p = queue.popFirst() {
                guard !done.contains(p), let tile = board[tile: p], let special = tile.special else { continue }
                done.insert(p)
                let (hits, gem) = blast(special, at: p, gem: tile.gem)
                detonations.append(Detonation(pos: p, special: special, gem: gem, cells: hits.sorted(by: Self.reading)))
                for h in hits where !cleared.contains(h) && !createdCells.contains(h) {
                    cleared.insert(h)
                    if board[tile: h]?.special != nil { queue.insert(h) }
                    points += Self.pointsPerGem * combo
                }
            }
            points += detonations.count * Self.pointsPerDetonation * combo

            for p in cleared { board[p] = nil }
            for c in created { board[tile: c.pos] = Tile(c.gem, c.special) }
            let (falls, spawns) = collapse()
            score += points
            steps.append(CascadeStep(
                runs: runs,
                cleared: cleared.sorted(by: Self.reading),
                falls: falls,
                spawns: spawns,
                combo: combo,
                points: points,
                created: created,
                detonations: detonations
            ))
        }
        return steps
    }

    /// Wirkung eines Spezialsteins: getroffene Felder und (beim Hyperstein) die gelöschte Farbe.
    private func blast(_ special: Special, at p: Pos, gem: Gem) -> (Set<Pos>, Gem) {
        switch special {
        case .line(let horizontal):
            let cells = horizontal
                ? (0..<board.cols).map { Pos($0, p.row) }
                : (0..<board.rows).map { Pos(p.col, $0) }
            return (Set(cells), gem)
        case .bomb:
            return (square(around: p, radius: 1), gem)
        case .hyper:
            // Ausgelöst ohne Tausch: löscht die häufigste Farbe
            var counts: [Gem: Int] = [:]
            for q in board.positions { if let c = board.color(at: q) { counts[c, default: 0] += 1 } }
            let target = counts.max { a, b in a.value != b.value ? a.value < b.value : a.key.rawValue > b.key.rawValue }?.key ?? gem
            return (Set(board.positions.filter { board.color(at: $0) == target }), target)
        }
    }

    /// Welche Spezialsteine aus den Reihen entstehen. Reihen mit gemeinsamen Feldern bilden eine Gruppe
    /// (L- und T-Formen). Fünfer → Hyperstein, L/T → Bombe, Vierer → Linie.
    private func plannedCreations(for runs: [Run], preferred: [Pos]) -> [Creation] {
        var groups: [[Run]] = []
        for run in runs {
            let cells = Set(run.cells)
            let touching = groups.indices.filter { i in groups[i].contains { !cells.isDisjoint(with: $0.cells) } }
            var merged = [run]
            for i in touching.reversed() {
                merged += groups[i]
                groups.remove(at: i)
            }
            groups.append(merged)
        }

        var out: [Creation] = []
        for group in groups {
            let longest = group.max { $0.length < $1.length }!
            let hasHorizontal = group.contains { $0.isHorizontal }
            let hasVertical = group.contains { !$0.isHorizontal }
            let special: Special
            if longest.length >= 5 {
                special = .hyper
            } else if hasHorizontal && hasVertical {
                special = .bomb
            } else if longest.length == 4 {
                special = .line(horizontal: longest.isHorizontal)
            } else {
                continue
            }
            let cells = Set(group.flatMap(\.cells))
            var candidates = preferred.filter { cells.contains($0) }
            if special == .bomb {
                let h = Set(group.filter(\.isHorizontal).flatMap(\.cells))
                let v = Set(group.filter { !$0.isHorizontal }.flatMap(\.cells))
                candidates += h.intersection(v).sorted(by: Self.reading)
            }
            candidates.append(longest.center)
            candidates += longest.cells
            let taken = Set(out.map(\.pos))
            guard let pos = candidates.first(where: { board[tile: $0]?.special == nil && !taken.contains($0) }) else { continue }
            out.append(Creation(pos: pos, gem: longest.gem, special: special))
        }
        return out
    }

    private mutating func finish(_ steps: [CascadeStep]) -> SwapResult {
        let rewards = collectRewards()
        updateOver()
        return SwapResult(isValid: true, steps: steps, rewards: rewards, isGameOver: isOver)
    }

    private mutating func updateOver() {
        isOver = hasFallen || (!board.hasValidMove && powerUps.isEmpty)
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
                guard let tile = board[tile: Pos(col, row)] else { continue }
                if row != write {
                    board[tile: Pos(col, write)] = tile
                    board[tile: Pos(col, row)] = nil
                    falls.append(Fall(gem: tile.gem, from: Pos(col, row), to: Pos(col, write), special: tile.special))
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

    /// Jeder neue Plan: Figur springt ein Haus weiter und bringt das nächste Power-up aus `roofRewards`.
    private mutating func collectRewards() -> [PlanReward] {
        var rewards: [PlanReward] = []
        while plan > rewardedPlan {
            rewardedPlan += 1
            guard mode == .rooftop else {
                rewards.append(PlanReward(plan: rewardedPlan, roof: 0, building: nil, powerUp: nil, bonusPoints: 0, reachedTop: false))
                continue
            }
            roof += 1
            let top = roof >= Self.roofCount - 1
            let kind = top ? pickReward(from: [.fresser, .atom]) : pickReward(from: PowerUp.allCases)
            var granted: PowerUp?
            var bonus = 0
            if powerUps.count < Self.maxPowerUps {
                powerUps.append(kind)
                granted = kind
            } else {
                bonus = Self.fullStorageBonus
                score += bonus
            }
            let building = city.jump()
            rewards.append(PlanReward(plan: rewardedPlan, roof: roof, building: building, powerUp: granted, bonusPoints: bonus, reachedTop: top))
            if top { roof = 0 }
        }
        return rewards
    }

    /// Gewichteter Zufall, ohne dasselbe Power-up zweimal hintereinander.
    private mutating func pickReward(from options: [PowerUp]) -> PowerUp {
        let pool = options.count > 1 ? options.filter { $0 != lastReward } : options
        let total = pool.reduce(0) { $0 + (Self.rewardWeights[$1] ?? 1) }
        var roll = rng.unit() * total
        var choice = pool[pool.count - 1]
        for kind in pool {
            roll -= Self.rewardWeights[kind] ?? 1
            if roll < 0 {
                choice = kind
                break
            }
        }
        lastReward = choice
        return choice
    }

    /// Für Tests: Lager leeren.
    mutating func clearPowerUps() {
        powerUps.removeAll()
        updateOver()
    }

    /// Für Tests: ein bestimmtes Power-up ins Lager legen.
    mutating func grant(_ kind: PowerUp) {
        powerUps.append(kind)
        updateOver()
    }

    /// Für Tests: Punkte gutschreiben und Belohnungen auswerten.
    mutating func award(points: Int) -> [PlanReward] {
        score += points
        let rewards = collectRewards()
        updateOver()
        return rewards
    }
}
