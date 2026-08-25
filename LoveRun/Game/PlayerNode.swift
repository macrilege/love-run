import SpriteKit

final class PlayerNode: SKNode {
    static let collisionSize = CGSize(width: 54, height: 108)

    private let runner = SKSpriteNode()
    private let runTextures: [SKTexture]
    private let sparkles = SKNode()
    private var isRunningAnimationActive = false

    override init() {
        let sheet = SKTexture(imageNamed: "BlondeRunner")
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
        runner.size = CGSize(width: 132, height: 127)
        runner.position = CGPoint(x: 0, y: -17)
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
            if !isRunningAnimationActive {
                runner.run(.repeatForever(.animate(with: runTextures, timePerFrame: 0.085, resize: false, restore: false)), withKey: "runCycle")
                isRunningAnimationActive = true
            }
            runner.position.y = -17
            runner.zRotation = 0
        } else {
            if isRunningAnimationActive {
                runner.removeAction(forKey: "runCycle")
                isRunningAnimationActive = false
            }
            runner.texture = airborne ? runTextures[5] : runTextures[0]
            runner.position.y = airborne ? -13 : -17
            runner.zRotation = airborne ? -0.04 : 0
        }
    }

    func squashForLanding() {
        removeAction(forKey: "landing")
        run(.sequence([
            .scaleX(to: xScale * 1.08, y: 0.88, duration: 0.06),
            .scaleX(to: xScale.sign == .minus ? -1 : 1, y: 1, duration: 0.09)
        ]), withKey: "landing")
    }

}
