import XCTest
@testable import LoveRun

final class GameRulesTests: XCTestCase {
    func testCampaignHasThreeDistinctPuppyLevels() {
        XCTAssertEqual(LevelDefinition.all.count, 3)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.puppyName)).count, 3)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.backgroundAsset)).count, 3)
        for level in LevelDefinition.all {
            XCTAssertGreaterThanOrEqual(level.platforms.count, 8)
            XCTAssertGreaterThanOrEqual(level.hazards.count, 4)
            XCTAssertGreaterThanOrEqual(level.pickups.count, 22)
            XCTAssertLessThan(level.puppyPosition.x, level.worldWidth)
        }
    }

    func testSmileProgressionMatchesHeartMilestones() {
        XCTAssertEqual(GameRules.smileLevel(for: 0), -1)
        XCTAssertEqual(GameRules.smileLevel(for: 1), 0)
        XCTAssertEqual(GameRules.smileLevel(for: 4), 1)
        XCTAssertEqual(GameRules.smileLevel(for: 16), 5)
        XCTAssertEqual(GameRules.smileLevel(for: 100), 5)
    }

    func testDifficultySpeedsUpButStaysPlayable() {
        XCTAssertEqual(GameRules.spawnInterval(for: 0), 2.0)
        XCTAssertLessThan(GameRules.spawnInterval(for: 10), 2.0)
        XCTAssertEqual(GameRules.spawnInterval(for: 100), 0.85)
    }
}
