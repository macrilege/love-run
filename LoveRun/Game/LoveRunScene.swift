import SpriteKit
import UIKit

final class LoveRunScene: SKScene {
    private enum State { case title, intro, playing, finished }

    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private let backdrop = SKSpriteNode()
    private let hud = SKNode()
    private let messages = SKNode()
    private let player = PlayerNode()
    private let groundY: CGFloat = 58

    private var state: State = .title
    private var levelIndex = 0
    private var rescued = 0
    private var health = 3
    private var score = 0
    private var combo = 0
    private var comboTime: TimeInterval = 0
    private var love = 0
    private var totalLove = 1
    private var pickups: [SKNode] = []
    private var puppy: SKSpriteNode?
    private var surfaces: [CGRect] = []
    private var velocity = CGVector.zero
    private var direction: CGFloat = 0
    private var facing: CGFloat = 1
    private var grounded = true
    private var coyote: TimeInterval = 0
    private var jumpBuffer: TimeInterval = 0
    private var invincible: TimeInterval = 0
    private var previousTime: TimeInterval = 0
    private var heldTouches: [UITouch: CGPoint] = [:]
    private var level: LevelDefinition { LevelDefinition.all[levelIndex] }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let healthLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let puppyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let loveFill = SKSpriteNode(color: UIColor(red: 1, green: 0.08, blue: 0.52, alpha: 1), size: CGSize(width: 216, height: 12))
    private let leftButton = SKShapeNode(circleOfRadius: 34)
    private let rightButton = SKShapeNode(circleOfRadius: 34)
    private let jumpButton = SKShapeNode(circleOfRadius: 42)

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.14, green: 0.01, blue: 0.18, alpha: 1)
        physicsWorld.gravity = .zero
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
        addChild(world)
        addChild(cameraNode)
        camera = cameraNode
        backdrop.size = CGSize(width: size.width, height: size.width * 941 / 1_672)
        backdrop.zPosition = -100
        cameraNode.addChild(backdrop)
        cameraNode.addChild(hud)
        cameraNode.addChild(messages)
        buildHUD()
        showTitle()
        if ProcessInfo.processInfo.environment["LOVE_RUN_AUTOSTART"] == "1" {
            newRun()
            if let rawLevel = ProcessInfo.processInfo.environment["LOVE_RUN_START_LEVEL"],
               let requestedLevel = Int(rawLevel) {
                levelIndex = min(max(0, requestedLevel), LevelDefinition.all.count - 1)
                rescued = levelIndex
                buildLevel()
                beginLevel()
            }
            if ProcessInfo.processInfo.environment["LOVE_RUN_START_AT_PUPPY"] == "1" {
                player.position.x = level.puppyPosition.x - 105
                cameraNode.position.x = level.worldWidth - size.width / 2
            }
        }
    }

    private func showTitle() {
        levelIndex = 0
        rescued = 0
        health = 3
        score = 0
        buildLevel()
        state = .title
        setControls(hidden: true)
        showPanel(title: "LOVE RUN", lines: ["THREE WORLDS • THREE PUPPIES • ZERO APOLOGIES", "Run, leap, collect, and rescue every little icon."], action: "TAP TO SERVE")
    }

    private func newRun() {
        levelIndex = 0
        rescued = 0
        health = 3
        score = 0
        buildLevel()
        beginLevel()
    }

    private func buildLevel() {
        world.removeAllChildren()
        pickups.removeAll()
        surfaces.removeAll()
        puppy = nil
        heldTouches.removeAll()
        backdrop.texture = SKTexture(imageNamed: level.backgroundAsset)
        backdrop.texture?.filteringMode = .linear
        buildGround()
        buildPetals()
        level.platforms.forEach(buildPlatform)
        level.hazards.forEach(buildHazard)
        level.bouncePads.forEach(buildBouncePad)
        level.pickups.forEach(buildPickup)
        buildPuppy()
        player.removeAllActions()
        player.position = CGPoint(x: 125, y: groundY)
        player.setScale(1)
        player.alpha = 1
        player.setSmileLevel(-1)
        world.addChild(player)
        velocity = .zero
        direction = 0
        facing = 1
        grounded = true
        coyote = 0.1
        jumpBuffer = 0
        invincible = 0
        combo = 0
        comboTime = 0
        love = 0
        totalLove = level.pickups.reduce(0) { $0 + ($1.style == .goldenHeart ? 3 : $1.style == .letter ? 2 : 1) }
        previousTime = 0
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        updateHUD()
    }

    private func beginLevel() {
        messages.removeAllChildren()
        direction = ProcessInfo.processInfo.environment["LOVE_RUN_AUTORUN"] == "1" ? 1 : 0
        setControls(hidden: false)
        state = .playing
    }

    private func buildGround() {
        let ground = SKSpriteNode(
            color: levelIndex == 2 ? UIColor(red: 0.16, green: 0.01, blue: 0.28, alpha: 0.82) : UIColor(red: 0.28, green: 0.03, blue: 0.25, alpha: 0.55),
            size: CGSize(width: level.worldWidth, height: groundY)
        )
        ground.anchorPoint = .zero
        ground.zPosition = 1
        world.addChild(ground)
        let edge = SKSpriteNode(color: UIColor(red: 1, green: 0.75, blue: 0.16, alpha: 1), size: CGSize(width: level.worldWidth, height: 3))
        edge.anchorPoint = .zero
        edge.position.y = groundY - 2
        edge.zPosition = 7
        world.addChild(edge)
    }

    private func buildPetals() {
        for index in 0..<64 {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 7, height: 3.5))
            petal.fillColor = index.isMultiple(of: 4) ? .yellow : UIColor(red: 1, green: 0.32, blue: 0.69, alpha: 0.78)
            petal.strokeColor = .clear
            petal.position = CGPoint(x: CGFloat(index) / 64 * level.worldWidth, y: 74 + CGFloat((index * 53) % 245))
            petal.zRotation = CGFloat(index % 8) * 0.4
            petal.zPosition = 3
            petal.run(.repeatForever(.sequence([.moveBy(x: 24, y: -12, duration: 1.8), .moveBy(x: -24, y: 12, duration: 0)])))
            world.addChild(petal)
        }
    }

    private func buildPlatform(_ spec: PlatformSpec) {
        surfaces.append(spec.rect)
        let root = SKNode()
        root.position = CGPoint(x: spec.rect.midX, y: spec.rect.midY)
        root.zPosition = 11
        let shadow = SKShapeNode(rectOf: CGSize(width: spec.rect.width + 8, height: spec.rect.height + 9), cornerRadius: 10)
        shadow.fillColor = UIColor(red: 0.08, green: 0, blue: 0.12, alpha: 0.5)
        shadow.strokeColor = .clear
        shadow.position.y = -6
        root.addChild(shadow)
        if spec.style == .cloud {
            for x in stride(from: -spec.rect.width / 2 + 15, through: spec.rect.width / 2 - 10, by: 25) {
                let puff = SKShapeNode(circleOfRadius: 19)
                puff.fillColor = UIColor(red: 1, green: 0.70, blue: 0.90, alpha: 0.97)
                puff.strokeColor = .white
                puff.lineWidth = 2
                puff.position.x = x
                root.addChild(puff)
            }
        } else {
            let body = SKShapeNode(rectOf: spec.rect.size, cornerRadius: 9)
            body.fillColor = spec.style == .picnic ? UIColor(red: 0.96, green: 0.10, blue: 0.48, alpha: 1) : UIColor(red: 0.46, green: 0.12, blue: 0.48, alpha: 1)
            body.strokeColor = UIColor(red: 1, green: 0.76, blue: 0.16, alpha: 1)
            body.lineWidth = 3
            root.addChild(body)
            for x in stride(from: -spec.rect.width / 2 + 15, through: spec.rect.width / 2 - 10, by: 26) {
                let jewel = SKShapeNode(circleOfRadius: 4)
                jewel.fillColor = spec.style == .picnic ? .white : UIColor(red: 1, green: 0.20, blue: 0.64, alpha: 1)
                jewel.strokeColor = .clear
                jewel.position.x = x
                root.addChild(jewel)
            }
        }
        let lip = SKSpriteNode(color: UIColor(red: 1, green: 0.20, blue: 0.61, alpha: 1), size: CGSize(width: spec.rect.width - 7, height: 5))
        lip.position.y = spec.rect.height / 2
        lip.zPosition = 4
        root.addChild(lip)
        world.addChild(root)
    }

    private func buildHazard(_ spec: HazardSpec) {
        let root = SKNode()
        root.position = CGPoint(x: spec.rect.midX, y: spec.rect.midY)
        root.zPosition = 15
        switch spec.style {
        case .puddle:
            let shape = SKShapeNode(ellipseOf: spec.rect.size)
            shape.fillColor = UIColor(red: 0.43, green: 0.15, blue: 0.90, alpha: 0.88)
            shape.strokeColor = UIColor(red: 0.96, green: 0.71, blue: 1, alpha: 1)
            shape.lineWidth = 2
            root.addChild(shape)
        case .hedge:
            let shape = SKShapeNode(rectOf: spec.rect.size, cornerRadius: 13)
            shape.fillColor = UIColor(red: 0.07, green: 0.38, blue: 0.20, alpha: 1)
            shape.strokeColor = UIColor(red: 1, green: 0.20, blue: 0.58, alpha: 1)
            shape.lineWidth = 3
            root.addChild(shape)
            for x in [-20.0, 0, 20.0] {
                let rose = SKShapeNode(circleOfRadius: 6)
                rose.fillColor = UIColor(red: 1, green: 0.05, blue: 0.45, alpha: 1)
                rose.strokeColor = UIColor(red: 1, green: 0.75, blue: 0.16, alpha: 1)
                rose.position.x = x
                root.addChild(rose)
            }
        case .thorns:
            let vine = SKSpriteNode(color: UIColor(red: 0.14, green: 0.38, blue: 0.16, alpha: 1), size: CGSize(width: spec.rect.width, height: 6))
            root.addChild(vine)
            for x in stride(from: -spec.rect.width / 2 + 8, through: spec.rect.width / 2 - 6, by: 15) {
                let thorn = SKShapeNode(path: triangle(width: 10, height: 17))
                thorn.fillColor = UIColor(red: 1, green: 0.08, blue: 0.48, alpha: 1)
                thorn.strokeColor = UIColor(red: 1, green: 0.76, blue: 0.16, alpha: 1)
                thorn.position = CGPoint(x: x, y: 7)
                root.addChild(thorn)
            }
        }
        world.addChild(root)
    }

    private func buildBouncePad(_ point: CGPoint) {
        let root = SKNode()
        root.position = point
        root.zPosition = 17
        let stem = SKShapeNode(rectOf: CGSize(width: 8, height: 23), cornerRadius: 3)
        stem.fillColor = UIColor(red: 0.51, green: 0.10, blue: 0.55, alpha: 1)
        stem.strokeColor = UIColor(red: 1, green: 0.74, blue: 0.16, alpha: 1)
        stem.position.y = 11
        root.addChild(stem)
        for index in 0..<10 {
            let angle = CGFloat(index) / 10 * .pi * 2
            let petal = SKShapeNode(ellipseOf: CGSize(width: 20, height: 9))
            petal.fillColor = index.isMultiple(of: 2) ? .systemPink : UIColor(red: 1, green: 0.55, blue: 0.82, alpha: 1)
            petal.strokeColor = .white
            petal.position = CGPoint(x: cos(angle) * 15, y: 28 + sin(angle) * 7)
            petal.zRotation = angle
            root.addChild(petal)
        }
        let center = SKShapeNode(circleOfRadius: 8)
        center.fillColor = .yellow
        center.strokeColor = .white
        center.position.y = 28
        root.addChild(center)
        root.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.45), .scale(to: 1, duration: 0.45)])))
        world.addChild(root)
    }

    private func buildPickup(_ spec: PickupSpec) {
        let node = spec.style == .letter ? makeLetter() : makeHeart(golden: spec.style == .goldenHeart)
        node.name = spec.style.rawValue
        node.position = spec.position
        node.zPosition = 28
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 0.55), .moveBy(x: 0, y: -7, duration: 0.55)])))
        world.addChild(node)
        pickups.append(node)
    }

    private func buildPuppy() {
        let sheet = SKTexture(imageNamed: "PuppyRescues")
        let texture = SKTexture(rect: CGRect(x: CGFloat(level.puppyFrame) / 3, y: 0, width: 1 / 3, height: 1), in: sheet)
        texture.filteringMode = .linear
        let node = SKSpriteNode(texture: texture)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.size = CGSize(width: 88, height: 176)
        node.position = CGPoint(x: level.puppyPosition.x, y: groundY - 34)
        node.zPosition = 25
        let aura = SKShapeNode(circleOfRadius: 47)
        aura.fillColor = UIColor(red: 1, green: 0.15, blue: 0.58, alpha: 0.17)
        aura.strokeColor = UIColor(red: 1, green: 0.76, blue: 0.16, alpha: 1)
        aura.lineWidth = 3
        aura.position.y = 75
        aura.zPosition = -1
        aura.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.7), .scale(to: 0.94, duration: 0.7)])))
        node.addChild(aura)
        world.addChild(node)
        puppy = node
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "RESCUE \(level.puppyName.uppercased())"
        label.fontSize = 14
        label.fontColor = .yellow
        label.position = CGPoint(x: level.puppyPosition.x, y: 155)
        label.zPosition = 30
        world.addChild(label)
    }

    private func buildHUD() {
        scoreLabel.fontSize = 21
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -394, y: 157)
        healthLabel.fontSize = 19
        healthLabel.horizontalAlignmentMode = .left
        healthLabel.fontColor = UIColor(red: 1, green: 0.21, blue: 0.62, alpha: 1)
        healthLabel.position = CGPoint(x: -394, y: 129)
        levelLabel.fontSize = 14
        levelLabel.position = CGPoint(x: 0, y: 165)
        comboLabel.fontSize = 16
        comboLabel.fontColor = .yellow
        comboLabel.position = CGPoint(x: 276, y: 146)
        puppyLabel.fontSize = 14
        puppyLabel.horizontalAlignmentMode = .right
        puppyLabel.position = CGPoint(x: 394, y: 165)
        [scoreLabel, healthLabel, levelLabel, comboLabel, puppyLabel].forEach { $0.zPosition = 105; hud.addChild($0) }
        let track = SKShapeNode(rectOf: CGSize(width: 236, height: 24), cornerRadius: 12)
        track.fillColor = UIColor(red: 0.17, green: 0.01, blue: 0.23, alpha: 0.86)
        track.strokeColor = UIColor(red: 1, green: 0.76, blue: 0.16, alpha: 1)
        track.lineWidth = 2.5
        track.position = CGPoint(x: 0, y: 140)
        track.zPosition = 102
        hud.addChild(track)
        loveFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        loveFill.position = CGPoint(x: -108, y: 140)
        loveFill.zPosition = 104
        hud.addChild(loveFill)
        configure(leftButton, text: "◀", at: CGPoint(x: -352, y: -137), font: 28)
        configure(rightButton, text: "▶", at: CGPoint(x: -270, y: -137), font: 28)
        configure(jumpButton, text: "JUMP", at: CGPoint(x: 348, y: -133), font: 14)
    }

    private func configure(_ button: SKShapeNode, text: String, at position: CGPoint, font: CGFloat) {
        button.position = position
        button.fillColor = UIColor(red: 0.95, green: 0.04, blue: 0.48, alpha: 0.52)
        button.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.16, alpha: 1)
        button.lineWidth = 3
        button.glowWidth = 3
        button.zPosition = 110
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = font
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)
        hud.addChild(button)
    }

    private func setControls(hidden: Bool) {
        leftButton.isHidden = hidden
        rightButton.isHidden = hidden
        jumpButton.isHidden = hidden
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .title: newRun()
        case .intro: beginLevel()
        case .finished: showTitle()
        case .playing:
            touches.forEach { heldTouches[$0] = $0.location(in: cameraNode) }
            readControls()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .playing else { return }
        touches.forEach { heldTouches[$0] = $0.location(in: cameraNode) }
        readControls()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { heldTouches.removeValue(forKey: $0) }
        readControls()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }

    private func readControls() {
        guard state == .playing else { return }
        var newDirection: CGFloat = ProcessInfo.processInfo.environment["LOVE_RUN_AUTORUN"] == "1" ? 1 : 0
        var wantsJump = false
        for point in heldTouches.values {
            if point.x < -225 { newDirection = point.x < -311 ? -1 : 1 }
            else if point.x > 230 { wantsJump = true }
        }
        direction = newDirection
        if direction != 0 { facing = direction }
        if wantsJump { jumpBuffer = 0.13 }
        let normal = UIColor(red: 0.95, green: 0.04, blue: 0.48, alpha: 0.52)
        let active = UIColor(red: 1, green: 0.20, blue: 0.63, alpha: 0.9)
        leftButton.fillColor = direction < 0 ? active : normal
        rightButton.fillColor = direction > 0 ? active : normal
        jumpButton.fillColor = wantsJump ? active : normal
    }

    override func update(_ currentTime: TimeInterval) {
        guard state == .playing else { previousTime = currentTime; return }
        let dt = min(previousTime == 0 ? 1 / 60 : currentTime - previousTime, 1 / 30)
        previousTime = currentTime
        invincible = max(0, invincible - dt)
        comboTime = max(0, comboTime - dt)
        if comboTime == 0, combo > 0 { combo = 0; updateHUD() }
        updatePlayer(dt)
        updatePickups(dt)
        updateCamera()
    }

    private func updatePlayer(_ dt: TimeInterval) {
        jumpBuffer = max(0, jumpBuffer - dt)
        coyote = grounded ? 0.1 : max(0, coyote - dt)
        if jumpBuffer > 0, coyote > 0 {
            velocity.dy = 625
            grounded = false
            coyote = 0
            jumpBuffer = 0
            burst(at: player.position, colors: [.systemPink, .white], count: 7)
        }
        velocity.dx = direction * 265
        velocity.dy = max(velocity.dy - 1_650 * dt, -920)
        let oldY = player.position.y
        player.position.x = min(max(25, player.position.x + velocity.dx * dt), level.worldWidth - 25)
        var nextY = player.position.y + velocity.dy * dt
        grounded = false
        if velocity.dy <= 0 {
            var landing: CGFloat?
            if oldY >= groundY - 2, nextY <= groundY { landing = groundY }
            let minX = player.position.x - 20
            let maxX = player.position.x + 20
            for rect in surfaces where maxX > rect.minX && minX < rect.maxX && oldY >= rect.maxY - 2 && nextY <= rect.maxY {
                landing = max(landing ?? rect.maxY, rect.maxY)
            }
            if let landing {
                if velocity.dy < -190 { player.squashForLanding() }
                nextY = landing
                velocity.dy = 0
                grounded = true
            }
        }
        player.position.y = nextY
        if grounded, let pad = level.bouncePads.first(where: { abs($0.x - player.position.x) < 34 && abs($0.y - player.position.y) < 8 }) {
            velocity.dy = 780
            grounded = false
            burst(at: CGPoint(x: pad.x, y: pad.y + 28), colors: [.systemPink, .yellow, .white], count: 16)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let hitbox = CGRect(x: player.position.x - 18, y: player.position.y, width: 36, height: 64)
        if player.position.y < -70 || (invincible == 0 && level.hazards.contains(where: { hitbox.intersects($0.rect) })) { takeDamage() }
        player.updateAnimation(deltaTime: dt, moving: direction != 0, airborne: !grounded, facing: facing)
    }

    private func takeDamage() {
        guard invincible == 0 else { return }
        health -= 1
        combo = 0
        comboTime = 0
        invincible = 1.5
        velocity = CGVector(dx: -facing * 100, dy: 380)
        player.position.x = max(105, player.position.x - 70)
        burst(at: CGPoint(x: player.position.x, y: player.position.y + 45), colors: [UIColor.purple, .white], count: 15)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        player.run(.repeat(.sequence([.fadeAlpha(to: 0.25, duration: 0.09), .fadeAlpha(to: 1, duration: 0.09)]), count: 6))
        updateHUD()
        if health <= 0 { finish(won: false) }
    }

    private func updatePickups(_ dt: TimeInterval) {
        let rect = CGRect(x: player.position.x - 27, y: player.position.y, width: 54, height: 108).insetBy(dx: -12, dy: -12)
        for node in pickups.reversed() {
            if rect.contains(node.position) { collect(node) }
        }
        if puppy != nil, abs(player.position.x - level.puppyPosition.x) < 62, player.position.y < 175 { rescuePuppy() }
    }

    private func collect(_ node: SKNode) {
        guard let index = pickups.firstIndex(where: { $0 === node }), let raw = node.name, let style = PickupStyle(rawValue: raw) else { return }
        pickups.remove(at: index)
        let value = style == .goldenHeart ? 3 : style == .letter ? 2 : 1
        let base = style == .goldenHeart ? 500 : style == .letter ? 750 : 100
        combo = comboTime > 0 ? min(combo + 1, 8) : 1
        comboTime = 2.4
        love += value
        score += base * min(combo, 5)
        if style == .goldenHeart { invincible = max(invincible, 3) }
        if style == .letter { health = min(3, health + 1) }
        player.setSmileLevel(min(5, love / 4))
        burst(at: node.position, colors: style == .goldenHeart ? [.yellow, .white, .systemPink] : [.systemPink, .white], count: 18)
        node.removeFromParent()
        UIImpactFeedbackGenerator(style: style == .goldenHeart ? .heavy : .light).impactOccurred()
        updateHUD()
    }

    private func rescuePuppy() {
        guard let puppy else { return }
        self.puppy = nil
        rescued += 1
        score += 2_500
        direction = 0
        velocity = .zero
        setControls(hidden: true)
        burst(at: CGPoint(x: puppy.position.x, y: puppy.position.y + 80), colors: [.systemPink, .yellow, .white], count: 30)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if levelIndex == LevelDefinition.all.count - 1 { finish(won: true); return }
        let name = level.puppyName
        levelIndex += 1
        buildLevel()
        state = .intro
        setControls(hidden: true)
        showPanel(title: "\(name.uppercased()) RESCUED!", lines: ["Next: \(level.name)", level.tagline], action: "TAP FOR LEVEL \(levelIndex + 1)")
    }

    private func finish(won: Bool) {
        state = .finished
        direction = 0
        velocity = .zero
        setControls(hidden: true)
        let best = UserDefaults.standard.integer(forKey: "LoveRun.bestScore")
        if score > best { UserDefaults.standard.set(score, forKey: "LoveRun.bestScore") }
        showPanel(
            title: won ? "ICONIC. ALL PUPPIES SAVED." : "CROWN SLIPPED. RESET.",
            lines: won ? ["Three worlds conquered. Score: \(score)", "Love won—and looked fabulous doing it."] : ["The garden fought back. Score: \(score)", "Gloss up and run it again."],
            action: "TAP TO RUN AGAIN"
        )
    }

    private func updateCamera() {
        let lead = direction >= 0 ? size.width * 0.15 : -size.width * 0.08
        let target = max(size.width / 2, min(level.worldWidth - size.width / 2, player.position.x + lead))
        cameraNode.position.x += (target - cameraNode.position.x) * 0.085
    }

    private func updateHUD() {
        scoreLabel.text = "SCORE \(score)"
        healthLabel.text = String(repeating: "♥ ", count: max(0, health))
        levelLabel.text = "LEVEL \(levelIndex + 1)  •  \(level.name)"
        comboLabel.text = combo > 1 ? "×\(combo) COMBO" : ""
        puppyLabel.text = "PUPPIES \(rescued)/3"
        loveFill.xScale = max(0.015, min(1, CGFloat(love) / CGFloat(totalLove)))
    }

    private func showPanel(title: String, lines: [String], action: String) {
        messages.removeAllChildren()
        let glow = SKShapeNode(rectOf: CGSize(width: 668, height: 272), cornerRadius: 34)
        glow.fillColor = UIColor(red: 1, green: 0.04, blue: 0.49, alpha: 0.14)
        glow.strokeColor = UIColor(red: 1, green: 0.24, blue: 0.66, alpha: 0.6)
        glow.lineWidth = 10
        glow.glowWidth = 12
        glow.zPosition = 198
        messages.addChild(glow)
        let panel = SKShapeNode(rectOf: CGSize(width: 642, height: 246), cornerRadius: 28)
        panel.fillColor = UIColor(red: 0.14, green: 0.01, blue: 0.20, alpha: 0.94)
        panel.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.16, alpha: 1)
        panel.lineWidth = 3
        panel.zPosition = 200
        messages.addChild(panel)
        let heart = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        heart.text = "♥"
        heart.fontSize = 43
        heart.fontColor = .systemPink
        heart.position.y = 68
        heart.zPosition = 202
        messages.addChild(heart)
        let heading = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        heading.text = title
        heading.fontSize = title.count > 23 ? 24 : 35
        heading.fontColor = .white
        heading.position.y = 28
        heading.zPosition = 202
        messages.addChild(heading)
        for (index, text) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = text
            label.fontSize = 16
            label.fontColor = UIColor(red: 1, green: 0.67, blue: 0.84, alpha: 1)
            label.position.y = -12 - CGFloat(index) * 23
            label.zPosition = 202
            messages.addChild(label)
        }
        let tap = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        tap.text = action
        tap.fontSize = 17
        tap.fontColor = .yellow
        tap.position.y = -91
        tap.zPosition = 202
        tap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.48, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        messages.addChild(tap)
    }

    private func makeHeart(golden: Bool) -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -16))
        path.addCurve(to: CGPoint(x: -27, y: 6), control1: CGPoint(x: -8, y: -5), control2: CGPoint(x: -27, y: -3))
        path.addCurve(to: CGPoint(x: 0, y: 22), control1: CGPoint(x: -27, y: 24), control2: CGPoint(x: -8, y: 28))
        path.addCurve(to: CGPoint(x: 27, y: 6), control1: CGPoint(x: 8, y: 28), control2: CGPoint(x: 27, y: 24))
        path.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: 27, y: -3), control2: CGPoint(x: 8, y: -5))
        path.closeSubpath()
        let heart = SKShapeNode(path: path)
        heart.fillColor = golden ? .yellow : UIColor(red: 1, green: 0.04, blue: 0.47, alpha: 1)
        heart.strokeColor = .white
        heart.lineWidth = golden ? 3 : 2
        heart.glowWidth = golden ? 8 : 3
        return heart
    }

    private func makeLetter() -> SKNode {
        let root = SKNode()
        let envelope = SKShapeNode(rectOf: CGSize(width: 42, height: 29), cornerRadius: 4)
        envelope.fillColor = UIColor(red: 1, green: 0.90, blue: 0.94, alpha: 1)
        envelope.strokeColor = .yellow
        envelope.lineWidth = 2.5
        root.addChild(envelope)
        let seal = SKShapeNode(circleOfRadius: 7)
        seal.fillColor = .systemPink
        seal.strokeColor = .white
        root.addChild(seal)
        return root
    }

    private func burst(at position: CGPoint, colors: [UIColor], count: Int) {
        for index in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            dot.fillColor = colors[index % colors.count]
            dot.strokeColor = .clear
            dot.position = position
            dot.zPosition = 50
            world.addChild(dot)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            let distance = CGFloat.random(in: 35...90)
            dot.run(.sequence([.group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.46), .fadeOut(withDuration: 0.46), .scale(to: 0.15, duration: 0.46)]), .removeFromParent()]))
        }
    }

    private func triangle(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        path.closeSubpath()
        return path
    }
}
