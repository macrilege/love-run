import XCTest
@testable import LoveRun

final class GameRulesTests: XCTestCase {
    func testCampaignHasSixDistinctWorldsAndTwelvePuppies() {
        XCTAssertEqual(LevelDefinition.all.count, 6)
        XCTAssertEqual(Set(LevelDefinition.all.flatMap(\.puppies).map(\.name)).count, 12)
        XCTAssertEqual(Set(LevelDefinition.all.flatMap(\.puppies).map(\.frame)).count, 12)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.backgroundAsset)).count, 6)
        for level in LevelDefinition.all {
            XCTAssertGreaterThanOrEqual(level.worldWidth, 7_200)
            XCTAssertGreaterThanOrEqual(level.platforms.count, 20)
            XCTAssertGreaterThanOrEqual(level.hazards.count, 12)
            XCTAssertGreaterThanOrEqual(level.pickups.count, 45)
            XCTAssertEqual(level.checkpoints.count, 2)
            XCTAssertEqual(level.puppies.count, 2)
            XCTAssertTrue(level.puppies.allSatisfy { $0.position.x < level.worldWidth })
            XCTAssertGreaterThan(level.puppies[0].position.x, 3_900)
            XCTAssertEqual(level.puppies.map(\.requiredSeals), [1, 3])
            XCTAssertGreaterThanOrEqual((level.puppies[0].position.x - 125) / 265, 14.5)
            let platformGaps = zip(level.platforms, level.platforms.dropFirst()).map { $1.rect.minX - $0.rect.minX }
            XCTAssertLessThanOrEqual(platformGaps.max() ?? 0, 360)
            let sealPositions = level.pickups.filter { $0.style == .letter }.map(\.position.x)
            XCTAssertEqual(sealPositions.count, 3)
            XCTAssertGreaterThanOrEqual(sealPositions.filter { $0 < level.puppies[0].position.x }.count, 1)
            XCTAssertTrue(sealPositions.allSatisfy { $0 < level.puppies[1].position.x })
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
