import XCTest
@testable import RaptCore

final class BoardTests: XCTestCase {
    func testFindsHorizontalAndVerticalRuns() {
        let board = Board([
            "OOOZ",
            "SZUK",
            "SKUR",
            "SNUR",
        ])
        let runs = board.runs()
        XCTAssertEqual(runs.count, 3)
        XCTAssertTrue(runs.contains(Run(gem: .orden, cells: [Pos(0, 0), Pos(1, 0), Pos(2, 0)], isHorizontal: true)))
        XCTAssertTrue(runs.contains(Run(gem: .signal, cells: [Pos(0, 1), Pos(0, 2), Pos(0, 3)], isHorizontal: false)))
        XCTAssertTrue(runs.contains(Run(gem: .uranglas, cells: [Pos(2, 1), Pos(2, 2), Pos(2, 3)], isHorizontal: false)))
    }

    func testFindsLongRunAtEdge() {
        let board = Board([
            "KZNNNN",
            "ZKSUKR",
        ])
        let runs = board.runs()
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.length, 4)
        XCTAssertEqual(runs.first?.cells.last, Pos(5, 0))
    }

    func testRandomBoardsHaveNoRunsButAMove() {
        for seed in 0..<50 {
            var rng = SplitMix64(seed: UInt64(seed))
            let board = Board.random(cols: 8, rows: 8, using: &rng)
            XCTAssertTrue(board.isFull)
            XCTAssertTrue(board.runs().isEmpty, "Seed \(seed) startet mit fertiger Reihe")
            XCTAssertTrue(board.hasValidMove, "Seed \(seed) hat keinen Zug")
        }
    }

    func testValidMoveDetection() {
        let board = Board([
            "KSU",
            "ZNK",
            "ZUR",
            "RRN",
        ])
        XCTAssertTrue(board.isValidMove(Pos(2, 2), Pos(2, 3)))
        XCTAssertTrue(board.isValidMove(Pos(2, 3), Pos(2, 2)))
        XCTAssertFalse(board.isValidMove(Pos(0, 0), Pos(1, 0)), "Tausch ohne Reihe")
        XCTAssertFalse(board.isValidMove(Pos(0, 0), Pos(2, 0)), "Nicht benachbart")
        XCTAssertFalse(board.isValidMove(Pos(2, 3), Pos(3, 3)), "Außerhalb des Bretts")
        XCTAssertTrue(board.validMoves().contains(Move(Pos(2, 2), Pos(2, 3))))
    }

    func testLinesRoundTrip() {
        let lines = ["KSU", "ZNK", "Z.R"]
        XCTAssertEqual(Board(lines).lines, lines)
    }
}
