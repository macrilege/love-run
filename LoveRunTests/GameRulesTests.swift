import XCTest
@testable import LoveRun

final class GameRulesTests: XCTestCase {
    func testCampaignHasSixDistinctWorldsAndTwelvePuppies() {
        XCTAssertEqual(LevelDefinition.all.count, 6)
        XCTAssertEqual(Set(LevelDefinition.all.flatMap(\.puppies).map(\.name)).count, 12)
        XCTAssertEqual(Set(LevelDefinition.all.flatMap(\.puppies).map(\.frame)).count, 12)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.backgroundAsset)).count, 6)
        for level in LevelDefinition.all {
            XCTAssertGreaterThanOrEqual(level.platforms.count, 8)
            XCTAssertGreaterThanOrEqual(level.hazards.count, 4)
            XCTAssertGreaterThanOrEqual(level.pickups.count, 22)
            XCTAssertEqual(level.puppies.count, 2)
            XCTAssertTrue(level.puppies.allSatisfy { $0.position.x < level.worldWidth })
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
