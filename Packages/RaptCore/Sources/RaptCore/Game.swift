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
    public static let rewardWeights: [PowerUp: Double] = [
        .bombe: 30, .farbtilger: 21, .strudel: 16, .atom: 12, .fresser: 9, .invasion: 6, .abriss: 6,
    ]
    /// Seltene Höhepunkte: garantiert am Ende jedes Zyklus.
    public static let topRewards: [PowerUp] = [.fresser, .atom, .invasion, .abriss]
    /// Jeder `roofCount - 1`. Sprung schließt einen Zyklus ab und bringt garantiert ein seltenes Power-up.
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
    /// `detonated`: Spezialsteine, die schon während der Runde ausgelöst haben (gehen nicht noch einmal los).
    public mutating func finishFresser(_ round: FresserRound, eaten: Set<Pos>, detonated: Set<Pos> = []) -> SwapResult {
        let cells = eaten.filter { p in board.contains(p) && board[p].map { !round.stones.contains($0) } ?? false }
        guard !cells.isEmpty else {
            updateOver()
            return SwapResult(isValid: true, steps: [], rewards: [], isGameOver: isOver)
        }
        return finish(resolve(initial: cells, spent: detonated.intersection(cells)))
    }

    /// Startet ein Minispiel (Invasion, Abrissbirne): nimmt das Power-up aus dem Lager.
    public mutating func startArcade(_ kind: PowerUp) -> Bool {
        guard kind.isArcade, powerUps.contains(kind) else { return false }
        take(kind)
        return true
    }

    /// Beendet ein Minispiel: Die getroffenen Felder verschwinden, danach laufen Kaskaden wie gewohnt.
    /// `detonated`: Spezialsteine, die schon während der Runde ausgelöst haben (gehen nicht noch einmal los).
    public mutating func finishArcade(cleared: Set<Pos>, detonated: Set<Pos> = []) -> SwapResult {
        let cells = cleared.filter { board.contains($0) && board[$0] != nil }
        guard !cells.isEmpty else {
            updateOver()
            return SwapResult(isValid: true, steps: [], rewards: [], isGameOver: isOver)
        }
        return finish(resolve(initial: cells, spent: detonated.intersection(cells)))
    }

    /// Wirkung eines Spezialsteins, der sofort auslöst (in Minispielen und beim Fresser), ohne das Brett zu
    /// verändern. `gone`: schon abgeräumte Felder; sie werden nicht getroffen und zählen beim Hyperstein nicht mit.
    public func detonation(at p: Pos, excluding gone: Set<Pos>) -> Detonation? {
        guard let tile = board[tile: p], let special = tile.special else { return nil }
        let (cells, gem) = blast(special, at: p, gem: tile.gem, excluding: gone)
        return Detonation(pos: p, special: special, gem: gem, cells: cells.subtracting(gone).sorted(by: Self.reading))
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
    ///   - spent: Spezialsteine in `initial`, die schon ausgelöst haben (Minispiele): zählen als Auslösung,
    ///     gehen aber nicht noch einmal los.
    private mutating func resolve(initial: Set<Pos>?, preferred: [Pos] = [], seed: [Detonation] = [],
                                  spent: Set<Pos> = []) -> [CascadeStep] {
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
                points = cells.count * Self.pointsPerGem + spent.count * Self.pointsPerDetonation
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
            var done = Set(detonations.map(\.pos)).union(spent)
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
    private func blast(_ special: Special, at p: Pos, gem: Gem, excluding gone: Set<Pos> = []) -> (Set<Pos>, Gem) {
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
            let present = board.positions.filter { !gone.contains($0) }
            for q in present { if let c = board.color(at: q) { counts[c, default: 0] += 1 } }
            let target = counts.max { a, b in a.value != b.value ? a.value < b.value : a.key.rawValue > b.key.rawValue }?.key ?? gem
            return (Set(present.filter { board.color(at: $0) == target }), target)
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
            let kind = top ? pickReward(from: Self.topRewards, uniform: true) : pickReward(from: PowerUp.allCases)
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
    /// `uniform`: alle Optionen gleich wahrscheinlich (seltene Power-ups am Zyklusende).
    private mutating func pickReward(from options: [PowerUp], uniform: Bool = false) -> PowerUp {
        let pool = options.count > 1 ? options.filter { $0 != lastReward } : options
        func weight(_ kind: PowerUp) -> Double { uniform ? 1 : Self.rewardWeights[kind] ?? 1 }
        let total = pool.reduce(0) { $0 + weight($1) }
        var roll = rng.unit() * total
        var choice = pool[pool.count - 1]
        for kind in pool {
            roll -= weight(kind)
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

    /// Legt ein Power-up ins Lager (z. B. Easteregg, Tests). `false`, wenn das Lager voll ist.
    @discardableResult
    public mutating func grant(_ kind: PowerUp) -> Bool {
        guard powerUps.count < Self.maxPowerUps else { return false }
        powerUps.append(kind)
        updateOver()
        return true
    }

    // MARK: Sternenbahn

    /// Alle so viele Sprünge startet im Dächerlauf die Sternenbahn (ohne Funkspruch, zusätzlich zum Power-up).
    public static let starRunEvery = 10
    /// Anteil der Münzen, ab dem es ein seltenes Power-up gibt.
    public static let starRunRareShare = 0.8
    /// Alle Münzen zusammen bringen diesen Anteil des aktuellen Sprungs (so höchstens ein Sprung je Fahrt).
    public static let starRunPlanShare = 0.5

    /// Punkte der Sternenbahn: anteilig nach eingesammelten Münzen bis zu einem halben Sprung des aktuellen
    /// Plans; wächst so mit dem Spielfortschritt mit. Auf 10 gerundet.
    public func starRunPoints(collected: Int, total: Int) -> Int {
        guard total > 0, collected > 0 else { return 0 }
        let step = Double(Self.pointsPerPlanStep * plan)
        let share = min(1, Double(collected) / Double(total))
        return Int((step * Self.starRunPlanShare * share / 10).rounded()) * 10
    }

    /// Löst dieser Zug die Sternenbahn aus? Eine Reihe aus mindestens vier Kristallen (auch in Kaskaden).
    public static func hasStarRunTrigger(_ result: SwapResult) -> Bool {
        result.steps.contains { step in step.runs.contains { $0.gem == .kristall && $0.length >= 4 } }
    }

    /// Ist der Sprung, der zu `plan` führt, ein Sternenbahn-Sprung (10., 20., 30. …)?
    public static func isStarRunJump(plan: Int) -> Bool {
        let jump = plan - 1
        return jump > 0 && jump % starRunEvery == 0
    }

    /// Beendet die Sternenbahn: Münzpunkte gutschreiben (`starRunPoints`); im Dächerlauf ab 80 % der Münzen ein
    /// seltenes Power-up (bei vollem Lager stattdessen Bonuspunkte; Endlos hat kein Lager). Das Brett bleibt unverändert.
    public mutating func finishStarRun(collected: Int, total: Int) -> (result: SwapResult, powerUp: PowerUp?, points: Int) {
        let points = starRunPoints(collected: collected, total: total)
        score += points
        var granted: PowerUp?
        if mode == .rooftop, total > 0, Double(collected) >= Double(total) * Self.starRunRareShare {
            let kind = pickReward(from: Self.topRewards, uniform: true)
            if powerUps.count < Self.maxPowerUps {
                powerUps.append(kind)
                granted = kind
            } else {
                score += Self.fullStorageBonus
            }
        }
        let rewards = collectRewards()
        updateOver()
        return (SwapResult(isValid: true, steps: [], rewards: rewards, isGameOver: isOver), granted, points)
    }

    /// Debug: so viele Pläne auf einmal schaffen (Sprünge samt Power-ups), ohne Steine zu bewegen.
    public mutating func debugAdvance(plans: Int) -> SwapResult {
        score = max(score, Self.planThreshold(plan + max(0, plans)))
        return finish([])
    }

    /// Für Tests: Punkte gutschreiben und Belohnungen auswerten.
    mutating func award(points: Int) -> [PlanReward] {
        score += points
        let rewards = collectRewards()
        updateOver()
        return rewards
    }
}
