import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum State {
        case title
        case playing
        case finished(won: Bool)
    }

    private let world = SKNode()
    private let hud = SKNode()
    private let gameCamera = SKCameraNode()
    private let player = PlayerNode()
    private let groundY: CGFloat = 54
    private let worldWidth: CGFloat = 4_500

    private var state: State = .title
    private var hearts: [SKNode] = []
    private var velocity = CGVector.zero
    private var facing: CGFloat = 1
    private var grounded = true
    private var coyoteTime: TimeInterval = 0
    private var jumpBuffer: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var previousUpdateTime: TimeInterval = 0
    private var heartsCaught = 0
    private var misses = 0
    private var score = 0
    private var heldTouches: [UITouch: CGPoint] = [:]

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let progressLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bestLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let messageLayer = SKNode()
    private let leftButton = SKShapeNode(circleOfRadius: 34)
    private let rightButton = SKShapeNode(circleOfRadius: 34)
    private let jumpButton = SKShapeNode(circleOfRadius: 42)

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.52, green: 0.81, blue: 0.93, alpha: 1)
        physicsWorld.gravity = .zero
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60

        addChild(world)
        addChild(gameCamera)
        camera = gameCamera
        gameCamera.addChild(hud)
        gameCamera.addChild(messageLayer)

        buildWorld()
        buildHUD()
        if ProcessInfo.processInfo.environment["LOVE_RUN_AUTOSTART"] == "1" {
            startGame()
        } else {
            showTitle()
        }
    }

    private func buildWorld() {
        let sky = SKSpriteNode(color: UIColor(red: 0.52, green: 0.81, blue: 0.93, alpha: 1), size: CGSize(width: worldWidth, height: size.height))
        sky.anchorPoint = .zero
        sky.position = .zero
        sky.zPosition = -20
        world.addChild(sky)

        for index in 0..<18 {
            let hill = SKShapeNode(ellipseOf: CGSize(width: 340, height: 125))
            hill.fillColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.48, green: 0.82, blue: 0.53, alpha: 1)
                : UIColor(red: 0.58, green: 0.88, blue: 0.58, alpha: 1)
            hill.strokeColor = .clear
            hill.position = CGPoint(x: CGFloat(index) * 280 + 100, y: 55)
            hill.zPosition = -8
            world.addChild(hill)
        }

        for index in 0..<14 {
            let cloud = makeCloud()
            cloud.position = CGPoint(x: CGFloat(index) * 340 + 120, y: 285 + CGFloat(index % 3) * 30)
            cloud.setScale(0.8 + CGFloat(index % 2) * 0.25)
            cloud.zPosition = -10
            world.addChild(cloud)
        }

        let ground = SKSpriteNode(color: UIColor(red: 0.26, green: 0.70, blue: 0.35, alpha: 1), size: CGSize(width: worldWidth, height: groundY))
        ground.anchorPoint = .zero
        ground.position = .zero
        ground.zPosition = 2
        world.addChild(ground)

        for index in 0..<90 {
            let flower = SKLabelNode(text: index.isMultiple(of: 3) ? "✿" : "•")
            flower.fontSize = index.isMultiple(of: 3) ? 14 : 18
            flower.fontColor = index.isMultiple(of: 2) ? .white : UIColor(red: 1, green: 0.83, blue: 0.2, alpha: 1)
            flower.position = CGPoint(x: CGFloat(index) * 50 + 20, y: 22 + CGFloat(index % 2) * 11)
            flower.zPosition = 3
            world.addChild(flower)
        }

        player.position = CGPoint(x: 120, y: groundY + 8)
        world.addChild(player)
        gameCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func makeCloud() -> SKNode {
        let cloud = SKNode()
        for (position, radius) in [
            (CGPoint(x: -34, y: 0), 23.0),
            (CGPoint(x: 0, y: 12), 31.0),
            (CGPoint(x: 35, y: 0), 25.0)
        ] {
            let puff = SKShapeNode(circleOfRadius: radius)
            puff.fillColor = .white.withAlphaComponent(0.78)
            puff.strokeColor = .clear
            puff.position = position
            cloud.addChild(puff)
        }
        return cloud
    }

    private func buildHUD() {
        scoreLabel.fontSize = 25
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -392, y: 151)
        scoreLabel.zPosition = 100
        hud.addChild(scoreLabel)

        progressLabel.fontSize = 17
        progressLabel.horizontalAlignmentMode = .left
        progressLabel.position = CGPoint(x: -392, y: 124)
        progressLabel.zPosition = 100
        hud.addChild(progressLabel)

        bestLabel.fontSize = 16
        bestLabel.horizontalAlignmentMode = .right
        bestLabel.position = CGPoint(x: 392, y: 151)
        bestLabel.zPosition = 100
        hud.addChild(bestLabel)

        configureButton(leftButton, text: "◀", position: CGPoint(x: -350, y: -135), fontSize: 30)
        configureButton(rightButton, text: "▶", position: CGPoint(x: -268, y: -135), fontSize: 30)
        configureButton(jumpButton, text: "JUMP", position: CGPoint(x: 344, y: -130), fontSize: 15)
        updateHUD()
    }

    private func configureButton(_ button: SKShapeNode, text: String, position: CGPoint, fontSize: CGFloat) {
        button.position = position
        button.fillColor = .white.withAlphaComponent(0.24)
        button.strokeColor = .white.withAlphaComponent(0.8)
        button.lineWidth = 2
        button.zPosition = 100
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = fontSize
        label.verticalAlignmentMode = .center
        label.fontColor = .white
        label.zPosition = 1
        button.addChild(label)
        hud.addChild(button)
    }

    private func showTitle() {
        state = .title
        setControlsHidden(true)
        messageLayer.removeAllChildren()
        addPanel(title: "LOVE RUN", subtitle: "Catch 20 hearts before 3 get away!\nHold ◀ or ▶ to run • Tap JUMP to leap", action: "TAP TO START", accent: "♥")
    }

    private func startGame() {
        for heart in hearts { heart.removeFromParent() }
        hearts.removeAll()
        heldTouches.removeAll()
        player.removeAllActions()
        player.position = CGPoint(x: 120, y: groundY + 8)
        player.setScale(1)
        player.setSmileLevel(-1)
        velocity = .zero
        if ProcessInfo.processInfo.environment["LOVE_RUN_AUTORUN"] == "1" {
            velocity.dx = 235
        }
        facing = 1
        grounded = true
        coyoteTime = 0.1
        jumpBuffer = 0
        spawnTimer = 0.7
        previousUpdateTime = 0
        heartsCaught = 0
        misses = 0
        score = 0
        gameCamera.position.x = size.width / 2
        messageLayer.removeAllChildren()
        setControlsHidden(false)
        updateHUD()
        state = .playing
    }

    private func finish(won: Bool) {
        state = .finished(won: won)
        heldTouches.removeAll()
        velocity.dx = 0
        setControlsHidden(true)

        let oldBest = UserDefaults.standard.integer(forKey: "LoveRun.bestScore")
        if score > oldBest {
            UserDefaults.standard.set(score, forKey: "LoveRun.bestScore")
        }
        updateHUD()
        let subtitle = won
            ? "You collected every heart!\nFinal score: \(score)"
            : "Three hearts got away.\nFinal score: \(score)"
        addPanel(title: won ? "YOU FILLED THE WORLD WITH LOVE!" : "KEEP THE LOVE GOING!", subtitle: subtitle, action: "TAP TO RUN AGAIN", accent: won ? "💖" : "♥")
    }

    private func addPanel(title: String, subtitle: String, action: String, accent: String) {
        let shade = SKShapeNode(rectOf: CGSize(width: 620, height: 250), cornerRadius: 28)
        shade.fillColor = UIColor(red: 0.24, green: 0.06, blue: 0.23, alpha: 0.86)
        shade.strokeColor = .white.withAlphaComponent(0.75)
        shade.lineWidth = 3
        shade.zPosition = 200
        messageLayer.addChild(shade)

        let heart = SKLabelNode(text: accent)
        heart.fontSize = 48
        heart.position = CGPoint(x: 0, y: 58)
        heart.zPosition = 201
        messageLayer.addChild(heart)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = title
        titleLabel.fontSize = title.count > 20 ? 25 : 38
        titleLabel.fontColor = UIColor(red: 1, green: 0.58, blue: 0.77, alpha: 1)
        titleLabel.position = CGPoint(x: 0, y: 20)
        titleLabel.zPosition = 201
        messageLayer.addChild(titleLabel)

        let lines = subtitle.split(separator: "\n")
        for (index, line) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = String(line)
            label.fontSize = 17
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: -17 - CGFloat(index) * 24)
            label.zPosition = 201
            messageLayer.addChild(label)
        }

        let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        actionLabel.text = action
        actionLabel.fontSize = 18
        actionLabel.fontColor = .yellow
        actionLabel.position = CGPoint(x: 0, y: -91)
        actionLabel.zPosition = 201
        actionLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 0.65),
            .fadeAlpha(to: 1, duration: 0.65)
        ])))
        messageLayer.addChild(actionLabel)
    }

    private func setControlsHidden(_ hidden: Bool) {
        leftButton.isHidden = hidden
        rightButton.isHidden = hidden
        jumpButton.isHidden = hidden
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .title, .finished:
            startGame()
        case .playing:
            for touch in touches {
                heldTouches[touch] = touch.location(in: gameCamera)
            }
            refreshInput()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard case .playing = state else { return }
        for touch in touches {
            heldTouches[touch] = touch.location(in: gameCamera)
        }
        refreshInput()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { heldTouches.removeValue(forKey: touch) }
        refreshInput()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func refreshInput() {
        var direction: CGFloat = 0
        var wantsJump = false
        for point in heldTouches.values {
            if point.x < -225 {
                direction = point.x < -309 ? -1 : 1
            } else if point.x > 230 {
                wantsJump = true
            }
        }
        velocity.dx = direction * 235
        if direction != 0 { facing = direction }
        if wantsJump { jumpBuffer = 0.12 }

        leftButton.fillColor = direction < 0 ? .white.withAlphaComponent(0.5) : .white.withAlphaComponent(0.24)
        rightButton.fillColor = direction > 0 ? .white.withAlphaComponent(0.5) : .white.withAlphaComponent(0.24)
        jumpButton.fillColor = wantsJump ? .white.withAlphaComponent(0.5) : .white.withAlphaComponent(0.24)
    }

    override func update(_ currentTime: TimeInterval) {
        guard case .playing = state else {
            previousUpdateTime = currentTime
            return
        }

        let rawDelta = previousUpdateTime == 0 ? 1.0 / 60.0 : currentTime - previousUpdateTime
        let dt = min(rawDelta, 1.0 / 30.0)
        previousUpdateTime = currentTime

        updatePlayer(deltaTime: dt)
        updateHearts(deltaTime: dt)
        updateCamera()
    }

    private func updatePlayer(deltaTime dt: TimeInterval) {
        jumpBuffer = max(0, jumpBuffer - dt)
        coyoteTime = grounded ? 0.1 : max(0, coyoteTime - dt)
        if jumpBuffer > 0, coyoteTime > 0 {
            velocity.dy = 620
            grounded = false
            coyoteTime = 0
            jumpBuffer = 0
            emitDust(at: player.position, color: .white)
        }

        velocity.dy -= 1_650 * dt
        velocity.dy = max(velocity.dy, -900)
        player.position.x = min(max(24, player.position.x + velocity.dx * dt), worldWidth - 24)
        player.position.y += velocity.dy * dt

        let floor = groundY + 8
        if player.position.y <= floor {
            if !grounded, velocity.dy < -180 { player.squashForLanding() }
            player.position.y = floor
            velocity.dy = 0
            grounded = true
        } else {
            grounded = false
        }

        player.updateAnimation(deltaTime: dt, moving: velocity.dx != 0, airborne: !grounded, facing: facing)
    }

    private func updateCamera() {
        let target = max(size.width / 2, min(worldWidth - size.width / 2, player.position.x + size.width / 6))
        gameCamera.position.x += (target - gameCamera.position.x) * 0.09
    }

    private func updateHearts(deltaTime dt: TimeInterval) {
        spawnTimer += dt
        if spawnTimer >= GameRules.spawnInterval(for: heartsCaught) {
            spawnTimer = 0
            spawnHeart()
        }

        let playerRect = CGRect(
            x: player.position.x - PlayerNode.collisionSize.width / 2,
            y: player.position.y,
            width: PlayerNode.collisionSize.width,
            height: PlayerNode.collisionSize.height
        )

        for heart in hearts.reversed() {
            heart.zRotation += CGFloat(dt) * 0.75
            let heartRect = CGRect(x: heart.position.x - 17, y: heart.position.y - 17, width: 34, height: 34)
            if playerRect.intersects(heartRect) {
                collect(heart)
            } else if heart.position.x < gameCamera.position.x - size.width / 2 - 50 {
                miss(heart)
            }
        }
    }

    private func spawnHeart() {
        let heart = makeHeart()
        let low = groundY + 72
        let high = groundY + 185
        heart.position = CGPoint(
            x: min(worldWidth - 60, gameCamera.position.x + size.width / 2 + CGFloat.random(in: 30...180)),
            y: CGFloat.random(in: low...high)
        )
        heart.setScale(0.9)
        heart.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.42),
            .scale(to: 0.9, duration: 0.42)
        ])))
        world.addChild(heart)
        hearts.append(heart)
    }

    private func makeHeart() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -18))
        path.addCurve(to: CGPoint(x: -31, y: 7), control1: CGPoint(x: -8, y: -7), control2: CGPoint(x: -31, y: -3))
        path.addCurve(to: CGPoint(x: 0, y: 24), control1: CGPoint(x: -31, y: 27), control2: CGPoint(x: -8, y: 31))
        path.addCurve(to: CGPoint(x: 31, y: 7), control1: CGPoint(x: 8, y: 31), control2: CGPoint(x: 31, y: 27))
        path.addCurve(to: CGPoint(x: 0, y: -18), control1: CGPoint(x: 31, y: -3), control2: CGPoint(x: 8, y: -7))
        path.closeSubpath()
        let heart = SKShapeNode(path: path)
        heart.fillColor = UIColor(red: 0.96, green: 0.08, blue: 0.48, alpha: 1)
        heart.strokeColor = .white
        heart.lineWidth = 2
        heart.zPosition = 12

        let shine = SKShapeNode(circleOfRadius: 5)
        shine.fillColor = .white.withAlphaComponent(0.55)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -10, y: 10)
        heart.addChild(shine)
        return heart
    }

    private func collect(_ heart: SKNode) {
        guard let index = hearts.firstIndex(where: { $0 === heart }) else { return }
        hearts.remove(at: index)
        emitBurst(at: heart.position)
        heart.removeFromParent()
        heartsCaught += 1
        score += GameRules.pointsPerHeart
        player.setSmileLevel(GameRules.smileLevel(for: heartsCaught))
        updateHUD()
        if heartsCaught >= GameRules.heartsToWin { finish(won: true) }
    }

    private func miss(_ heart: SKNode) {
        guard let index = hearts.firstIndex(where: { $0 === heart }) else { return }
        hearts.remove(at: index)
        heart.removeFromParent()
        misses += 1
        updateHUD()
        if misses >= GameRules.missesAllowed { finish(won: false) }
    }

    private func emitBurst(at position: CGPoint) {
        for index in 0..<12 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            particle.fillColor = index.isMultiple(of: 2) ? .systemPink : .yellow
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 30
            world.addChild(particle)
            let angle = CGFloat(index) / 12 * .pi * 2
            let distance = CGFloat.random(in: 35...75)
            particle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.45),
                    .fadeOut(withDuration: 0.45),
                    .scale(to: 0.2, duration: 0.45)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func emitDust(at position: CGPoint, color: UIColor) {
        for offset in [-12.0, 12.0] {
            let particle = SKShapeNode(circleOfRadius: 5)
            particle.fillColor = color.withAlphaComponent(0.65)
            particle.strokeColor = .clear
            particle.position = CGPoint(x: position.x + offset, y: groundY + 5)
            particle.zPosition = 15
            world.addChild(particle)
            particle.run(.sequence([
                .group([.moveBy(x: offset, y: 10, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent()
            ]))
        }
    }

    private func updateHUD() {
        scoreLabel.text = "SCORE  \(score)"
        progressLabel.text = "💗 \(heartsCaught)/\(GameRules.heartsToWin)   •   MISSED \(misses)/\(GameRules.missesAllowed)"
        let best = max(score, UserDefaults.standard.integer(forKey: "LoveRun.bestScore"))
        bestLabel.text = "BEST  \(best)"
    }
}
