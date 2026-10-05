import XCTest
@testable import RaptCore

final class GameTests: XCTestCase {
    private let smallBoard = Board([
        "KSU",
        "ZNK",
        "ZUR",
        "RRN",
    ])

    func testInvalidSwapLeavesBoardUntouched() {
        var game = Game(board: smallBoard, seed: 1)
        let result = game.swap(Pos(0, 0), Pos(1, 0))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(game.board, smallBoard)
        XCTAssertEqual(game.score, 0)
    }

    func testSwapClearsRunAndAppliesGravity() throws {
        var game = Game(board: smallBoard, seed: 1)
        let result = game.swap(Pos(2, 2), Pos(2, 3))
        XCTAssertTrue(result.isValid)

        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.combo, 1)
        XCTAssertEqual(Set(first.cleared), Set([Pos(0, 3), Pos(1, 3), Pos(2, 3)]))
        XCTAssertEqual(first.points, 150)
        XCTAssertEqual(first.falls.count, 9)
        XCTAssertEqual(first.spawns.count, 3)
        XCTAssertTrue(first.falls.contains(Fall(gem: .zahnrad, from: Pos(0, 2), to: Pos(0, 3))))
        XCTAssertTrue(first.falls.contains(Fall(gem: .niete, from: Pos(2, 2), to: Pos(2, 3))))
        XCTAssertTrue(first.spawns.allSatisfy { $0.from.row == -1 && $0.to.row == 0 })

        XCTAssertTrue(game.board.isFull)
        XCTAssertTrue(game.board.runs().isEmpty)
        XCTAssertEqual(game.score, result.points)
    }

    func testLongRunsAndCombosScoreMore() {
        let three = Run(gem: .orden, cells: [Pos(0, 0), Pos(1, 0), Pos(2, 0)], isHorizontal: true)
        let four = Run(gem: .orden, cells: [Pos(0, 0), Pos(1, 0), Pos(2, 0), Pos(3, 0)], isHorizontal: true)
        XCTAssertEqual(Game.points(for: [three], combo: 1), 150)
        XCTAssertEqual(Game.points(for: [four], combo: 1), 300)
        XCTAssertEqual(Game.points(for: [three], combo: 3), 450)
    }

    func testRandomPlayKeepsBoardConsistent() {
        for seed in 0..<20 {
            var game = Game(seed: UInt64(seed))
            var moves = 0
            while let move = game.hint(), moves < 60 {
                let result = game.swap(move.a, move.b)
                XCTAssertTrue(result.isValid)
                XCTAssertFalse(result.steps.isEmpty)
                for (i, step) in result.steps.enumerated() {
                    XCTAssertEqual(step.combo, i + 1)
                    let spawnsPerCol = Dictionary(grouping: step.spawns, by: \.to.col).mapValues(\.count)
                    let clearedPerCol = Dictionary(grouping: step.cleared, by: \.col).mapValues(\.count)
                    XCTAssertEqual(spawnsPerCol, clearedPerCol)
                }
                XCTAssertTrue(game.board.isFull)
                XCTAssertTrue(game.board.runs().isEmpty)
                XCTAssertEqual(game.isOver, !game.board.hasValidMove)
                moves += 1
            }
        }
    }

    func testSameSeedPlaysTheSameGame() {
        var a = Game(seed: 42)
        var b = Game(seed: 42)
        XCTAssertEqual(a.board, b.board)
        for _ in 0..<10 {
            guard let move = a.hint() else { break }
            let ra = a.swap(move.a, move.b)
            let rb = b.swap(move.a, move.b)
            XCTAssertEqual(ra, rb)
        }
        XCTAssertEqual(a.board, b.board)
        XCTAssertEqual(a.score, b.score)
    }

    func testPlanThresholds() {
        XCTAssertEqual(Game.planThreshold(1), 0)
        XCTAssertEqual(Game.planThreshold(2), 1500)
        XCTAssertEqual(Game.planThreshold(3), 4500)
    }
}
