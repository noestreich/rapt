/// Das Spielfeld als Raster aus Steinen. Leere Felder gibt es nur während der Auflösung.
public struct Board: Equatable, Sendable {
    public let cols: Int
    public let rows: Int
    private var cells: [Tile?]

    public init(cols: Int, rows: Int) {
        precondition(cols > 0 && rows > 0)
        self.cols = cols
        self.rows = rows
        cells = Array(repeating: nil, count: cols * rows)
    }

    /// Oberste Zeile zuerst. Jedes Zeichen ist ein Stein (O Z S U K R N), "." ist leer.
    /// `specials` setzt Spezialsteine auf einzelne Felder.
    public init(_ lines: [String], specials: [Pos: Special] = [:]) {
        let rowCount = lines.count
        let colCount = lines.first?.count ?? 0
        let parsed: [Tile?] = lines.flatMap { line in line.map { Gem(symbol: $0).map { Tile($0) } } }
        precondition(colCount > 0 && rowCount > 0)
        precondition(parsed.count == colCount * rowCount, "Alle Zeilen müssen gleich lang sein")
        rows = rowCount
        cols = colCount
        cells = parsed
        for (p, special) in specials { cells[p.row * cols + p.col]?.special = special }
    }

    /// Farbe des Steins (auch bei Spezialsteinen). Setzen erzeugt einen normalen Stein.
    public subscript(_ p: Pos) -> Gem? {
        get { cells[p.row * cols + p.col]?.gem }
        set { cells[p.row * cols + p.col] = newValue.map { Tile($0) } }
    }

    public subscript(tile p: Pos) -> Tile? {
        get { cells[p.row * cols + p.col] }
        set { cells[p.row * cols + p.col] = newValue }
    }

    /// Farbe, mit der der Stein Reihen bildet. Hypersteine haben keine.
    public func color(at p: Pos) -> Gem? {
        guard let tile = self[tile: p], !tile.isHyper else { return nil }
        return tile.gem
    }

    public subscript(col col: Int, row row: Int) -> Gem? {
        get { self[Pos(col, row)] }
        set { self[Pos(col, row)] = newValue }
    }

    public func contains(_ p: Pos) -> Bool {
        p.col >= 0 && p.col < cols && p.row >= 0 && p.row < rows
    }

    /// Tauscht zwei Felder samt Spezialstein.
    public mutating func swapAt(_ a: Pos, _ b: Pos) {
        let t = self[tile: a]
        self[tile: a] = self[tile: b]
        self[tile: b] = t
    }

    public var isFull: Bool { cells.allSatisfy { $0 != nil } }

    public var positions: [Pos] {
        (0..<rows).flatMap { row in (0..<cols).map { Pos($0, row) } }
    }

    /// Textdarstellung im selben Format wie `init(_ lines:)`.
    public var lines: [String] {
        (0..<rows).map { row in
            String((0..<cols).map { self[col: $0, row: row]?.symbol ?? "." })
        }
    }

    /// Zufällig gefülltes Brett ohne fertige Dreierreihen und mit mindestens einem gültigen Zug.
    public static func random<G: RandomNumberGenerator>(cols: Int, rows: Int, using rng: inout G) -> Board {
        while true {
            var board = Board(cols: cols, rows: rows)
            for row in 0..<rows {
                for col in 0..<cols {
                    var gem: Gem
                    repeat {
                        gem = Gem.random(using: &rng)
                    } while board.wouldCompleteRun(gem, at: Pos(col, row))
                    board[col: col, row: row] = gem
                }
            }
            if board.hasValidMove { return board }
        }
    }

    /// Prüft beim zeilenweisen Füllen von oben links, ob `gem` an `p` eine Dreierreihe schließen würde.
    func wouldCompleteRun(_ gem: Gem, at p: Pos) -> Bool {
        let left = p.col >= 2
            && self[col: p.col - 1, row: p.row] == gem
            && self[col: p.col - 2, row: p.row] == gem
        let up = p.row >= 2
            && self[col: p.col, row: p.row - 1] == gem
            && self[col: p.col, row: p.row - 2] == gem
        return left || up
    }
}
