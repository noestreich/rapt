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
        let top = Game.roofCount - 1
        let rewards = game.award(points: Game.planThreshold(top + 1))
        XCTAssertEqual(rewards.map(\.plan), Array(2...(top + 1)))
        XCTAssertEqual(rewards.map(\.roof), Array(1...top))
        XCTAssertEqual(game.powerUps.count, Game.maxPowerUps)
        XCTAssertEqual(game.powerUps, rewards.compactMap(\.powerUp))
        let overflow = rewards.count - Game.maxPowerUps
        XCTAssertTrue(rewards.suffix(overflow).allSatisfy { $0.powerUp == nil && $0.bonusPoints == Game.fullStorageBonus })
        XCTAssertTrue(rewards.last!.reachedTop)
        XCTAssertEqual(game.score, Game.planThreshold(top + 1) + overflow * Game.fullStorageBonus)
        XCTAssertEqual(game.roof, 0, "Nach dem Zyklus beginnt er von vorn")
    }

    func testRewardsAreMixedAndNeverRepeatDirectly() {
        var kinds: [PowerUp] = []
        for seed in 0..<40 {
            var game = Game(seed: UInt64(seed))
            var previous: PowerUp?
            for n in 2...6 {
                // Lager leeren, damit jede Belohnung ankommt
                game.clearPowerUps()
                let rewards = game.award(points: max(0, Game.planThreshold(n) - game.score))
                for reward in rewards {
                    guard let kind = reward.powerUp else { continue }
                    XCTAssertNotEqual(kind, previous, "Seed \(seed): zweimal hintereinander \(kind)")
                    previous = kind
                    kinds.append(kind)
                }
            }
        }
        XCTAssertEqual(Set(kinds), Set(PowerUp.allCases), "Alle Power-ups kommen vor")
        XCTAssertNotEqual(Array(kinds.prefix(4)), Array(kinds.dropFirst(5).prefix(4)), "Keine feste Reihenfolge")
    }

    func testTopOfCycleBringsRarePowerUp() {
        for seed in 0..<20 {
            var game = Game(seed: UInt64(seed))
            _ = game.award(points: Game.planThreshold(Game.roofCount - 1))
            game.clearPowerUps()
            let rewards = game.award(points: max(0, Game.planThreshold(Game.roofCount) - game.score))
            let top = rewards.first { $0.reachedTop }
            XCTAssertNotNil(top)
            XCTAssertTrue([PowerUp.fresser, .atom].contains(top!.powerUp!))
        }
    }

    func testBombClearsThreeByThree() throws {
        var game = Game(seed: 3)
        game.grant(.bombe)
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
        game.grant(.bombe)
        let result = game.useBomb(at: Pos(0, 0))
        XCTAssertEqual(try XCTUnwrap(result.steps.first).cleared.count, 4)
    }

    func testAtomClearsFiveByFive() throws {
        var game = Game(seed: 9)
        game.grant(.atom)
        let result = game.useAtom(at: Pos(4, 4))
        XCTAssertEqual(try XCTUnwrap(result.steps.first).cleared.count, 25)
    }

    func testPurgeRemovesEveryGemOfOneColor() throws {
        var game = Game(seed: 11)
        game.grant(.farbtilger)
        let color = try XCTUnwrap(game.board.color(at: Pos(0, 0)))
        let count = game.board.positions.filter { game.board.color(at: $0) == color }.count
        let result = game.usePurge(color)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.cleared.count, count)
        XCTAssertFalse(game.powerUps.contains(.farbtilger))
    }

    func testShuffleKeepsGemsAndLeavesAMove() {
        var game = Game(seed: 4)
        game.grant(.strudel)
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
        XCTAssertNil(game.startFresser(), "Ohne Fresser im Lager startet keine Runde")
        game.grant(.fresser)
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
        game.grant(.bombe)
        XCTAssertFalse(game.isOver, "Mit Bombe im Lager geht es weiter")
        let result = game.useBomb(at: Pos(0, 0))
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.isGameOver)
        XCTAssertTrue(game.isOver)
    }
}

