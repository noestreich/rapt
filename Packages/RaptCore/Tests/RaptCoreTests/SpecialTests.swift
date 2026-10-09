import XCTest
@testable import RaptCore

final class SpecialTests: XCTestCase {
    /// Linien-Stein wird selbst getauscht und bildet eine Dreierreihe: die ganze Zeile muss weg.
    func testSwappedLineStoneKeepsItsPowerAndClearsTheRow() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNKSU",
            "OOZKN",
            "SUOSZ",
        ], specials: [Pos(2, 3): .line(horizontal: true)]), seed: 1)
        let result = game.swap(Pos(2, 2), Pos(2, 3))
        XCTAssertTrue(result.isValid)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.detonations.map(\.special), [.line(horizontal: true)])
        XCTAssertEqual(Set(first.cleared), Set((0..<5).map { Pos($0, 2) }))
    }

    func testSwapKeepsSpecials() {
        var board = Board(["OZ"], specials: [Pos(0, 0): .bomb])
        board.swapAt(Pos(0, 0), Pos(1, 0))
        XCTAssertEqual(board[tile: Pos(1, 0)], Tile(.orden, .bomb))
        XCTAssertEqual(board[tile: Pos(0, 0)], Tile(.zahnrad))
    }

    func testFourInARowCreatesLineAtSwappedCell() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNKSU",
            "SUOKN",
            "OOZOS",
        ]), seed: 1)
        let result = game.swap(Pos(2, 2), Pos(2, 3))
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.created, [Creation(pos: Pos(2, 3), gem: .orden, special: .line(horizontal: true))])
        XCTAssertEqual(Set(first.cleared), [Pos(0, 3), Pos(1, 3), Pos(3, 3)])
        XCTAssertTrue(first.detonations.isEmpty)
    }

    func testLineInARunClearsItsColumn() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNKSU",
            "SUOKN",
            "OOZOS",
        ], specials: [Pos(1, 3): .line(horizontal: false)]), seed: 1)
        let result = game.swap(Pos(2, 2), Pos(2, 3))
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.detonations.map(\.special), [.line(horizontal: false)])
        XCTAssertEqual(Set(first.cleared), [Pos(0, 3), Pos(1, 3), Pos(3, 3), Pos(1, 0), Pos(1, 1), Pos(1, 2)])
        XCTAssertEqual(first.created.map(\.pos), [Pos(2, 3)])
    }

    func testLShapeCreatesBomb() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNKSU",
            "OOZOK",
            "SUOKN",
            "NKORS",
        ]), seed: 1)
        let result = game.swap(Pos(2, 2), Pos(3, 2))
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.created, [Creation(pos: Pos(2, 2), gem: .orden, special: .bomb)])
        XCTAssertEqual(first.cleared.count, 4)
    }

    func testFiveInARowCreatesHyper() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNOSU",
            "OOZOO",
            "SUKNZ",
        ]), seed: 1)
        let result = game.swap(Pos(2, 1), Pos(2, 2))
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.created, [Creation(pos: Pos(2, 2), gem: .orden, special: .hyper)])
        XCTAssertEqual(first.cleared.count, 4)
    }

    func testHyperSwapClearsTheOtherColor() throws {
        var game = Game(board: Board([
            "KSUO",
            "ZNKR",
            "ZURS",
            "RRNK",
        ], specials: [Pos(0, 0): .hyper]), seed: 1)
        XCTAssertTrue(game.board.isValidMove(Pos(0, 0), Pos(1, 0)))
        let result = game.swap(Pos(0, 0), Pos(1, 0))
        let first = try XCTUnwrap(result.steps.first)
        // Hyperstein landet auf (1,0); Signal-Steine auf (0,0) und (3,2)
        XCTAssertEqual(Set(first.cleared), [Pos(0, 0), Pos(1, 0), Pos(3, 2)])
        XCTAssertEqual(first.detonations.first?.special, .hyper)
        XCTAssertEqual(first.detonations.first?.gem, .signal)
    }

    func testBombPowerUpTriggersSpecialsInChain() throws {
        var board = Board([
            "KSUNRK",
            "ZNKSUS",
            "SUOKNZ",
            "OKZOSU",
            "NRSUKN",
        ])
        board[tile: Pos(1, 1)] = Tile(.niete, .line(horizontal: true))
        var game = Game(board: board, seed: 2)
        _ = game.award(points: Game.planThreshold(2))
        let result = game.useBomb(at: Pos(0, 0))
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.detonations.map(\.special), [.line(horizontal: true)])
        // 2×2 Ecke plus die restliche Zeile 1
        XCTAssertEqual(first.cleared.count, 4 + 4)
    }

    func testSpecialsDetonateImmediatelyInMinigamesAndOnlyOnce() throws {
        var board = Board([
            "KSUNRK",
            "ZNKSUS",
            "SUOKNZ",
            "OKZOSU",
            "NRSUKN",
        ])
        board[tile: Pos(1, 1)] = Tile(.niete, .line(horizontal: true))
        var game = Game(board: board, seed: 2)
        // Sofort-Auslösung trifft die restliche Zeile, ohne das Brett zu verändern
        let blast = try XCTUnwrap(game.detonation(at: Pos(1, 1), excluding: [Pos(1, 1)]))
        XCTAssertEqual(blast.special, .line(horizontal: true))
        XCTAssertEqual(blast.cells, [Pos(0, 1), Pos(2, 1), Pos(3, 1), Pos(4, 1), Pos(5, 1)])
        XCTAssertNil(game.detonation(at: Pos(0, 0), excluding: []), "Normaler Stein löst nichts aus")
        XCTAssertNotNil(game.board[tile: Pos(1, 1)]?.special, "Brett bleibt unverändert")

        // Abrechnung: die Zeile verschwindet, der Linienstein geht nicht noch einmal los, zählt aber als Auslösung
        game.grant(.invasion)
        XCTAssertTrue(game.startArcade(.invasion))
        let row = Set((0..<6).map { Pos($0, 1) })
        let result = game.finishArcade(cleared: row, detonated: [Pos(1, 1)])
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertTrue(first.detonations.isEmpty)
        XCTAssertEqual(Set(first.cleared), row)
        XCTAssertEqual(first.points, 6 * Game.pointsPerGem + Game.pointsPerDetonation)
    }

    func testSpecialsFallWithTheirTile() throws {
        var game = Game(board: Board([
            "KSUNR",
            "ZNKSU",
            "SUOKN",
            "OOZOS",
        ], specials: [Pos(4, 0): .bomb]), seed: 1)
        _ = game.swap(Pos(2, 2), Pos(2, 3))
        // Spalte 4 bleibt unberührt, die Bombe liegt weiter oben rechts
        XCTAssertEqual(game.board[tile: Pos(4, 0)]?.special, .bomb)
    }
}
