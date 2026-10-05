import XCTest
@testable import RaptCore

final class PowerUpTests: XCTestCase {
    private let board4 = Board([
        "KSUO",
        "ZNKR",
        "ZURS",
        "RRNK",
    ])

    /// Setzt alle Power-ups im Lager ein, damit wieder Platz ist.
    private func emptyStorage(_ game: inout Game) {
        while let kind = game.powerUps.first {
            switch kind {
            case .bombe: _ = game.useBomb(at: Pos(4, 4))
            case .atom: _ = game.useAtom(at: Pos(4, 4))
            case .farbtilger: _ = game.usePurge(game.board.color(at: Pos(0, 0)) ?? .orden)
            case .strudel: _ = game.useShuffle()
            case .fresser:
                guard let round = game.startFresser() else { return }
                _ = game.finishFresser(round, eaten: [round.start])
            }
        }
    }

    func testPlansWalkTheRoofsAndFillStorage() {
        var game = Game(seed: 7)
        let top = Game.roofCount - 1
        let rewards = game.award(points: Game.planThreshold(top + 1))
        XCTAssertEqual(rewards.map(\.plan), Array(2...(top + 1)))
        XCTAssertEqual(rewards.map(\.roof), Array(1...top))
        XCTAssertEqual(game.powerUps, Array(Game.roofRewards.prefix(Game.maxPowerUps)))
        let overflow = rewards.count - Game.maxPowerUps
        XCTAssertTrue(rewards.suffix(overflow).allSatisfy { $0.powerUp == nil && $0.bonusPoints == Game.fullStorageBonus })
        XCTAssertTrue(rewards.last!.reachedTop)
        XCTAssertEqual(game.score, Game.planThreshold(top + 1) + overflow * Game.fullStorageBonus)
        XCTAssertEqual(game.roof, 0, "Nach dem letzten Dach beginnt die Figur wieder vorne")
    }

    func testTopRoofGrantsFresserWhenThereIsRoom() {
        var game = Game(seed: 7)
        _ = game.award(points: Game.planThreshold(Game.roofCount - 1))
        emptyStorage(&game)
        let rewards = game.award(points: max(0, Game.planThreshold(Game.roofCount) - game.score))
        XCTAssertTrue(rewards.contains { $0.reachedTop && $0.powerUp == .fresser })
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

    func testAtomClearsFiveByFive() throws {
        var game = Game(seed: 9)
        let atomRoof = try XCTUnwrap(Game.roofRewards.firstIndex(of: .atom)) + 1
        _ = game.award(points: Game.planThreshold(atomRoof))
        emptyStorage(&game)
        _ = game.award(points: max(0, Game.planThreshold(atomRoof + 1) - game.score))
        XCTAssertTrue(game.powerUps.contains(.atom))
        let result = game.useAtom(at: Pos(4, 4))
        XCTAssertEqual(try XCTUnwrap(result.steps.first).cleared.count, 25)
    }

    func testPurgeRemovesEveryGemOfOneColor() throws {
        var game = Game(seed: 11)
        _ = game.award(points: Game.planThreshold(3))
        let color = try XCTUnwrap(game.board.color(at: Pos(0, 0)))
        let count = game.board.positions.filter { game.board.color(at: $0) == color }.count
        let result = game.usePurge(color)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.cleared.count, count)
        XCTAssertFalse(game.powerUps.contains(.farbtilger))
    }

    func testShuffleKeepsGemsAndLeavesAMove() {
        var game = Game(seed: 4)
        _ = game.award(points: Game.planThreshold(4))
        XCTAssertTrue(game.powerUps.contains(.strudel))
        let before = game.board
        let result = game.useShuffle()
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(game.powerUps.contains(.strudel))
        XCTAssertTrue(game.board.runs().isEmpty)
        XCTAssertTrue(game.board.hasValidMove)
        if !result.replacedBoard {
            XCTAssertEqual(result.moves.count, 64)
            for (from, to) in result.moves {
                XCTAssertEqual(before[tile: from], game.board[tile: to])
            }
        }
    }

    func testFresserPetrifiesTwoColorsAndIgnoresEatenStones() throws {
        var game = Game(seed: 5)
        _ = game.award(points: Game.planThreshold(3))
        XCTAssertNil(game.startFresser(), "Ohne Fresser im Lager startet keine Runde")
        _ = game.award(points: Game.planThreshold(Game.roofCount - 1) - game.score)
        emptyStorage(&game)
        _ = game.award(points: max(0, Game.planThreshold(Game.roofCount) - game.score))
        let round = try XCTUnwrap(game.startFresser())
        XCTAssertEqual(round.stones.count, 2)
        let startGem = try XCTUnwrap(game.board[round.start])
        XCTAssertFalse(round.stones.contains(startGem))

        let stone = try XCTUnwrap(game.board.positions.first { game.board.color(at: $0).map(round.stones.contains) ?? false })
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
