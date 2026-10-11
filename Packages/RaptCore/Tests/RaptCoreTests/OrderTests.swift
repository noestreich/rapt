import XCTest
@testable import RaptCore

final class OrderTests: XCTestCase {
    func testFirstOrderIsAColorAndOrdersAreFixedPerSeed() {
        for seed in 0..<30 {
            let first = Order.make(plan: 1, seed: UInt64(seed))
            guard case .clear = first.kind else { return XCTFail("Plan 1: immer eine Farbe") }
            XCTAssertEqual(first.target, 15)
            XCTAssertEqual(first.bonus, Game.pointsPerPlanStep / 4)
            XCTAssertEqual(Order.make(plan: 5, seed: UInt64(seed)), Order.make(plan: 5, seed: UInt64(seed)))
        }
        let kinds = Set((0..<200).map { seed -> String in
            switch Order.make(plan: 4, seed: UInt64(seed)).kind {
            case .clear: return "clear"
            case .build: return "build"
            case .ignite: return "ignite"
            case .cascade: return "cascade"
            }
        })
        XCTAssertEqual(kinds, ["clear", "build", "ignite", "cascade"])
    }

    func testRecordCountsAndCaps() {
        var colors = Order(kind: .clear(.orden), target: 5, plan: 2)
        colors.record(cleared: [.orden: 3, .niete: 9], created: 0, detonated: 0, combo: 1)
        XCTAssertEqual(colors.progress, 3)
        colors.record(cleared: [.orden: 4], created: 0, detonated: 0, combo: 1)
        XCTAssertEqual(colors.progress, 5)
        XCTAssertTrue(colors.isDone)

        var cascade = Order(kind: .cascade, target: 3, plan: 2)
        cascade.record(cleared: [:], created: 0, detonated: 0, combo: 2)
        cascade.record(cleared: [:], created: 0, detonated: 0, combo: 1)
        XCTAssertEqual(cascade.progress, 2)
        cascade.record(cleared: [:], created: 0, detonated: 0, combo: 3)
        XCTAssertTrue(cascade.isDone)
    }

    func testCompletedOrderPaysBonusOnceAndNextPlanBringsANewOne() throws {
        let board = Board(Array(repeating: "OOOOOOOO", count: 8))
        var found: Game?
        for seed in 0..<400 {
            let game = Game(board: board, seed: UInt64(seed))
            if game.order?.kind == .clear(.orden) {
                found = game
                break
            }
        }
        var game = try XCTUnwrap(found, "Ein Seed mit Orden-Auftrag")
        game.grant(.atom)
        let result = game.useAtom(at: Pos(4, 4))
        let done = try XCTUnwrap(result.completedOrder)
        XCTAssertEqual(done.kind, .clear(.orden))
        XCTAssertEqual(game.score, result.points + done.bonus + result.rewards.map(\.bonusPoints).reduce(0, +))
        if game.plan > 1 {
            XCTAssertEqual(game.order?.plan, game.plan, "Neuer Sprung, neuer Auftrag")
        } else {
            XCTAssertNil(game.order, "Bis zum nächsten Sprung kein neuer Auftrag")
        }

        // Gespeichert und geladen bleibt der Auftrag erhalten
        let restored = try XCTUnwrap(Game(snapshot: game.snapshot))
        XCTAssertEqual(restored.order, game.order)
    }
}
