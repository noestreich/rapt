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
            XCTAssertTrue(Game.topRewards.contains(top!.powerUp!))
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

    func testArcadeRoundsClearHitCellsAndCascade() throws {
        var game = Game(seed: 9)
        XCTAssertFalse(game.startArcade(.invasion), "Ohne Power-up im Lager startet kein Minispiel")
        XCTAssertFalse(game.startArcade(.bombe), "Nur Minispiele lassen sich so starten")
        game.grant(.invasion)
        XCTAssertTrue(game.startArcade(.invasion))
        XCTAssertFalse(game.powerUps.contains(.invasion))

        let hits: Set<Pos> = [Pos(0, 7), Pos(1, 7), Pos(2, 6), Pos(99, 99)]
        let result = game.finishArcade(cleared: hits)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(Set(try XCTUnwrap(result.steps.first).cleared), [Pos(0, 7), Pos(1, 7), Pos(2, 6)])
        XCTAssertTrue(game.board.positions.allSatisfy { game.board[$0] != nil }, "Brett ist danach wieder voll")

        game.grant(.abriss)
        XCTAssertTrue(game.startArcade(.abriss))
        let empty = game.finishArcade(cleared: [])
        XCTAssertTrue(empty.isValid)
        XCTAssertTrue(empty.steps.isEmpty)
    }

    func testStarRunEveryTenthJumpAndRareRewardFromEightyPercent() {
        XCTAssertFalse(Game.isStarRunJump(plan: 1))
        XCTAssertFalse(Game.isStarRunJump(plan: 10), "Plan 10 ist der 9. Sprung")
        XCTAssertTrue(Game.isStarRunJump(plan: 11))
        XCTAssertTrue(Game.isStarRunJump(plan: 21))
        XCTAssertFalse(Game.isStarRunJump(plan: 22))

        var game = Game(seed: 4)
        // Plan 1: ein Sprung sind 1500 Punkte, alle Münzen zusammen höchstens die Hälfte
        XCTAssertEqual(game.starRunPoints(collected: 10, total: 10), 750)
        let few = game.finishStarRun(collected: 6, total: 10)
        XCTAssertNil(few.powerUp, "Unter 80 %: nur Punkte")
        XCTAssertEqual(few.points, 450)
        XCTAssertEqual(game.score, 450)
        XCTAssertTrue(few.result.isValid)
        XCTAssertTrue(few.result.steps.isEmpty)

        let many = game.finishStarRun(collected: 8, total: 10)
        XCTAssertEqual(many.points, 600)
        XCTAssertTrue(many.result.rewards.isEmpty, "1050 Punkte reichen noch nicht für den nächsten Sprung")
        let rare = many.powerUp
        XCTAssertNotNil(rare)
        if let rare {
            XCTAssertTrue(Game.topRewards.contains(rare))
            XCTAssertEqual(game.powerUps, [rare])
        }
        XCTAssertEqual(game.score, 1050)

        let none = game.finishStarRun(collected: 0, total: 0)
        XCTAssertNil(none.powerUp, "Ohne Münzen kein Bonus")
        XCTAssertEqual(none.points, 0)

        // Endlos hat kein Lager: nur Punkte, kein seltenes Power-up
        var endless = Game(seed: 5, mode: .endless)
        let calm = endless.finishStarRun(collected: 10, total: 10)
        XCTAssertNil(calm.powerUp)
        XCTAssertTrue(endless.powerUps.isEmpty)
        XCTAssertEqual(calm.points, 750)

        // Eine volle Fahrt bringt nie mehr als einen Sprung
        var late = Game(seed: 6)
        _ = late.award(points: Game.planThreshold(11))
        let plan = late.plan
        let full = late.finishStarRun(collected: 30, total: 30)
        XCTAssertLessThanOrEqual(full.result.rewards.count, 1)
        XCTAssertLessThanOrEqual(late.plan, plan + 1)
    }

    func testStarRunTriggersOnFourCrystalsInARow() {
        func result(_ runs: [Run]) -> SwapResult {
            let step = CascadeStep(runs: runs, cleared: runs.flatMap(\.cells), falls: [], spawns: [], combo: 1, points: 0,
                                   created: [], detonations: [])
            return SwapResult(isValid: true, steps: [step], rewards: [], isGameOver: false)
        }
        let four = Run(gem: .kristall, cells: (0..<4).map { Pos($0, 2) }, isHorizontal: true)
        let three = Run(gem: .kristall, cells: (0..<3).map { Pos($0, 2) }, isHorizontal: true)
        let otherFour = Run(gem: .orden, cells: (0..<4).map { Pos(1, $0) }, isHorizontal: false)
        XCTAssertTrue(Game.hasStarRunTrigger(result([four])))
        XCTAssertFalse(Game.hasStarRunTrigger(result([three])), "Drei Kristalle reichen nicht")
        XCTAssertFalse(Game.hasStarRunTrigger(result([otherFour])), "Nur Kristalle")
        XCTAssertFalse(Game.hasStarRunTrigger(.invalid))
    }

    func testDebugAdvanceJumpsSeveralPlansAtOnce() {
        var game = Game(seed: 3)
        let result = game.debugAdvance(plans: 3)
        XCTAssertEqual(game.plan, 4)
        XCTAssertEqual(result.rewards.map(\.plan), [2, 3, 4])
        XCTAssertTrue(result.steps.isEmpty)
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

