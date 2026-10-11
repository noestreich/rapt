import Foundation
import XCTest
@testable import RaptCore

final class SnapshotTests: XCTestCase {
    func testSnapshotRoundTripContinuesIdentically() throws {
        var game = Game(seed: 21)
        _ = game.award(points: Game.planThreshold(3) + 400)
        _ = game.tick(42)
        let move = try XCTUnwrap(game.hint())
        let snapshot = game.snapshot
        let data = try JSONEncoder().encode(snapshot)
        var restored = try XCTUnwrap(Game(snapshot: try JSONDecoder().decode(GameSnapshot.self, from: data)))

        XCTAssertEqual(restored.board, game.board)
        XCTAssertEqual(restored.score, game.score)
        XCTAssertEqual(restored.powerUps, game.powerUps)
        XCTAssertEqual(restored.plan, game.plan)
        XCTAssertEqual(restored.city.offset, game.city.offset)
        XCTAssertEqual(restored.city.figureIndex, game.city.figureIndex)
        XCTAssertEqual(restored.city.buildings, game.city.buildings)
        XCTAssertEqual(restored.snapshot, snapshot)

        // Gleicher Zug, gleiche Zufallssteine, gleiche Belohnungen
        let a = game.swap(move.a, move.b)
        let b = restored.swap(move.a, move.b)
        XCTAssertEqual(a, b)
        XCTAssertEqual(restored.board, game.board)
        _ = game.award(points: Game.planThreshold(6))
        _ = restored.award(points: Game.planThreshold(6))
        XCTAssertEqual(restored.powerUps, game.powerUps)
        _ = game.tick(30)
        _ = restored.tick(30)
        XCTAssertEqual(restored.city.buildings, game.city.buildings)
    }

    func testSnapshotKeepsSpecialsAndRejectsBrokenData() throws {
        let board = Board(["OZS", "SUK", "ZNO"], specials: [Pos(0, 0): .line(horizontal: false), Pos(1, 1): .hyper, Pos(2, 2): .bomb])
        var game = Game(board: board, seed: 2)
        game.grant(.bombe)
        let restored = try XCTUnwrap(Game(snapshot: game.snapshot))
        XCTAssertEqual(restored.board, board)
        XCTAssertEqual(restored.powerUps, [.bombe])

        var broken = game.snapshot
        broken = GameSnapshot(mode: "weltraum", lines: broken.lines, specials: broken.specials, score: 0, powerUps: [],
                              roof: 0, lastReward: nil, rewardedPlan: 1, rng: 1, city: broken.city)
        XCTAssertNil(Game(snapshot: broken), "Unbekannter Modus")
        let over = Game(board: Board(["OZ", "SU"]), seed: 1)
        XCTAssertNil(Game(snapshot: over.snapshot), "Vorbei ist vorbei")
    }
}
