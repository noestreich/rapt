/// Eine waagerechte oder senkrechte Reihe aus mindestens drei gleichen Steinen.
public struct Run: Equatable, Sendable {
    public let gem: Gem
    public let cells: [Pos]
    public let isHorizontal: Bool

    public var length: Int { cells.count }

    /// Mittleres Feld, z. B. für Punkte-Einblendungen.
    public var center: Pos { cells[cells.count / 2] }
}

public struct Move: Hashable, Sendable {
    public let a: Pos
    public let b: Pos

    public init(_ a: Pos, _ b: Pos) {
        self.a = a
        self.b = b
    }
}

extension Board {
    /// Alle Reihen ab Länge 3. Ein Stein kann in einer waagerechten und einer senkrechten Reihe stecken.
    public func runs() -> [Run] {
        var out: [Run] = []
        for row in 0..<rows {
            var start = 0
            for col in 1...cols {
                if col < cols, let g = color(at: Pos(col, row)), g == color(at: Pos(start, row)) { continue }
                if col - start >= 3, let g = color(at: Pos(start, row)) {
                    out.append(Run(gem: g, cells: (start..<col).map { Pos($0, row) }, isHorizontal: true))
                }
                start = col
            }
        }
        for col in 0..<cols {
            var start = 0
            for row in 1...rows {
                if row < rows, let g = color(at: Pos(col, row)), g == color(at: Pos(col, start)) { continue }
                if row - start >= 3, let g = color(at: Pos(col, start)) {
                    out.append(Run(gem: g, cells: (start..<row).map { Pos(col, $0) }, isHorizontal: false))
                }
                start = row
            }
        }
        return out
    }

    /// Liegt `p` in einer Reihe aus mindestens drei gleichen Steinen?
    func hasRun(through p: Pos) -> Bool {
        guard let g = color(at: p) else { return false }
        var h = 1
        var c = p.col - 1
        while c >= 0, color(at: Pos(c, p.row)) == g { h += 1; c -= 1 }
        c = p.col + 1
        while c < cols, color(at: Pos(c, p.row)) == g { h += 1; c += 1 }
        if h >= 3 { return true }
        var v = 1
        var r = p.row - 1
        while r >= 0, color(at: Pos(p.col, r)) == g { v += 1; r -= 1 }
        r = p.row + 1
        while r < rows, color(at: Pos(p.col, r)) == g { v += 1; r += 1 }
        return v >= 3
    }

    /// Ein Tausch ist gültig, wenn er eine Reihe ergibt oder ein Hyperstein beteiligt ist.
    public func isValidMove(_ a: Pos, _ b: Pos) -> Bool {
        guard contains(a), contains(b), a.isAdjacent(to: b),
              let ta = self[tile: a], let tb = self[tile: b] else { return false }
        if ta.isHyper || tb.isHyper { return true }
        guard ta.gem != tb.gem else { return false }
        var copy = self
        copy.swapAt(a, b)
        return copy.hasRun(through: a) || copy.hasRun(through: b)
    }

    public func validMoves() -> [Move] {
        var out: [Move] = []
        for p in positions {
            for q in [Pos(p.col + 1, p.row), Pos(p.col, p.row + 1)] where isValidMove(p, q) {
                out.append(Move(p, q))
            }
        }
        return out
    }

    public var hasValidMove: Bool {
        for p in positions {
            if isValidMove(p, Pos(p.col + 1, p.row)) || isValidMove(p, Pos(p.col, p.row + 1)) { return true }
        }
        return false
    }
}
