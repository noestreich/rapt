/// Die sieben Steinsorten.
public enum Gem: Int, CaseIterable, Sendable {
    case orden, zahnrad, signal, uranglas, kristall, roehre, niete

    public static func random<G: RandomNumberGenerator>(using rng: inout G) -> Gem {
        allCases[Int.random(in: 0..<allCases.count, using: &rng)]
    }

    /// Kürzel für Test-Bretter: O Z S U K R N.
    public init?(symbol: Character) {
        switch symbol {
        case "O": self = .orden
        case "Z": self = .zahnrad
        case "S": self = .signal
        case "U": self = .uranglas
        case "K": self = .kristall
        case "R": self = .roehre
        case "N": self = .niete
        default: return nil
        }
    }

    public var symbol: Character {
        switch self {
        case .orden: return "O"
        case .zahnrad: return "Z"
        case .signal: return "S"
        case .uranglas: return "U"
        case .kristall: return "K"
        case .roehre: return "R"
        case .niete: return "N"
        }
    }
}

/// Feldposition. Zeile 0 ist oben.
public struct Pos: Hashable, Sendable, CustomStringConvertible {
    public var col: Int
    public var row: Int

    public init(_ col: Int, _ row: Int) {
        self.col = col
        self.row = row
    }

    public func isAdjacent(to other: Pos) -> Bool {
        abs(col - other.col) + abs(row - other.row) == 1
    }

    public var description: String { "(\(col),\(row))" }
}
