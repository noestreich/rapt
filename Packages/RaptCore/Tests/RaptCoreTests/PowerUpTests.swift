import XCTest
@testable import RaptCore

final class PowerUpTests: XCTestCase {
    private let board4 = Board([
        "KSUO",
        "ZNKR",
        "ZURS",
        "RRNK",
    ])

    func testPlansWalkTheRoofsAndFillStorage() {
        var game = Game(seed: 7)
        // Plan 2, 3, 4 und 5 auf einmal: Bombe, Farbtilger, Bombe, dann Fresser auf dem letzten Dach
        let rewards = game.award(points: Game.planThreshold(5))
        XCTAssertEqual(rewards.map(\.plan), [2, 3, 4, 5])
        XCTAssertEqual(rewards.map(\.roof), [1, 2, 3, 4])
        XCTAssertEqual(game.powerUps, [.bombe, .farbtilger, .bombe])
        // Lager voll: statt Fresser gibt es Bonuspunkte
        let last = rewards[3]
        XCTAssertTrue(last.reachedTop)
        XCTAssertNil(last.powerUp)
        XCTAssertEqual(last.bonusPoints, Game.fullStorageBonus)
        XCTAssertEqual(game.score, Game.planThreshold(5) + Game.fullStorageBonus)
        XCTAssertEqual(game.roof, 0, "Nach dem letzten Dach beginnt die Figur wieder vorne")
    }

    func testTopRoofGrantsFresserWhenThereIsRoom() {
        var game = Game(seed: 7)
        _ = game.award(points: Game.planThreshold(4))
        XCTAssertEqual(game.powerUps, [.bombe, .farbtilger, .bombe])
        XCTAssertTrue(game.useBomb(at: Pos(3, 3)).isValid)
        XCTAssertEqual(game.powerUps.count, 2)
        let rewards = game.award(points: max(0, Game.planThreshold(5) - game.score))
        XCTAssertEqual(rewards.last?.powerUp, .fresser)
        XCTAssertTrue(game.powerUps.contains(.fresser))
    }

    func testBombClearsThreeByThree() throws {
        var game = Game(seed: 3)
        _ = game.award(points: Game.planThreshold(2))
        XCTAssertEqual(game.powerUps, [.bombe])
        let middle = game.useBomb(at: Pos(4, 4))
        let first = try XCTUnwrap(middle.steps.first)
        XCTAssertEqual(first.cleared.count, 9)
        XCTAssertTrue(first.runs.isEmpty)
        XCTAssertEqual(first.points, 9 * Game.pointsPerGem)
        XCTAssertFalse(game.powerUps.contains(.bombe))
        XCTAssertTrue(game.board.isFull)
        XCTAssertTrue(game.board.runs().isEmpty)
        XCTAssertFalse(game.useBomb(at: Pos(0, 0)).isValid, "Keine Bombe mehr im Lager")
    }

    func testBombAtCornerClearsFour() throws {
        var game = Game(board: board4, seed: 1)
        _ = game.award(points: Game.planThreshold(2))
        let result = game.useBomb(at: Pos(0, 0))
        XCTAssertEqual(try XCTUnwrap(result.steps.first).cleared.count, 4)
    }

    func testPurgeRemovesEveryGemOfOneColor() throws {
        var game = Game(seed: 11)
        _ = game.award(points: Game.planThreshold(3))
        let color = try XCTUnwrap(game.board[Pos(0, 0)])
        let count = game.board.positions.filter { game.board[$0] == color }.count
        let result = game.usePurge(color)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.cleared.count, count)
        XCTAssertFalse(game.powerUps.contains(.farbtilger))
    }

    func testFresserPetrifiesTwoColorsAndIgnoresEatenStones() throws {
        var game = Game(seed: 5)
        _ = game.award(points: Game.planThreshold(3))
        XCTAssertNil(game.startFresser(), "Ohne Fresser im Lager startet keine Runde")
        _ = game.useBomb(at: Pos(1, 1))
        _ = game.award(points: Game.planThreshold(5) - game.score)
        let round = try XCTUnwrap(game.startFresser())
        XCTAssertEqual(round.stones.count, 2)
        let startGem = try XCTUnwrap(game.board[round.start])
        XCTAssertFalse(round.stones.contains(startGem))

        let stone = try XCTUnwrap(game.board.positions.first { game.board[$0].map(round.stones.contains) ?? false })
        let result = game.finishFresser(round, eaten: [round.start, stone])
        XCTAssertEqual(try XCTUnwrap(result.steps.first).cleared, [round.start])
        XCTAssertFalse(game.powerUps.contains(.fresser))
    }

    func testGameIsOnlyOverWithoutMovesAndPowerUps() {
        // 2×2 kann nie eine Dreierreihe bilden
        var game = Game(board: Board(["OZ", "SU"]), seed: 1)
        XCTAssertTrue(game.isOver)
        _ = game.award(points: Game.planThreshold(2))
        XCTAssertFalse(game.isOver, "Mit Bombe im Lager geht es weiter")
        let result = game.useBomb(at: Pos(0, 0))
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.isGameOver)
        XCTAssertTrue(game.isOver)
    }
}
