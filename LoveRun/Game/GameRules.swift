import CoreGraphics
import Foundation

enum GameRules {
    static let pointsPerHeart = 100
    static let heartsToWin = 20
    static let missesAllowed = 3

    static func smileLevel(for hearts: Int) -> Int {
        guard hearts > 0 else { return -1 }
        return min(5, (hearts - 1) / 3)
    }

    static func spawnInterval(for hearts: Int) -> TimeInterval {
        max(0.85, 2.0 - Double(hearts) * 0.055)
    }

    static func crowns(letters: Int, totalLetters: Int, damageTaken: Int) -> Int {
        1 + (letters >= totalLetters ? 1 : 0) + (damageTaken == 0 ? 1 : 0)
    }
}
