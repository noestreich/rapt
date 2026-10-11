/// Gespeicherter Spielstand zum Fortsetzen nach einem Neustart der App. Enthält alles, was den weiteren
/// Verlauf bestimmt (Brett mit Spezialsteinen, Punkte, Lager, Stadt, Zufallsgeneratoren); als JSON speicherbar.
public struct GameSnapshot: Codable, Equatable, Sendable {
    public struct Cell: Codable, Equatable, Sendable {
        public let col: Int
        public let row: Int
        /// "h"/"v" Linie waagerecht/senkrecht, "b" Bombe, "x" Hyperstein.
        public let kind: String
    }

    public struct CityState: Codable, Equatable, Sendable {
        public let buildings: [[Double]]
        public let offset: Double
        public let figureIndex: Int
        public let elapsed: Double
        public let rng: UInt64
    }

    public static let version = 1

    public var version = GameSnapshot.version
    public let mode: String
    public let lines: [String]
    public let specials: [Cell]
    public let score: Int
    public let powerUps: [String]
    public let roof: Int
    public let lastReward: String?
    public let rewardedPlan: Int
    public let rng: UInt64
    public let city: CityState
}

extension Special {
    var code: String {
        switch self {
        case .line(let horizontal): return horizontal ? "h" : "v"
        case .bomb: return "b"
        case .hyper: return "x"
        }
    }

    init?(code: String) {
        switch code {
        case "h": self = .line(horizontal: true)
        case "v": self = .line(horizontal: false)
        case "b": self = .bomb
        case "x": self = .hyper
        default: return nil
        }
    }
}

extension City {
    var snapshot: GameSnapshot.CityState {
        GameSnapshot.CityState(buildings: buildings.map { [$0.x, Double($0.width), Double($0.height)] },
                               offset: offset, figureIndex: figureIndex, elapsed: elapsed, rng: rngState)
    }

    init?(snapshot s: GameSnapshot.CityState) {
        let buildings = s.buildings.compactMap { b in b.count == 3 ? Building(x: b[0], width: Int(b[1]), height: Int(b[2])) : nil }
        guard buildings.count == s.buildings.count, buildings.indices.contains(s.figureIndex) else { return nil }
        self.init(buildings: buildings, offset: s.offset, figureIndex: s.figureIndex, elapsed: s.elapsed, rng: s.rng)
    }
}

extension Game {
    /// Aktueller Stand zum Speichern.
    public var snapshot: GameSnapshot {
        var specials: [GameSnapshot.Cell] = []
        for p in board.positions {
            if let special = board[tile: p]?.special { specials.append(.init(col: p.col, row: p.row, kind: special.code)) }
        }
        return GameSnapshot(mode: mode.rawValue, lines: board.lines, specials: specials, score: score,
                            powerUps: powerUps.map(\.rawValue), roof: roof, lastReward: lastRewardKind?.rawValue,
                            rewardedPlan: rewardedPlanStep, rng: rngState, city: city.snapshot)
    }

    /// Stellt einen gespeicherten Stand wieder her. `nil`, wenn er unbrauchbar oder das Spiel schon vorbei ist.
    public init?(snapshot s: GameSnapshot) {
        guard s.version == GameSnapshot.version, let mode = GameMode(rawValue: s.mode), let city = City(snapshot: s.city),
              let first = s.lines.first, !first.isEmpty, s.lines.allSatisfy({ $0.count == first.count }),
              s.lines.allSatisfy({ $0.allSatisfy { Gem(symbol: $0) != nil } }) else { return nil }
        var specials: [Pos: Special] = [:]
        for cell in s.specials {
            guard let special = Special(code: cell.kind), (0..<first.count).contains(cell.col), (0..<s.lines.count).contains(cell.row)
            else { return nil }
            specials[Pos(cell.col, cell.row)] = special
        }
        self.init(board: Board(s.lines, specials: specials), seed: s.rng, mode: mode)
        restore(score: s.score, powerUps: s.powerUps.compactMap(PowerUp.init(rawValue:)), roof: s.roof,
                lastReward: s.lastReward.flatMap(PowerUp.init(rawValue:)), rewardedPlan: s.rewardedPlan, city: city)
        if isOver { return nil }
    }
}
