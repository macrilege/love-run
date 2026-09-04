import SpriteKit

final class PlayerNode: SKNode {
    static let collisionSize = CGSize(width: 54, height: 108)

    private let runner = SKSpriteNode()
    private let runTextures: [SKTexture]
    private let sparkles = SKNode()
    private var isRunningAnimationActive = false
    private var animationClock: CGFloat = 0

    override init() {
        let sheet = SKTexture(imageNamed: "BlondeRunnerSmooth")
        let cells = [
            CGRect(x: 0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            CGRect(x: 1.0 / 3.0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            CGRect(x: 2.0 / 3.0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 0.5),
            CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 0.5),
            CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 0.5)
        ]
        runTextures = cells.map {
            let texture = SKTexture(rect: $0, in: sheet)
            texture.filteringMode = .linear
            return texture
        }
        super.init()
        zPosition = 20

        runner.texture = runTextures[0]
        runner.anchorPoint = CGPoint(x: 0.5, y: 0)
        runner.size = CGSize(width: 134, height: 134)
        runner.position = CGPoint(x: 0, y: -4)
        addChild(runner)

        sparkles.zPosition = 2
        sparkles.position = CGPoint(x: 0, y: 92)
        addChild(sparkles)
        setSmileLevel(-1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSmileLevel(_ level: Int) {
        runner.color = .systemPink
        runner.colorBlendFactor = level < 0 ? 0 : min(0.16, CGFloat(level + 1) * 0.025)
        sparkles.removeAllChildren()
        guard level >= 1 else { return }
        let count = level + 2
        for index in 0..<count {
            let star = SKLabelNode(text: index.isMultiple(of: 2) ? "♥" : "✦")
            star.fontSize = index.isMultiple(of: 2) ? 13 : 11
            star.fontColor = index.isMultiple(of: 2) ? .systemPink : .yellow
            star.verticalAlignmentMode = .center
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            star.position = CGPoint(x: cos(angle) * 48, y: sin(angle) * 42)
            star.run(.repeatForever(.sequence([
                .scale(to: 1.6, duration: 0.35),
                .scale(to: 0.65, duration: 0.35)
            ])))
            sparkles.addChild(star)
        }
    }

    func updateAnimation(deltaTime: CGFloat, moving: Bool, airborne: Bool, facing: CGFloat) {
        xScale = facing
        if moving && !airborne {
            animationClock += deltaTime
            if !isRunningAnimationActive {
                runner.run(.repeatForever(.animate(with: runTextures, timePerFrame: 0.07, resize: false, restore: false)), withKey: "runCycle")
                isRunningAnimationActive = true
            }
            runner.position.y = -4 + sin(animationClock / 0.42 * .pi * 2) * 0.8
            runner.zRotation = 0
        } else {
            if isRunningAnimationActive {
                runner.removeAction(forKey: "runCycle")
                isRunningAnimationActive = false
            }
            animationClock = 0
            runner.texture = airborne ? runTextures[2] : runTextures[0]
            runner.position.y = airborne ? 0 : -4
            runner.zRotation = airborne ? -0.04 : 0
        }
    }

    func squashForLanding() {
        runner.removeAction(forKey: "landing")
        runner.run(.sequence([
            .scaleX(to: 1.06, y: 0.91, duration: 0.055),
            .scale(to: 1, duration: 0.085)
        ]), withKey: "landing")
    }

}
