import XCTest
@testable import LoveRun

final class GameRulesTests: XCTestCase {
    func testVerticalSliceHasThreeDistinctRescueMissions() {
        XCTAssertEqual(LevelDefinition.all.count, 3)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.title)).count, 3)
        XCTAssertEqual(Set(LevelDefinition.all.map(\.puppy.name)).count, 3)

        for mission in LevelDefinition.all {
            XCTAssertGreaterThan(mission.worldWidth, 5_000)
            XCTAssertGreaterThan(mission.puppy.position.x, 3_000)
            XCTAssertGreaterThan(mission.exitX, mission.puppy.position.x + 1_500)
            XCTAssertLessThan(mission.exitX, mission.worldWidth)
            XCTAssertGreaterThanOrEqual(mission.platforms.count, 14)
            XCTAssertGreaterThanOrEqual(mission.hazards.count, 12)
            XCTAssertGreaterThanOrEqual(mission.hazards.filter { $0.rect.minX > mission.puppy.position.x }.count, 3)

            let letters = mission.pickups.filter { $0.style == .letter }
            XCTAssertEqual(letters.count, 3)
            XCTAssertTrue(letters.allSatisfy { $0.position.x < mission.puppy.position.x })
        }
    }

    func testLaterMissionsAddMovingAndCrumblingSurfaces() {
        XCTAssertFalse(LevelDefinition.all[0].platforms.contains { $0.behavior != .fixed })
        XCTAssertTrue(LevelDefinition.all[1].platforms.contains { $0.behavior == .moving })
        XCTAssertTrue(LevelDefinition.all[2].platforms.contains { $0.behavior == .crumbling })
    }

    func testMissionCrownsRewardCompletionLettersAndFlawlessPlay() {
        XCTAssertEqual(GameRules.crowns(letters: 0, totalLetters: 3, damageTaken: 2), 1)
        XCTAssertEqual(GameRules.crowns(letters: 3, totalLetters: 3, damageTaken: 1), 2)
        XCTAssertEqual(GameRules.crowns(letters: 3, totalLetters: 3, damageTaken: 0), 3)
    }

    func testSmileProgressionMatchesHeartMilestones() {
        XCTAssertEqual(GameRules.smileLevel(for: 0), -1)
        XCTAssertEqual(GameRules.smileLevel(for: 1), 0)
        XCTAssertEqual(GameRules.smileLevel(for: 4), 1)
        XCTAssertEqual(GameRules.smileLevel(for: 16), 5)
    }
}
