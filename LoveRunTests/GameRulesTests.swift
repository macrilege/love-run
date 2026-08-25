import XCTest
@testable import LoveRun

final class GameRulesTests: XCTestCase {
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

