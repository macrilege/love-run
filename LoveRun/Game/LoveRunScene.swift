import SpriteKit
import UIKit

final class LoveRunScene: SKScene {
    private enum State { case title, ready, playing, celebrating, transition, finished }
    private final class Surface {
        var rect: CGRect
        weak var node: SKNode?
        let behavior: PlatformBehavior
        let baseX: CGFloat
        let phase: CGFloat
        var active = true
        var crumbling = false

        init(rect: CGRect, node: SKNode, behavior: PlatformBehavior, phase: CGFloat) {
            self.rect = rect
            self.node = node
            self.behavior = behavior
            self.baseX = rect.midX
            self.phase = phase
        }
    }

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
    private var puppyNodes: [SKSpriteNode] = []
    private var rescuedInLevel: Set<Int> = []
    private var surfaces: [Surface] = []
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
    private let healthHUD = SKNode()
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let puppyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let loveFrame = SKSpriteNode()
    private let loveFill = SKSpriteNode()
    private let loveFillMask = SKSpriteNode(color: .white, size: CGSize(width: 190, height: 34))
    private let loveFillCrop = SKCropNode()
    private let leftButton = SKSpriteNode(texture: LoveRunScene.controlTexture(index: 0))
    private let rightButton = SKSpriteNode(texture: LoveRunScene.controlTexture(index: 1))
    private let jumpButton = SKSpriteNode(texture: LoveRunScene.controlTexture(index: 2))

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
                rescued = levelIndex * 2
                buildLevel()
                startReadySequence()
            }
            if ProcessInfo.processInfo.environment["LOVE_RUN_START_AT_PUPPY"] == "1" {
                player.position.x = level.puppies[0].position.x - 105
                cameraNode.position.x = player.position.x
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
        showPanel(title: "LOVE RUN", lines: ["6 WORLDS • 12 PUPPIES • MAXIMUM GLAMOUR", "Run, leap, collect, and bring the whole pack home."], action: "TAP TO SERVE")
    }

    private func newRun() {
        levelIndex = 0
        rescued = 0
        health = 3
        score = 0
        buildLevel()
        startReadySequence()
    }

    private func buildLevel() {
        world.removeAllChildren()
        pickups.removeAll()
        surfaces.removeAll()
        puppyNodes.removeAll()
        rescuedInLevel.removeAll()
        heldTouches.removeAll()
        backdrop.texture = SKTexture(imageNamed: level.backgroundAsset)
        backdrop.texture?.filteringMode = .linear
        buildGround()
        buildPetals()
        level.platforms.forEach(buildPlatform)
        level.hazards.forEach(buildHazard)
        level.bouncePads.forEach(buildBouncePad)
        level.pickups.forEach(buildPickup)
        buildPuppies()
        buildFriend()
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
        player.updateAnimation(deltaTime: 0, moving: false, airborne: false, facing: 1)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        updateHUD()
    }

    private func startReadySequence() {
        messages.removeAllChildren()
        state = .ready
        direction = 0
        velocity = .zero
        player.standStill(facing: facing)
        setControls(hidden: true)
        showStageCard()
        run(.sequence([
            .wait(forDuration: 1.05),
            .run { [weak self] in self?.showCountdown("GO!", color: .yellow) },
            .wait(forDuration: 0.45),
            .run { [weak self] in
                guard let self else { return }
                self.messages.removeAllChildren()
                self.state = .playing
                self.direction = ProcessInfo.processInfo.environment["LOVE_RUN_AUTORUN"] == "1" ? 1 : 0
                self.setControls(hidden: false)
            }
        ]), withKey: "readySequence")
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
        let root = SKNode()
        root.position = CGPoint(x: spec.rect.midX, y: spec.rect.midY)
        root.zPosition = 11
        let cell: (Int, Int)
        switch spec.style {
        case .stone: cell = (3, 1)
        case .picnic: cell = (0, 2)
        case .cloud: cell = (1, 2)
        }
        let texture = Self.objectTexture(column: cell.0, row: cell.1, crop: CGRect(x: 0.02, y: 0.18, width: 0.96, height: 0.62))
        let platform = SKSpriteNode(texture: texture)
        platform.anchorPoint = CGPoint(x: 0.5, y: 0.78)
        platform.size = CGSize(width: spec.rect.width + 14, height: spec.style == .cloud ? 66 : 58)
        platform.position.y = spec.rect.height / 2 + 4
        root.addChild(platform)
        if spec.behavior != .fixed {
            let badge = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            badge.text = spec.behavior == .moving ? "↔" : "✦"
            badge.fontSize = 18
            badge.fontColor = spec.behavior == .moving ? .cyan : .yellow
            badge.position.y = 17
            root.addChild(badge)
        }
        world.addChild(root)
        surfaces.append(Surface(rect: spec.rect, node: root, behavior: spec.behavior, phase: CGFloat(surfaces.count) * 0.73))
    }

    private func buildHazard(_ spec: HazardSpec) {
        let root = SKNode()
        root.position = CGPoint(x: spec.rect.midX, y: spec.rect.midY)
        root.zPosition = 15
        let cell: (Int, Int)
        let displaySize: CGSize
        switch spec.style {
        case .puddle:
            cell = (0, 1)
            displaySize = CGSize(width: spec.rect.width + 24, height: 42)
        case .hedge:
            cell = (1, 1)
            displaySize = CGSize(width: spec.rect.width + 24, height: spec.rect.height + 34)
        case .thorns:
            cell = (2, 1)
            displaySize = CGSize(width: spec.rect.width + 28, height: 62)
        }
        let hazard = SKSpriteNode(texture: Self.objectTexture(column: cell.0, row: cell.1))
        hazard.anchorPoint = CGPoint(x: 0.5, y: 0)
        hazard.size = displaySize
        hazard.position.y = -spec.rect.height / 2
        root.addChild(hazard)
        world.addChild(root)
    }

    private func buildBouncePad(_ point: CGPoint) {
        let root = SKNode()
        root.position = point
        root.zPosition = 17
        let flower = SKSpriteNode(texture: Self.objectTexture(column: 3, row: 0))
        flower.anchorPoint = CGPoint(x: 0.5, y: 0)
        flower.size = CGSize(width: 82, height: 82)
        root.addChild(flower)
        root.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.45), .scale(to: 1, duration: 0.45)])))
        world.addChild(root)
    }

    private func buildPickup(_ spec: PickupSpec) {
        let node: SKSpriteNode
        switch spec.style {
        case .heart:
            node = SKSpriteNode(texture: Self.objectTexture(column: 0, row: 0))
            node.size = CGSize(width: 62, height: 62)
        case .goldenHeart:
            node = SKSpriteNode(texture: Self.objectTexture(column: 1, row: 0))
            node.size = CGSize(width: 76, height: 76)
        case .letter:
            node = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 0))
            node.size = CGSize(width: 67, height: 58)
        }
        node.name = spec.style.rawValue
        node.position = spec.position
        node.zPosition = 28
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 0.55), .moveBy(x: 0, y: -7, duration: 0.55)])))
        world.addChild(node)
        pickups.append(node)
    }

    private func buildPuppies() {
        for (index, spec) in level.puppies.enumerated() {
            let node = SKSpriteNode(texture: Self.puppyTexture(frame: spec.frame))
            node.name = "puppy\(index)"
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.size = CGSize(width: 96, height: 96)
            node.position = CGPoint(x: spec.position.x, y: groundY - 4)
            node.zPosition = 25
            let aura = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 2))
            aura.size = CGSize(width: 112, height: 112)
            aura.position.y = 48
            aura.zPosition = -1
            aura.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.7), .scale(to: 0.94, duration: 0.7)])))
            node.addChild(aura)
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.45), .moveBy(x: 0, y: -5, duration: 0.45)])))
            world.addChild(node)
            puppyNodes.append(node)

            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.name = "puppyLabel\(index)"
            label.text = "RESCUE \(spec.name.uppercased())"
            label.fontSize = 14
            label.fontColor = .yellow
            label.position = CGPoint(x: spec.position.x, y: 164)
            label.zPosition = 30
            world.addChild(label)
        }
    }

    private func buildFriend() {
        let friend = SKSpriteNode(texture: Self.friendTexture(frame: level.friendFrame))
        friend.anchorPoint = CGPoint(x: 0.5, y: 0)
        friend.size = CGSize(width: 104, height: 139)
        friend.position = CGPoint(x: level.puppies[1].position.x - 155, y: groundY - 5)
        friend.zPosition = 22
        friend.run(.repeatForever(.sequence([
            .rotate(toAngle: -0.025, duration: 0.55),
            .rotate(toAngle: 0.025, duration: 0.55)
        ])))
        world.addChild(friend)
    }

    private func buildHUD() {
        scoreLabel.fontSize = 21
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -394, y: 157)
        healthHUD.position = CGPoint(x: -375, y: 132)
        healthHUD.zPosition = 105
        for index in 0..<3 {
            let heart = SKSpriteNode(texture: Self.objectTexture(column: 0, row: 0))
            heart.name = "healthHeart\(index)"
            heart.size = CGSize(width: 29, height: 29)
            heart.position.x = CGFloat(index) * 30
            healthHUD.addChild(heart)
        }
        hud.addChild(healthHUD)
        levelLabel.fontSize = 14
        levelLabel.position = CGPoint(x: 0, y: 165)
        comboLabel.fontSize = 16
        comboLabel.fontColor = .yellow
        comboLabel.position = CGPoint(x: 276, y: 146)
        puppyLabel.fontSize = 14
        puppyLabel.horizontalAlignmentMode = .right
        puppyLabel.position = CGPoint(x: 394, y: 165)
        [scoreLabel, levelLabel, comboLabel, puppyLabel].forEach { $0.zPosition = 105; hud.addChild($0) }
        loveFrame.texture = Self.meterTexture(cell: 0)
        loveFrame.size = CGSize(width: 278, height: 62)
        loveFrame.position = CGPoint(x: 0, y: 139)
        loveFrame.zPosition = 102
        hud.addChild(loveFrame)
        loveFill.texture = Self.meterTexture(cell: 1)
        loveFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        loveFill.size = CGSize(width: 190, height: 34)
        loveFill.position = CGPoint(x: -78, y: 0)
        loveFill.zPosition = 104
        loveFillMask.anchorPoint = CGPoint(x: 0, y: 0.5)
        loveFillMask.position = CGPoint(x: -78, y: 0)
        loveFillCrop.position = CGPoint(x: 0, y: 139)
        loveFillCrop.zPosition = 104
        loveFillCrop.maskNode = loveFillMask
        loveFillCrop.addChild(loveFill)
        hud.addChild(loveFillCrop)
        configure(leftButton, at: CGPoint(x: -352, y: -132), size: CGSize(width: 82, height: 82))
        configure(rightButton, at: CGPoint(x: -264, y: -132), size: CGSize(width: 82, height: 82))
        configure(jumpButton, at: CGPoint(x: 342, y: -128), size: CGSize(width: 136, height: 99))
    }

    private func configure(_ button: SKSpriteNode, at position: CGPoint, size: CGSize) {
        button.position = position
        button.size = size
        button.alpha = 0.9
        button.zPosition = 110
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
        case .finished: showTitle()
        case .playing:
            touches.forEach { heldTouches[$0] = $0.location(in: cameraNode) }
            readControls()
        case .ready, .celebrating, .transition: break
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
        leftButton.setScale(direction < 0 ? 1.12 : 1)
        rightButton.setScale(direction > 0 ? 1.12 : 1)
        jumpButton.setScale(wantsJump ? 1.1 : 1)
        leftButton.alpha = direction < 0 ? 1 : 0.9
        rightButton.alpha = direction > 0 ? 1 : 0.9
        jumpButton.alpha = wantsJump ? 1 : 0.9
    }

    override func update(_ currentTime: TimeInterval) {
        guard state == .playing else { previousTime = currentTime; return }
        let dt = min(previousTime == 0 ? 1 / 60 : currentTime - previousTime, 1 / 30)
        previousTime = currentTime
        invincible = max(0, invincible - dt)
        comboTime = max(0, comboTime - dt)
        if comboTime == 0, combo > 0 { combo = 0; updateHUD() }
        updatePlatforms(currentTime)
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
            var landedSurface: Surface?
            for surface in surfaces where surface.active {
                let rect = surface.rect
                if maxX > rect.minX && minX < rect.maxX && oldY >= rect.maxY - 2 && nextY <= rect.maxY {
                    if rect.maxY >= landing ?? -.greatestFiniteMagnitude {
                        landing = rect.maxY
                        landedSurface = surface
                    }
                }
            }
            if let landing {
                if velocity.dy < -190 { player.squashForLanding() }
                nextY = landing
                velocity.dy = 0
                grounded = true
                if let landedSurface, landedSurface.behavior == .crumbling { crumble(landedSurface) }
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
        player.updateAnimation(deltaTime: dt, moving: direction != 0, airborne: !grounded, facing: facing, verticalVelocity: velocity.dy)
    }

    private func updatePlatforms(_ currentTime: TimeInterval) {
        for surface in surfaces where surface.active && surface.behavior == .moving {
            let centerX = surface.baseX + sin(CGFloat(currentTime) * 1.25 + surface.phase) * 48
            surface.node?.position.x = centerX
            surface.rect.origin.x = centerX - surface.rect.width / 2
        }
    }

    private func crumble(_ surface: Surface) {
        guard !surface.crumbling else { return }
        surface.crumbling = true
        surface.node?.run(.sequence([
            .repeat(.sequence([.rotate(byAngle: 0.035, duration: 0.055), .rotate(byAngle: -0.07, duration: 0.055), .rotate(byAngle: 0.035, duration: 0.055)]), count: 3),
            .group([.moveBy(x: 0, y: -55, duration: 0.32), .fadeOut(withDuration: 0.32)]),
            .run { surface.active = false }
        ]))
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
        for (index, puppy) in puppyNodes.enumerated() where !rescuedInLevel.contains(index) {
            if abs(player.position.x - puppy.position.x) < 68, player.position.y < 175 {
                rescuePuppy(index: index)
                break
            }
        }
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

    private func rescuePuppy(index: Int) {
        guard puppyNodes.indices.contains(index), !rescuedInLevel.contains(index) else { return }
        let puppy = puppyNodes[index]
        let spec = level.puppies[index]
        rescuedInLevel.insert(index)
        rescued += 1
        score += 2_500
        state = .celebrating
        direction = 0
        velocity = .zero
        player.standStill(facing: facing)
        setControls(hidden: true)
        burst(at: CGPoint(x: puppy.position.x, y: puppy.position.y + 80), colors: [.systemPink, .yellow, .white], count: 30)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        world.childNode(withName: "puppyLabel\(index)")?.removeFromParent()
        puppy.removeAllActions()
        puppy.run(.sequence([
            .group([.move(to: CGPoint(x: player.position.x + 58 * facing, y: player.position.y + 5), duration: 0.45), .scale(to: 1.2, duration: 0.45)]),
            .repeat(.sequence([.moveBy(x: 0, y: 16, duration: 0.15), .moveBy(x: 0, y: -16, duration: 0.15)]), count: 3),
            .fadeOut(withDuration: 0.25)
        ]))
        showRescueCelebration(name: spec.name)
        run(.sequence([
            .wait(forDuration: 2.65),
            .run { [weak self] in self?.completeRescue() }
        ]), withKey: "rescueCelebration")
    }

    private func completeRescue() {
        messages.removeAllChildren()
        if rescued == 12 { finish(won: true); return }
        if rescuedInLevel.count < level.puppies.count {
            startReadySequence()
            return
        }
        transitionToNextLevel()
    }

    private func transitionToNextLevel() {
        state = .transition
        setControls(hidden: true)
        let veil = SKSpriteNode(color: UIColor(red: 0.95, green: 0.03, blue: 0.48, alpha: 1), size: size)
        veil.alpha = 0
        veil.zPosition = 500
        cameraNode.addChild(veil)
        veil.run(.sequence([
            .fadeIn(withDuration: 0.72),
            .run { [weak self] in
                guard let self else { return }
                self.levelIndex += 1
                self.buildLevel()
            },
            .fadeOut(withDuration: 0.83),
            .removeFromParent(),
            .run { [weak self] in self?.startReadySequence() }
        ]))
    }

    private func finish(won: Bool) {
        state = .finished
        direction = 0
        velocity = .zero
        setControls(hidden: true)
        let best = UserDefaults.standard.integer(forKey: "LoveRun.bestScore")
        if score > best { UserDefaults.standard.set(score, forKey: "LoveRun.bestScore") }
        showPanel(
            title: won ? "ICONIC. THE PACK IS HOME." : "CROWN SLIPPED. RESET.",
            lines: won ? ["Six worlds conquered. Twelve puppies rescued. Score: \(score)", "Love won—and looked fabulous doing it."] : ["The garden fought back. Score: \(score)", "Gloss up and run it again."],
            action: "TAP TO RUN AGAIN"
        )
        if won { showFinalParade() }
    }

    private func updateCamera() {
        let lead = direction >= 0 ? size.width * 0.15 : -size.width * 0.08
        let target = max(size.width / 2, min(level.worldWidth - size.width / 2, player.position.x + lead))
        cameraNode.position.x += (target - cameraNode.position.x) * 0.085
    }

    private func updateHUD() {
        scoreLabel.text = "SCORE \(score)"
        for index in 0..<3 {
            healthHUD.childNode(withName: "healthHeart\(index)")?.isHidden = index >= health
        }
        levelLabel.text = "LEVEL \(levelIndex + 1)  •  \(level.name)"
        comboLabel.text = combo > 1 ? "×\(combo) COMBO" : ""
        puppyLabel.text = "PUPPIES \(rescued)/12"
        loveFillMask.xScale = max(0.015, min(1, CGFloat(love) / CGFloat(totalLove)))
    }

    private func showStageCard() {
        messages.removeAllChildren()
        let frame = SKSpriteNode(texture: SKTexture(imageNamed: "CelebrationFrame"))
        frame.size = CGSize(width: 520, height: 265)
        frame.zPosition = 190
        messages.addChild(frame)
        let eyebrow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        eyebrow.text = "WORLD \(levelIndex + 1) • READY"
        eyebrow.fontSize = 18
        eyebrow.fontColor = .yellow
        eyebrow.position.y = 50
        eyebrow.zPosition = 192
        messages.addChild(eyebrow)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = level.name
        title.fontSize = level.name.count > 20 ? 25 : 31
        title.fontColor = .white
        title.position.y = 10
        title.zPosition = 192
        messages.addChild(title)
        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = level.tagline
        subtitle.fontSize = 15
        subtitle.fontColor = UIColor(red: 1, green: 0.66, blue: 0.84, alpha: 1)
        subtitle.position.y = -25
        subtitle.zPosition = 192
        messages.addChild(subtitle)
        messages.setScale(0.7)
        messages.alpha = 0
        messages.run(.group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.28)]))
    }

    private func showCountdown(_ text: String, color: UIColor) {
        messages.removeAllChildren()
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 82
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.zPosition = 250
        label.setScale(0.35)
        messages.addChild(label)
        label.run(.group([.scale(to: 1.2, duration: 0.22), .fadeOut(withDuration: 0.42)]))
    }

    private func showRescueCelebration(name: String) {
        messages.removeAllChildren()
        let flash = SKSpriteNode(color: .white, size: size)
        flash.alpha = 0.75
        flash.zPosition = 180
        messages.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        let frame = SKSpriteNode(texture: SKTexture(imageNamed: "CelebrationFrame"))
        frame.size = CGSize(width: 560, height: 286)
        frame.zPosition = 200
        frame.setScale(0.4)
        messages.addChild(frame)
        frame.run(.sequence([.scale(to: 1.08, duration: 0.22), .scale(to: 1, duration: 0.12)]))
        let heading = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        heading.text = "\(name.uppercased()) RESCUED!"
        heading.fontSize = 36
        heading.fontColor = .white
        heading.position.y = 18
        heading.zPosition = 202
        messages.addChild(heading)
        let progress = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        progress.text = "PUPPY \(rescued) OF 12 • +2500"
        progress.fontSize = 18
        progress.fontColor = .yellow
        progress.position.y = -25
        progress.zPosition = 202
        messages.addChild(progress)
        cameraNode.run(.sequence([
            .moveBy(x: -9, y: 4, duration: 0.05), .moveBy(x: 17, y: -8, duration: 0.05),
            .moveBy(x: -12, y: 6, duration: 0.05), .moveBy(x: 4, y: -2, duration: 0.05)
        ]))
    }

    private func showFinalParade() {
        for frame in 0..<12 {
            let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: frame))
            puppy.size = CGSize(width: 62, height: 62)
            puppy.position = CGPoint(x: -340 + CGFloat(frame) * 62, y: -142)
            puppy.zPosition = 196
            puppy.alpha = 0
            messages.addChild(puppy)
            puppy.run(.sequence([.wait(forDuration: Double(frame) * 0.055), .fadeIn(withDuration: 0.15), .repeat(.sequence([.moveBy(x: 0, y: 9, duration: 0.18), .moveBy(x: 0, y: -9, duration: 0.18)]), count: 5)]))
        }
        burst(at: CGPoint(x: player.position.x, y: 185), colors: [.systemPink, .yellow, .white, .cyan], count: 80)
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
        let heart = SKSpriteNode(texture: Self.objectTexture(column: 0, row: 0))
        heart.size = CGSize(width: 58, height: 58)
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

    private static func objectTexture(column: Int, row: Int, crop: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> SKTexture {
        let sheet = SKTexture(imageNamed: "RomanceObjects")
        let cellWidth: CGFloat = 1 / 4
        let cellHeight: CGFloat = 1 / 3
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) * cellWidth + crop.minX * cellWidth,
                y: CGFloat(2 - row) * cellHeight + crop.minY * cellHeight,
                width: crop.width * cellWidth,
                height: crop.height * cellHeight
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private static func meterTexture(cell: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "LoveMeter")
        let texture = SKTexture(
            rect: CGRect(x: CGFloat(cell) / 2 + 0.01, y: 0.36, width: 0.48, height: 0.28),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private static func puppyTexture(frame: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "PuppyParade")
        let column = frame % 4
        let row = frame / 4
        let texture = SKTexture(
            rect: CGRect(x: CGFloat(column) / 4, y: CGFloat(2 - row) / 3, width: 1 / 4, height: 1 / 3),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private static func friendTexture(frame: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "SupportingCast")
        let inset: CGFloat = 0.012
        let texture = SKTexture(
            rect: CGRect(x: CGFloat(frame) / 4 + inset, y: 0.03, width: 0.25 - inset * 2, height: 0.94),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private static func controlTexture(index: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "CrystalControls")
        let rects = [
            CGRect(x: 0, y: 0, width: 0.29, height: 1),
            CGRect(x: 0.29, y: 0, width: 0.29, height: 1),
            CGRect(x: 0.56, y: 0, width: 0.44, height: 1)
        ]
        let texture = SKTexture(rect: rects[index], in: sheet)
        texture.filteringMode = .linear
        return texture
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

}
