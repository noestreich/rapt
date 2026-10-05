import XCTest
@testable import RaptCore

final class CityTests: XCTestCase {
    func testSameSeedBuildsSameCity() {
        XCTAssertEqual(City(seed: 9).buildings, City(seed: 9).buildings)
        XCTAssertNotEqual(City(seed: 9).buildings, City(seed: 10).buildings)
    }

    func testCityCoversTheViewAndFigureStartsRightOfCenter() {
        let city = City(seed: 1)
        XCTAssertGreaterThan(city.buildings.last!.right, City.viewWidth)
        XCTAssertGreaterThan(city.figureX, City.viewWidth / 2)
        XCTAssertFalse(city.isInDanger)
        for (a, b) in zip(city.buildings, city.buildings.dropFirst()) {
            XCTAssertGreaterThan(b.x, a.right, "Häuser überlappen nicht")
        }
    }

    func testCityScrollsAndGrows() {
        var city = City(seed: 2)
        let start = city.figureX
        let count = city.buildings.count
        city.advance(by: 100, plan: 1)
        XCTAssertEqual(city.figureX, start - City.baseSpeed * 100, accuracy: 0.0001)
        XCTAssertGreaterThan(city.buildings.count, count)
        XCTAssertGreaterThan(city.buildings.last!.right, city.offset + City.viewWidth)
    }

    func testJumpMovesFigureToNextBuilding() {
        var city = City(seed: 3)
        let before = city.figureX
        let index = city.jump()
        XCTAssertEqual(index, city.figureIndex)
        XCTAssertGreaterThan(city.figureX, before)
    }

    func testFigureIsLostWhenPushedOut() {
        var game = Game(seed: 4)
        var fell = false
        for _ in 0..<2000 where !fell {
            fell = game.tick(1)
        }
        XCTAssertTrue(fell)
        XCTAssertTrue(game.hasFallen)
        XCTAssertTrue(game.isOver)
        XCTAssertLessThan(game.city.figureX, 0)
        XCTAssertFalse(game.tick(1), "Nur einmal abstürzen")
    }

    func testPlanRewardsMoveTheFigure() {
        var game = Game(seed: 5)
        let start = game.city.figureIndex
        let rewards = game.award(points: Game.planThreshold(3))
        XCTAssertEqual(rewards.map(\.building), [start + 1, start + 2])
        XCTAssertEqual(game.city.figureIndex, start + 2)
    }

    func testEndlessModeHasNoCityPressureAndNoPowerUps() {
        var game = Game(seed: 6, mode: .endless)
        let start = game.city.figureX
        XCTAssertFalse(game.tick(100_000))
        XCTAssertEqual(game.city.figureX, start)
        XCTAssertFalse(game.isOver)
        let rewards = game.award(points: Game.planThreshold(4))
        XCTAssertEqual(rewards.map(\.plan), [2, 3, 4])
        XCTAssertTrue(rewards.allSatisfy { $0.powerUp == nil && $0.building == nil })
        XCTAssertTrue(game.powerUps.isEmpty)
    }

    func testAccelerationGrowsWithPlayTime() {
        var city = City(seed: 8)
        let start = city.currentSpeed(plan: 1, base: 1, accelerationPerMinute: 0.2)
        city.advance(by: 120, plan: 1, base: 1, accelerationPerMinute: 0.2)
        XCTAssertEqual(start, 1, accuracy: 0.0001)
        XCTAssertEqual(city.currentSpeed(plan: 1, base: 1, accelerationPerMinute: 0.2), 1.4, accuracy: 0.0001)
    }

    func testSpeedGrowsWithPlan() {
        XCTAssertGreaterThan(City.speed(plan: 5), City.speed(plan: 1))
    }
}
