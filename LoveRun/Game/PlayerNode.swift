import SpriteKit

final class PlayerNode: SKNode {
    static let collisionSize = CGSize(width: 54, height: 108)

    private let runner = SKSpriteNode()
    private let runTextures: [SKTexture]
    private let idleTexture: SKTexture
    private let jumpTextures: [SKTexture]
    private let sparkles = SKNode()
    private var isRunningAnimationActive = false
    private var isIdleAnimationActive = false
    private var animationClock: CGFloat = 0

    private let runningSize = CGSize(width: 134, height: 134)
    private let idleSize = CGSize(width: 62, height: 134)

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

        let idleSheet = SKTexture(imageNamed: "BlondeRunnerIdle")
        // A single planted pose is intentional. Cycling separately generated poses made
        // her feet and silhouette slide even when the player node itself never moved.
        idleTexture = SKTexture(rect: CGRect(x: 0.0866, y: 0.03, width: 0.1427, height: 0.94), in: idleSheet)
        idleTexture.filteringMode = .linear

        let jumpSheet = SKTexture(imageNamed: "BlondeRunnerJump")
        jumpTextures = (0..<4).map { index in
            let texture = SKTexture(
                rect: CGRect(x: CGFloat(index) / 4 + 0.0125, y: 0.14, width: 0.225, height: 0.78),
                in: jumpSheet
            )
            texture.filteringMode = .linear
            return texture
        }
        super.init()
        zPosition = 20

        runner.texture = runTextures[0]
        runner.anchorPoint = CGPoint(x: 0.5, y: 0)
        runner.size = runningSize
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

    func updateAnimation(deltaTime: CGFloat, moving: Bool, airborne: Bool, facing: CGFloat, verticalVelocity: CGFloat = 0, sliding: Bool = false) {
        xScale = facing
        if sliding {
            stopRunningAnimation()
            stopIdleAnimation()
            runner.texture = runTextures[2]
            runner.size = CGSize(width: 142, height: 82)
            runner.position.y = -3
            runner.zRotation = -0.07
        } else if moving && !airborne {
            animationClock += deltaTime
            stopIdleAnimation()
            if !isRunningAnimationActive {
                runner.size = runningSize
                runner.run(.repeatForever(.animate(with: runTextures, timePerFrame: 0.07, resize: false, restore: false)), withKey: "runCycle")
                isRunningAnimationActive = true
            }
            runner.position.y = -4 + sin(animationClock / 0.42 * .pi * 2) * 0.8
            runner.zRotation = 0
        } else {
            stopRunningAnimation()
            animationClock = 0
            if airborne {
                stopIdleAnimation()
                let frame: Int
                if verticalVelocity > 430 { frame = 0 }
                else if verticalVelocity > 120 { frame = 1 }
                else if verticalVelocity > -180 { frame = 2 }
                else { frame = 3 }
                runner.texture = jumpTextures[frame]
                runner.size = runningSize
                runner.position.y = 0
                runner.zRotation = 0
            } else {
                runner.position.y = -4
                runner.zRotation = 0
                if !isIdleAnimationActive {
                    runner.texture = idleTexture
                    runner.size = idleSize
                    runner.run(
                        .repeatForever(.sequence([
                            .scaleX(to: 1.006, y: 0.994, duration: 0.7),
                            .scaleX(to: 1, y: 1, duration: 0.7)
                        ])),
                        withKey: "idleCycle"
                    )
                    isIdleAnimationActive = true
                }
            }
        }
    }

    func standStill(facing: CGFloat) {
        updateAnimation(deltaTime: 0, moving: false, airborne: false, facing: facing)
    }

    private func stopRunningAnimation() {
        guard isRunningAnimationActive else { return }
        runner.removeAction(forKey: "runCycle")
        isRunningAnimationActive = false
    }

    private func stopIdleAnimation() {
        guard isIdleAnimationActive else { return }
        runner.removeAction(forKey: "idleCycle")
        runner.setScale(1)
        isIdleAnimationActive = false
    }

    func squashForLanding() {
        runner.removeAction(forKey: "landing")
        runner.run(.sequence([
            .scaleX(to: 1.06, y: 0.91, duration: 0.055),
            .scale(to: 1, duration: 0.085)
        ]), withKey: "landing")
    }

    func performTwirl() {
        removeAction(forKey: "airTwirl")
        run(.rotate(byAngle: .pi * 2, duration: 0.30), withKey: "airTwirl")
    }

}
