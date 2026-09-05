import SpriteKit
import UIKit
import AVFoundation

final class LoveRunScene: SKScene {
    private enum State { case title, missionSelect, sanctuary, ready, playing, rescuing, results }
    private enum RunPhase { case approach, escape }

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
    private let transitionBackdrop = SKSpriteNode()
    private let tint = SKSpriteNode(color: UIColor(red: 0.32, green: 0.01, blue: 0.30, alpha: 0.08), size: CGSize(width: 900, height: 430))
    private let hud = SKNode()
    private let overlay = SKNode()
    private let player = PlayerNode()
    private let groundY: CGFloat = 58

    private var state: State = .title
    private var phase: RunPhase = .approach
    private var missionIndex = 0
    private var health = 3
    private var letters = 0
    private var hearts = 0
    private var totalHearts = 1
    private var damageTaken = 0
    private var checkpointX: CGFloat = 125
    private var activatedCheckpoints: Set<Int> = []
    private var surfaces: [Surface] = []
    private var pickups: [SKNode] = []
    private var puppyNode: SKSpriteNode?
    private var rescuedPuppy: SKSpriteNode?
    private var velocity = CGVector.zero
    private var grounded = true
    private var jumpBuffer: TimeInterval = 0
    private var coyoteTime: TimeInterval = 0.1
    private var jumpHoldTime: TimeInterval = 0
    private var jumpHeld = false
    private var airTwirlAvailable = true
    private var slideTime: TimeInterval = 0
    private var invincibleTime: TimeInterval = 0
    private var companionShield = false
    private var previousTime: TimeInterval = 0
    private var backgroundStage = 0
    private var backgroundTransitioning = false
    private var touchStarts: [UITouch: CGPoint] = [:]
    private var currentLevel: LevelDefinition { LevelDefinition.all[missionIndex] }

    private let healthHUD = SKNode()
    private let letterHUD = SKNode()
    private let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let missionLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let progressFill = SKSpriteNode(color: UIColor(red: 1, green: 0.18, blue: 0.62, alpha: 1), size: CGSize(width: 190, height: 6))
    private let progressPuppy = SKSpriteNode()
    private let jumpButton = SKSpriteNode(texture: LoveRunScene.controlTexture(index: 2))
    private let actionButton = SKSpriteNode(texture: LoveRunScene.objectTexture(column: 1, row: 0))
    private let sound = TonePlayer()

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.12, green: 0.01, blue: 0.18, alpha: 1)
        physicsWorld.gravity = .zero
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
        addChild(world)
        addChild(cameraNode)
        camera = cameraNode
        backdrop.size = CGSize(width: size.width, height: size.width * 941 / 1_672)
        backdrop.zPosition = -100
        cameraNode.addChild(backdrop)
        transitionBackdrop.size = backdrop.size
        transitionBackdrop.zPosition = -99
        transitionBackdrop.alpha = 0
        cameraNode.addChild(transitionBackdrop)
        tint.zPosition = -90
        cameraNode.addChild(tint)
        cameraNode.addChild(hud)
        cameraNode.addChild(overlay)
        buildHUD()
        showTitle()

        if ProcessInfo.processInfo.environment["LOVE_RUN_START_SCREEN"] == "missions" {
            showMissionSelect()
        } else if ProcessInfo.processInfo.environment["LOVE_RUN_START_SCREEN"] == "sanctuary" {
            showSanctuary()
        } else if ProcessInfo.processInfo.environment["LOVE_RUN_AUTOSTART"] == "1" {
            let requested = Int(ProcessInfo.processInfo.environment["LOVE_RUN_START_MISSION"] ?? "0") ?? 0
            startMission(min(max(0, requested), LevelDefinition.all.count - 1))
            if let rawX = ProcessInfo.processInfo.environment["LOVE_RUN_START_X"], let x = Double(rawX) {
                player.position.x = CGFloat(x)
                cameraNode.position.x = max(size.width / 2, player.position.x)
            }
            if let rawLetters = ProcessInfo.processInfo.environment["LOVE_RUN_START_LETTERS"], let count = Int(rawLetters) {
                letters = min(3, max(0, count))
            }
            if ProcessInfo.processInfo.environment["LOVE_RUN_SKIP_READY"] == "1" {
                removeAction(forKey: "ready")
                overlay.removeAllChildren()
                state = .playing
                setControls(hidden: false)
                updateHUD()
            }
            if ProcessInfo.processInfo.environment["LOVE_RUN_PREVIEW_TWIRL"] == "1" {
                player.run(.repeatForever(.sequence([
                    .run { [weak self] in self?.player.performTwirl() },
                    .wait(forDuration: 0.65)
                ])), withKey: "previewTwirl")
            }
        }
    }

    private func showTitle() {
        state = .title
        missionIndex = 0
        buildShowcase(showCast: true)
        hud.isHidden = true
        overlay.removeAllChildren()
        addVeil(alpha: 0.30)
        let frame = makePanel(size: CGSize(width: 620, height: 286))
        overlay.addChild(frame)
        addText("LOVE RUN", fontSize: 52, color: .white, y: 72, parent: overlay)
        addText("GLAM RESCUE", fontSize: 21, color: .yellow, y: 35, parent: overlay)
        addText("RUN FIERCE  •  RESCUE SWEET", fontSize: 15, color: UIColor(red: 1, green: 0.70, blue: 0.87, alpha: 1), y: 3, parent: overlay)
        addText("Three handcrafted missions await in Blooming Park", fontSize: 14, color: .white, y: -27, parent: overlay)
        let play = makeButton(title: "ENTER BLOOMING PARK", width: 300, name: "menu:missions")
        play.position.y = -77
        overlay.addChild(play)
        addText("TAP TO BEGIN", fontSize: 12, color: .yellow, y: -125, parent: overlay)
    }

    private func buildShowcase(showCast: Bool) {
        world.removeAllChildren()
        backdrop.texture = SKTexture(imageNamed: "BloomingPark")
        backdrop.texture?.filteringMode = .linear
        transitionBackdrop.removeAllActions()
        transitionBackdrop.alpha = 0
        tint.color = UIColor(red: 1, green: 0.72, blue: 0.86, alpha: 0.25)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let floor = SKSpriteNode(color: UIColor(red: 0.25, green: 0.01, blue: 0.20, alpha: 0.55), size: CGSize(width: size.width, height: 62))
        floor.anchorPoint = .zero
        floor.position = .zero
        floor.zPosition = 3
        world.addChild(floor)
        if showCast {
            player.removeFromParent()
            player.position = CGPoint(x: 225, y: 58)
            player.standStill(facing: 1)
            world.addChild(player)
            for index in 0..<3 {
                let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: index))
                puppy.anchorPoint = CGPoint(x: 0.5, y: 0)
                puppy.size = CGSize(width: 82, height: 82)
                puppy.position = CGPoint(x: 540 + CGFloat(index) * 78, y: 54)
                puppy.zPosition = 22
                puppy.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.4 + Double(index) * 0.05), .moveBy(x: 0, y: -5, duration: 0.4 + Double(index) * 0.05)])))
                world.addChild(puppy)
            }
        }
    }

    private func showMissionSelect() {
        state = .missionSelect
        buildShowcase(showCast: false)
        hud.isHidden = true
        overlay.removeAllChildren()
        addVeil(alpha: 0.42)
        addText("BLOOMING PARK", fontSize: 34, color: .white, y: 145, parent: overlay)
        addText("Choose a rescue mission", fontSize: 15, color: UIColor(red: 1, green: 0.70, blue: 0.87, alpha: 1), y: 118, parent: overlay)

        for index in LevelDefinition.all.indices {
            let level = LevelDefinition.all[index]
            let unlocked = isMissionUnlocked(index)
            let card = SKShapeNode(rectOf: CGSize(width: 230, height: 210), cornerRadius: 24)
            card.name = unlocked ? "mission:\(index)" : "locked"
            card.position = CGPoint(x: -252 + CGFloat(index) * 252, y: -10)
            card.fillColor = UIColor(red: 0.18, green: 0.015, blue: 0.24, alpha: unlocked ? 0.94 : 0.72)
            card.strokeColor = unlocked ? UIColor(red: 1, green: 0.70, blue: 0.12, alpha: 1) : .gray
            card.lineWidth = unlocked ? 3 : 2
            card.zPosition = 201
            overlay.addChild(card)

            let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: level.puppy.frame))
            puppy.size = CGSize(width: 88, height: 88)
            puppy.position.y = 48
            puppy.alpha = unlocked ? 1 : 0.28
            puppy.zPosition = 1
            card.addChild(puppy)
            addText("MISSION \(index + 1)", fontSize: 12, color: .yellow, y: -6, parent: card)
            addText(level.title, fontSize: level.title.count > 14 ? 17 : 20, color: .white, y: -35, parent: card)
            let crowns = savedCrowns(for: index)
            addText(unlocked ? crownString(crowns) : "LOCKED", fontSize: 20, color: unlocked ? .yellow : .lightGray, y: -72, parent: card)
        }

        let sanctuary = makeButton(title: "PUPPY SANCTUARY", width: 230, name: "menu:sanctuary")
        sanctuary.position.y = -151
        overlay.addChild(sanctuary)
    }

    private func showSanctuary() {
        state = .sanctuary
        world.removeAllChildren()
        backdrop.texture = SKTexture(imageNamed: "BloomingPark")
        transitionBackdrop.removeAllActions()
        transitionBackdrop.alpha = 0
        tint.color = UIColor(red: 1, green: 0.72, blue: 0.86, alpha: 0.27)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        hud.isHidden = true
        overlay.removeAllChildren()
        addVeil(alpha: 0.20)
        let panel = makePanel(size: CGSize(width: 720, height: 310))
        panel.position.y = 6
        overlay.addChild(panel)
        addText("PUPPY SANCTUARY", fontSize: 32, color: .white, y: 126, parent: overlay)
        addText("Every rescue brings the garden back to life", fontSize: 14, color: UIColor(red: 1, green: 0.70, blue: 0.87, alpha: 1), y: 97, parent: overlay)

        for index in LevelDefinition.all.indices {
            let completed = isMissionComplete(index)
            let pedestal = SKSpriteNode(texture: Self.objectTexture(column: index, row: 2))
            pedestal.size = CGSize(width: 185, height: 120)
            pedestal.position = CGPoint(x: -230 + CGFloat(index) * 230, y: -35)
            pedestal.alpha = completed ? 1 : 0.38
            pedestal.zPosition = 202
            overlay.addChild(pedestal)
            let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: index))
            puppy.size = CGSize(width: 110, height: 110)
            puppy.position = CGPoint(x: pedestal.position.x, y: 20)
            puppy.alpha = completed ? 1 : 0.16
            puppy.color = completed ? .white : .black
            puppy.colorBlendFactor = completed ? 0 : 0.8
            puppy.zPosition = 204
            overlay.addChild(puppy)
            addText(completed ? LevelDefinition.all[index].puppy.name.uppercased() : "???", fontSize: 15, color: completed ? .yellow : .lightGray, x: pedestal.position.x, y: -92, parent: overlay)
        }
        let back = makeButton(title: "BACK TO MISSIONS", width: 220, name: "menu:missions")
        back.position.y = -146
        overlay.addChild(back)
    }

    private func startMission(_ index: Int) {
        missionIndex = index
        state = .ready
        phase = .approach
        health = 3
        letters = 0
        hearts = 0
        damageTaken = 0
        companionShield = false
        checkpointX = 125
        activatedCheckpoints.removeAll()
        touchStarts.removeAll()
        jumpHeld = false
        loadMissionWorld()
        updateHUD()
        hud.isHidden = false
        setControls(hidden: true)
        showStageCard()
        run(.sequence([
            .wait(forDuration: 1.15),
            .run { [weak self] in self?.showCountdown() },
            .wait(forDuration: 0.5),
            .run { [weak self] in
                guard let self else { return }
                self.overlay.removeAllChildren()
                self.state = .playing
                self.setControls(hidden: false)
            }
        ]), withKey: "ready")
    }

    private func loadMissionWorld() {
        world.removeAllChildren()
        overlay.removeAllChildren()
        surfaces.removeAll()
        pickups.removeAll()
        puppyNode = nil
        rescuedPuppy = nil
        backdrop.texture = SKTexture(imageNamed: missionBackgrounds[0])
        backdrop.texture?.filteringMode = .linear
        transitionBackdrop.removeAllActions()
        transitionBackdrop.alpha = 0
        backgroundStage = 0
        backgroundTransitioning = false
        let tintColors = [
            UIColor(red: 1, green: 0.88, blue: 0.93, alpha: 0.55),
            UIColor(red: 0.88, green: 0.94, blue: 1, alpha: 0.54),
            UIColor(red: 0.95, green: 0.88, blue: 0.97, alpha: 0.56)
        ]
        tint.color = tintColors[missionIndex]
        buildGround()
        buildAtmosphere()
        currentLevel.platforms.forEach(buildPlatform)
        currentLevel.hazards.forEach(buildHazard)
        currentLevel.bouncePads.forEach(buildBouncePad)
        currentLevel.pickups.forEach(buildPickup)
        buildCheckpoints()
        buildPuppy()
        buildExit()
        player.removeFromParent()
        player.isHidden = false
        player.removeAllActions()
        player.position = CGPoint(x: 125, y: groundY)
        player.alpha = 1
        player.setScale(1)
        player.setSmileLevel(-1)
        player.standStill(facing: 1)
        world.addChild(player)
        velocity = .zero
        grounded = true
        coyoteTime = 0.1
        jumpBuffer = 0
        jumpHoldTime = 0
        airTwirlAvailable = true
        slideTime = 0
        invincibleTime = 0
        previousTime = 0
        totalHearts = max(1, currentLevel.pickups.filter { $0.style != .letter }.count)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func buildGround() {
        let ground = SKSpriteNode(color: UIColor(red: 0.25, green: 0.02, blue: 0.22, alpha: 0.68), size: CGSize(width: currentLevel.worldWidth, height: groundY))
        ground.anchorPoint = .zero
        ground.zPosition = 1
        world.addChild(ground)
        let edge = SKSpriteNode(color: UIColor(red: 1, green: 0.72, blue: 0.12, alpha: 1), size: CGSize(width: currentLevel.worldWidth, height: 3))
        edge.anchorPoint = .zero
        edge.position.y = groundY - 2
        edge.zPosition = 8
        world.addChild(edge)
    }

    private func buildAtmosphere() {
        for index in 0..<Int(currentLevel.worldWidth / 180) {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 6, height: 3))
            petal.fillColor = index.isMultiple(of: 5) ? UIColor.yellow.withAlphaComponent(0.25) : UIColor(red: 1, green: 0.32, blue: 0.69, alpha: 0.20)
            petal.strokeColor = .clear
            petal.position = CGPoint(x: CGFloat(index) * 180 + 55, y: 88 + CGFloat((index * 67) % 230))
            petal.zRotation = CGFloat(index % 7) * 0.45
            petal.zPosition = 4
            petal.run(.repeatForever(.sequence([.moveBy(x: 20, y: -11, duration: 1.8), .moveBy(x: -20, y: 11, duration: 0)])))
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
        let crop = CGRect(x: 0.02, y: 0.18, width: 0.96, height: 0.62)
        let sprite = SKSpriteNode(texture: Self.objectTexture(column: cell.0, row: cell.1, crop: crop))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.78)
        let width = spec.rect.width + 14
        let height = width / (crop.width / crop.height)
        sprite.size = CGSize(width: width, height: height)
        sprite.position.y = spec.rect.height / 2 + (spec.style == .stone ? height * 0.29 : -height * 0.08)
        sprite.color = UIColor(white: 1, alpha: 1)
        sprite.colorBlendFactor = 0.16
        root.addChild(sprite)
        if spec.behavior != .fixed {
            let gem = SKSpriteNode(texture: Self.objectTexture(column: 1, row: 0))
            gem.size = CGSize(width: 24, height: 24)
            gem.position.y = 24
            gem.color = spec.behavior == .moving ? .cyan : .yellow
            gem.colorBlendFactor = 0.35
            root.addChild(gem)
        }
        world.addChild(root)
        surfaces.append(Surface(rect: spec.rect, node: root, behavior: spec.behavior, phase: CGFloat(surfaces.count) * 0.73))
    }

    private func buildHazard(_ spec: HazardSpec) {
        let cell: (Int, Int)
        let displaySize: CGSize
        switch spec.style {
        case .puddle: cell = (0, 1); displaySize = CGSize(width: 105, height: 40)
        case .hedge: cell = (1, 1); displaySize = CGSize(width: 92, height: 78)
        case .thorns: cell = (2, 1); displaySize = CGSize(width: 112, height: 62)
        case .branch: cell = (3, 2); displaySize = CGSize(width: 126, height: 74)
        }
        let node = SKSpriteNode(texture: Self.objectTexture(column: cell.0, row: cell.1))
        node.size = displaySize
        node.position = CGPoint(x: spec.rect.midX, y: spec.rect.midY)
        node.zPosition = 16
        if spec.style == .branch { node.zRotation = .pi }
        world.addChild(node)
    }

    private func buildBouncePad(_ point: CGPoint) {
        let flower = SKSpriteNode(texture: Self.objectTexture(column: 3, row: 0))
        flower.anchorPoint = CGPoint(x: 0.5, y: 0)
        flower.size = CGSize(width: 76, height: 76)
        flower.position = point
        flower.zPosition = 17
        flower.name = "bounce"
        flower.run(.repeatForever(.sequence([.scale(to: 1.07, duration: 0.42), .scale(to: 1, duration: 0.42)])))
        world.addChild(flower)
    }

    private func buildPickup(_ spec: PickupSpec) {
        let cell: (Int, Int)
        let size: CGSize
        switch spec.style {
        case .heart: cell = (0, 0); size = CGSize(width: 30, height: 30)
        case .goldenHeart: cell = (1, 0); size = CGSize(width: 40, height: 40)
        case .letter: cell = (2, 0); size = CGSize(width: 44, height: 44)
        }
        let node = SKSpriteNode(texture: Self.objectTexture(column: cell.0, row: cell.1))
        node.name = spec.style.rawValue
        node.size = size
        node.position = spec.position
        node.zPosition = 27
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.5), .moveBy(x: 0, y: -6, duration: 0.5)])))
        world.addChild(node)
        pickups.append(node)
    }

    private func buildCheckpoints() {
        for (index, x) in currentLevel.checkpoints.enumerated() {
            let root = SKNode()
            root.name = "checkpoint\(index)"
            root.position = CGPoint(x: x, y: groundY)
            root.zPosition = 23
            let aura = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 2))
            aura.size = CGSize(width: 72, height: 72)
            aura.position.y = 37
            aura.alpha = 0.7
            root.addChild(aura)
            let heart = SKSpriteNode(texture: Self.objectTexture(column: 1, row: 0))
            heart.size = CGSize(width: 38, height: 38)
            heart.position.y = 37
            root.addChild(heart)
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "CHECKPOINT"
            label.fontSize = 10
            label.fontColor = .yellow
            label.position.y = 72
            root.addChild(label)
            world.addChild(root)
        }
    }

    private func buildPuppy() {
        let spec = currentLevel.puppy
        let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: spec.frame))
        puppy.name = "rescuePuppy"
        puppy.anchorPoint = CGPoint(x: 0.5, y: 0)
        puppy.size = CGSize(width: 100, height: 100)
        puppy.position = CGPoint(x: spec.position.x, y: groundY - 4)
        puppy.zPosition = 26
        let aura = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 2))
        aura.size = CGSize(width: 118, height: 118)
        aura.position.y = 50
        aura.zPosition = -1
        aura.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.65), .scale(to: 0.95, duration: 0.65)])))
        puppy.addChild(aura)
        puppy.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.42), .moveBy(x: 0, y: -5, duration: 0.42)])))
        world.addChild(puppy)
        puppyNode = puppy
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.name = "rescueLabel"
        label.text = "2 LETTERS OPEN • 3 EARN THE CROWN"
        label.fontSize = 12
        label.fontColor = .yellow
        label.position = CGPoint(x: spec.position.x, y: 164)
        label.zPosition = 30
        world.addChild(label)
    }

    private func buildExit() {
        let root = SKNode()
        root.name = "exit"
        root.position = CGPoint(x: currentLevel.exitX, y: groundY)
        root.zPosition = 24
        let aura = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 2))
        aura.size = CGSize(width: 150, height: 150)
        aura.position.y = 72
        aura.color = .yellow
        aura.colorBlendFactor = 0.18
        root.addChild(aura)
        let heart = SKSpriteNode(texture: Self.objectTexture(column: 1, row: 0))
        heart.size = CGSize(width: 70, height: 70)
        heart.position.y = 73
        root.addChild(heart)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "HOME PORTAL"
        label.fontSize = 13
        label.fontColor = .yellow
        label.position.y = 142
        root.addChild(label)
        root.alpha = 0.28
        root.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.55), .scale(to: 1, duration: 0.55)])))
        world.addChild(root)
    }

    private func buildHUD() {
        let topBar = SKShapeNode(rectOf: CGSize(width: 610, height: 56), cornerRadius: 20)
        topBar.fillColor = UIColor(red: 0.12, green: 0.01, blue: 0.18, alpha: 0.70)
        topBar.strokeColor = UIColor(red: 1, green: 0.65, blue: 0.14, alpha: 0.72)
        topBar.lineWidth = 2
        topBar.position.y = 151
        topBar.zPosition = 100
        hud.addChild(topBar)

        healthHUD.position = CGPoint(x: -280, y: 151)
        healthHUD.zPosition = 104
        for index in 0..<3 {
            let heart = SKSpriteNode(texture: Self.objectTexture(column: 0, row: 0))
            heart.name = "health\(index)"
            heart.size = CGSize(width: 27, height: 27)
            heart.position.x = CGFloat(index) * 28
            healthHUD.addChild(heart)
        }
        hud.addChild(healthHUD)

        missionLabel.fontSize = 12
        missionLabel.fontColor = UIColor(red: 1, green: 0.72, blue: 0.87, alpha: 1)
        missionLabel.position = CGPoint(x: 0, y: 163)
        missionLabel.zPosition = 104
        hud.addChild(missionLabel)
        phaseLabel.fontSize = 13
        phaseLabel.fontColor = .white
        phaseLabel.position = CGPoint(x: 0, y: 143)
        phaseLabel.zPosition = 104
        hud.addChild(phaseLabel)

        let track = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.22), size: CGSize(width: 190, height: 6))
        track.position = CGPoint(x: 0, y: 126)
        track.zPosition = 103
        hud.addChild(track)
        progressFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressFill.position = CGPoint(x: -95, y: 126)
        progressFill.zPosition = 104
        hud.addChild(progressFill)
        progressPuppy.texture = Self.puppyTexture(frame: 0)
        progressPuppy.size = CGSize(width: 25, height: 25)
        progressPuppy.position = CGPoint(x: 0, y: 126)
        progressPuppy.zPosition = 105
        hud.addChild(progressPuppy)

        letterHUD.position = CGPoint(x: 222, y: 151)
        letterHUD.zPosition = 104
        for index in 0..<3 {
            let letter = SKSpriteNode(texture: Self.objectTexture(column: 2, row: 0))
            letter.name = "letter\(index)"
            letter.size = CGSize(width: 28, height: 28)
            letter.position.x = CGFloat(index) * 29
            letter.alpha = 0.24
            letterHUD.addChild(letter)
        }
        hud.addChild(letterHUD)

        actionButton.name = "actionControl"
        actionButton.size = CGSize(width: 44, height: 44)
        actionButton.position = CGPoint(x: -370, y: -148)
        actionButton.alpha = 0.58
        actionButton.zPosition = 110
        hud.addChild(actionButton)
        let actionGlyph = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        actionGlyph.text = "SLIDE"
        actionGlyph.fontSize = 10
        actionGlyph.fontColor = .white
        actionGlyph.position = CGPoint(x: -370, y: -177)
        actionGlyph.zPosition = 111
        actionGlyph.name = "actionLabel"
        hud.addChild(actionGlyph)

        jumpButton.name = "jumpControl"
        jumpButton.size = CGSize(width: 70, height: 58)
        jumpButton.position = CGPoint(x: 368, y: -148)
        jumpButton.alpha = 0.64
        jumpButton.zPosition = 110
        hud.addChild(jumpButton)
    }

    private func updateHUD() {
        missionLabel.text = "MISSION \(missionIndex + 1)  •  \(currentLevel.title)"
        phaseLabel.text = phase == .approach ? "FIND \(currentLevel.puppy.name.uppercased())" : "ESCAPE TO THE HEART PORTAL"
        for index in 0..<3 {
            healthHUD.childNode(withName: "health\(index)")?.isHidden = index >= health
            letterHUD.childNode(withName: "letter\(index)")?.alpha = index < letters ? 1 : 0.24
        }
        let progress = min(1, max(0, player.position.x / currentLevel.exitX))
        progressFill.xScale = max(0.02, progress)
        progressPuppy.texture = Self.puppyTexture(frame: currentLevel.puppy.frame)
        progressPuppy.position.x = -95 + progress * 190
    }

    private func setControls(hidden: Bool) {
        jumpButton.isHidden = hidden
        actionButton.isHidden = hidden
        hud.childNode(withName: "actionLabel")?.isHidden = hidden
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .title:
            showMissionSelect()
        case .missionSelect, .sanctuary, .results:
            for touch in touches { handleMenuTouch(touch.location(in: overlay)) }
        case .playing:
            for touch in touches {
                let point = touch.location(in: cameraNode)
                touchStarts[touch] = point
                if point.x < -220 {
                    beginSlideOrDive()
                } else {
                    beginJumpOrTwirl()
                }
            }
        case .ready, .rescuing:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .playing else { return }
        for touch in touches {
            guard let start = touchStarts[touch] else { continue }
            let point = touch.location(in: cameraNode)
            if start.y - point.y > 45 {
                beginSlideOrDive()
                touchStarts[touch] = point
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchStarts.removeValue(forKey: touch) }
        jumpHeld = false
        jumpButton.setScale(1)
        actionButton.setScale(1)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func handleMenuTouch(_ point: CGPoint) {
        for hit in overlay.nodes(at: point) {
            var node: SKNode? = hit
            while let current = node, current !== overlay {
                if let name = current.name {
                    if name == "menu:missions" { showMissionSelect(); return }
                    if name == "menu:sanctuary" { showSanctuary(); return }
                    if name == "menu:retry" { startMission(missionIndex); return }
                    if name == "menu:next" { startMission(min(missionIndex + 1, LevelDefinition.all.count - 1)); return }
                    if name.hasPrefix("mission:"), let index = Int(name.dropFirst(8)) { startMission(index); return }
                }
                node = current.parent
            }
        }
    }

    private func beginJumpOrTwirl() {
        if grounded || coyoteTime > 0 {
            jumpBuffer = 0.14
            jumpHeld = true
            jumpHoldTime = 0.22
            sound.play(frequency: 520, duration: 0.09, volume: 0.12)
        } else if airTwirlAvailable {
            airTwirlAvailable = false
            velocity.dy = max(velocity.dy, 170)
            invincibleTime = max(invincibleTime, 0.30)
            player.performTwirl()
            collectNearby(radius: 105)
            sparkleBurst(at: CGPoint(x: player.position.x, y: player.position.y + 58), colors: [.systemPink, .yellow, .white], count: 18)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            sound.play(frequency: 880, duration: 0.12, volume: 0.12)
        }
        jumpButton.setScale(1.1)
    }

    private func beginSlideOrDive() {
        if grounded {
            slideTime = 0.58
        } else {
            velocity.dy = -1_050
            slideTime = 0.32
        }
        actionButton.setScale(1.1)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sound.play(frequency: grounded ? 240 : 180, duration: 0.07, volume: 0.10)
    }

    override func update(_ currentTime: TimeInterval) {
        guard state == .playing else { previousTime = currentTime; return }
        let dt = min(previousTime == 0 ? 1 / 60 : currentTime - previousTime, 1 / 30)
        previousTime = currentTime
        invincibleTime = max(0, invincibleTime - dt)
        slideTime = max(0, slideTime - dt)
        jumpHoldTime = max(0, jumpHoldTime - dt)
        jumpBuffer = max(0, jumpBuffer - dt)
        coyoteTime = grounded ? 0.1 : max(0, coyoteTime - dt)
        updatePlatforms(currentTime)
        updatePlayer(dt)
        updatePickups(dt)
        updateCheckpoint()
        updatePuppyFollower(dt)
        updateBackground()
        updateCamera()
        updateHUD()
    }

    private var missionBackgrounds: [String] {
        switch missionIndex {
        case 0: return ["BloomingPark", "ParisFashionDistrict", "SunsetRooftops"]
        case 1: return ["BloomingPark", "CandyBoardwalk", "CrystalHeartPalace"]
        default: return ["NeonMoonGarden", "SunsetRooftops", "CrystalHeartPalace"]
        }
    }

    private func updateBackground() {
        let progress = min(0.999, max(0, player.position.x / currentLevel.exitX))
        let requestedStage = min(missionBackgrounds.count - 1, Int(progress * CGFloat(missionBackgrounds.count)))
        guard requestedStage > backgroundStage, !backgroundTransitioning else { return }
        backgroundTransitioning = true
        let texture = SKTexture(imageNamed: missionBackgrounds[requestedStage])
        texture.filteringMode = .linear
        transitionBackdrop.texture = texture
        transitionBackdrop.alpha = 0
        transitionBackdrop.run(.fadeIn(withDuration: 0.85)) { [weak self] in
            guard let self else { return }
            self.backdrop.texture = texture
            self.transitionBackdrop.alpha = 0
            self.backgroundStage = requestedStage
            self.backgroundTransitioning = false
        }
    }

    private func updatePlayer(_ dt: TimeInterval) {
        if jumpBuffer > 0, coyoteTime > 0 {
            velocity.dy = 620
            grounded = false
            coyoteTime = 0
            jumpBuffer = 0
            airTwirlAvailable = true
            sparkleBurst(at: player.position, colors: [.systemPink, .white], count: 8)
        }
        let escapeBoost: CGFloat = missionIndex == 2 ? 112 : 72
        let speed = currentLevel.runSpeed + (phase == .escape ? escapeBoost : 0)
        velocity.dx = speed
        let gravity: CGFloat = jumpHeld && jumpHoldTime > 0 && velocity.dy > 0 ? 920 : 1_650
        velocity.dy = max(velocity.dy - gravity * dt, -980)
        let oldY = player.position.y
        player.position.x = min(currentLevel.worldWidth - 20, player.position.x + velocity.dx * dt)
        var nextY = player.position.y + velocity.dy * dt
        grounded = false
        if velocity.dy <= 0 {
            var landing: CGFloat?
            var landedSurface: Surface?
            if oldY >= groundY - 2, nextY <= groundY { landing = groundY }
            let minX = player.position.x - 19
            let maxX = player.position.x + 19
            for surface in surfaces where surface.active {
                if maxX > surface.rect.minX, minX < surface.rect.maxX,
                   oldY >= surface.rect.maxY - 2, nextY <= surface.rect.maxY,
                   surface.rect.maxY >= landing ?? -.greatestFiniteMagnitude {
                    landing = surface.rect.maxY
                    landedSurface = surface
                }
            }
            if let landing {
                if velocity.dy < -210 { player.squashForLanding() }
                nextY = landing
                velocity.dy = 0
                grounded = true
                airTwirlAvailable = true
                if landedSurface?.behavior == .crumbling, let landedSurface { crumble(landedSurface) }
            }
        }
        player.position.y = nextY
        if grounded, currentLevel.bouncePads.contains(where: { abs($0.x - player.position.x) < 32 && abs($0.y - player.position.y) < 8 }) {
            velocity.dy = 790
            grounded = false
            airTwirlAvailable = true
            sparkleBurst(at: player.position, colors: [.systemPink, .yellow, .white], count: 15)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sound.play(frequency: 660, duration: 0.14, volume: 0.14)
        }
        let hitHeight: CGFloat = slideTime > 0 ? 38 : 72
        let hitbox = CGRect(x: player.position.x - 17, y: player.position.y, width: 34, height: hitHeight)
        if player.position.y < -80 || (invincibleTime == 0 && currentLevel.hazards.contains(where: { hitbox.intersects($0.rect) })) {
            takeDamage(fell: player.position.y < -80)
        }
        player.updateAnimation(deltaTime: dt, moving: true, airborne: !grounded, facing: 1, verticalVelocity: velocity.dy, sliding: slideTime > 0)

        if phase == .approach, player.position.x >= currentLevel.puppy.position.x - 55 {
            if letters >= 2 { rescuePuppy() }
            else { missedGate() }
        } else if phase == .escape, player.position.x >= currentLevel.exitX - 42 {
            finishMission(won: true)
        }
    }

    private func updatePlatforms(_ currentTime: TimeInterval) {
        for surface in surfaces where surface.active && surface.behavior == .moving {
            let center = surface.baseX + sin(CGFloat(currentTime) * 1.2 + surface.phase) * 44
            surface.node?.position.x = center
            surface.rect.origin.x = center - surface.rect.width / 2
        }
    }

    private func crumble(_ surface: Surface) {
        guard !surface.crumbling else { return }
        surface.crumbling = true
        surface.node?.run(.sequence([
            .repeat(.sequence([.rotate(byAngle: 0.035, duration: 0.05), .rotate(byAngle: -0.07, duration: 0.05), .rotate(byAngle: 0.035, duration: 0.05)]), count: 3),
            .group([.moveBy(x: 0, y: -65, duration: 0.34), .fadeOut(withDuration: 0.34)]),
            .run { surface.active = false }
        ]))
    }

    private func takeDamage(fell: Bool) {
        guard invincibleTime == 0 else { return }
        if companionShield {
            companionShield = false
            invincibleTime = 0.8
            sparkleBurst(at: CGPoint(x: player.position.x, y: player.position.y + 50), colors: [.cyan, .white, .systemPink], count: 28)
            showToast("BIJOU'S SHIELD SAVED YOU")
            sound.play(frequency: 960, duration: 0.18, volume: 0.14)
            return
        }
        damageTaken += 1
        health -= 1
        invincibleTime = 1.35
        player.position = CGPoint(x: checkpointX, y: groundY)
        velocity = CGVector(dx: 0, dy: 360)
        sparkleBurst(at: CGPoint(x: player.position.x, y: player.position.y + 45), colors: [.purple, .white], count: 18)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        sound.play(frequency: 155, duration: 0.20, volume: 0.15)
        player.run(.repeat(.sequence([.fadeAlpha(to: 0.25, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)]), count: 7))
        if health <= 0 { finishMission(won: false) }
    }

    private func updatePickups(_ dt: TimeInterval) {
        if phase == .escape, missionIndex == 0 {
            for node in pickups where node.name != PickupStyle.letter.rawValue {
                let dx = player.position.x - node.position.x
                let dy = player.position.y + 55 - node.position.y
                let distance = hypot(dx, dy)
                if distance < 175, distance > 1 {
                    node.position.x += dx / distance * 280 * dt
                    node.position.y += dy / distance * 280 * dt
                }
            }
        }
        collectNearby(radius: slideTime > 0 ? 48 : 58)
    }

    private func collectNearby(radius: CGFloat) {
        let center = CGPoint(x: player.position.x, y: player.position.y + 52)
        for node in pickups.reversed() where hypot(node.position.x - center.x, node.position.y - center.y) < radius {
            collect(node)
        }
    }

    private func collect(_ node: SKNode) {
        guard let index = pickups.firstIndex(where: { $0 === node }), let name = node.name, let style = PickupStyle(rawValue: name) else { return }
        pickups.remove(at: index)
        switch style {
        case .heart: hearts += 1
        case .goldenHeart:
            hearts += 1
            invincibleTime = max(invincibleTime, 3)
        case .letter:
            letters = min(3, letters + 1)
            world.childNode(withName: "rescueLabel")?.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.12)]))
        }
        player.setSmileLevel(GameRules.smileLevel(for: hearts))
        sparkleBurst(at: node.position, colors: style == .goldenHeart ? [.yellow, .white, .systemPink] : [.systemPink, .white], count: style == .letter ? 22 : 12)
        node.removeFromParent()
        UIImpactFeedbackGenerator(style: style == .goldenHeart ? .heavy : .light).impactOccurred()
        let frequency: Double = style == .letter ? 1_080 : style == .goldenHeart ? 920 : 760
        sound.play(frequency: frequency, duration: style == .letter ? 0.16 : 0.08, volume: 0.11)
    }

    private func updateCheckpoint() {
        for (index, x) in currentLevel.checkpoints.enumerated() where !activatedCheckpoints.contains(index) && player.position.x >= x {
            activatedCheckpoints.insert(index)
            checkpointX = x
            if let node = world.childNode(withName: "checkpoint\(index)") {
                node.run(.sequence([.scale(to: 1.2, duration: 0.14), .scale(to: 1, duration: 0.14), .fadeAlpha(to: 0.35, duration: 0.4)]))
            }
            sparkleBurst(at: CGPoint(x: x, y: 105), colors: [.yellow, .systemPink, .white], count: 20)
            sound.play(frequency: 700, duration: 0.14, volume: 0.12)
        }
    }

    private func missedGate() {
        checkpointX = 125
        player.position = CGPoint(x: 125, y: groundY)
        velocity = .zero
        cameraNode.position.x = size.width / 2
        showToast("THE HEART GATE NEEDS 2 LOVE LETTERS")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func rescuePuppy() {
        guard state == .playing, let puppy = puppyNode else { return }
        state = .rescuing
        velocity = .zero
        player.standStill(facing: 1)
        setControls(hidden: true)
        world.childNode(withName: "rescueLabel")?.removeFromParent()
        puppy.removeAllActions()
        puppy.run(.sequence([
            .group([.move(to: CGPoint(x: player.position.x + 58, y: player.position.y + 2), duration: 0.38), .scale(to: 1.12, duration: 0.38)]),
            .repeat(.sequence([.moveBy(x: 0, y: 11, duration: 0.13), .moveBy(x: 0, y: -11, duration: 0.13)]), count: 2)
        ]))
        sparkleBurst(at: CGPoint(x: puppy.position.x, y: puppy.position.y + 65), colors: [.systemPink, .yellow, .white], count: 38)
        showRescueCard()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sound.play(frequency: 1_160, duration: 0.28, volume: 0.15)
        run(.sequence([.wait(forDuration: 1.75), .run { [weak self] in self?.beginEscape() }]), withKey: "rescue")
    }

    private func beginEscape() {
        guard let puppy = puppyNode else { return }
        overlay.removeAllChildren()
        phase = .escape
        state = .playing
        rescuedPuppy = puppy
        companionShield = missionIndex == 1
        world.childNode(withName: "exit")?.alpha = 1
        checkpointX = player.position.x
        invincibleTime = 1
        previousTime = 0
        setControls(hidden: false)
        let powers = ["HONEY POWER: HEART MAGNET!", "BIJOU POWER: CRYSTAL SHIELD!", "VELVET POWER: ROSE RUSH!"]
        showToast(powers[missionIndex])
    }

    private func updatePuppyFollower(_ dt: TimeInterval) {
        guard phase == .escape, let puppy = rescuedPuppy else { return }
        let target = CGPoint(x: player.position.x - 65, y: max(groundY - 3, player.position.y - 8))
        puppy.position.x += (target.x - puppy.position.x) * min(1, 8 * dt)
        puppy.position.y += (target.y - puppy.position.y) * min(1, 7 * dt)
        puppy.xScale = 0.82
        puppy.yScale = 0.82
    }

    private func finishMission(won: Bool) {
        guard state == .playing else { return }
        state = .results
        velocity = .zero
        jumpHeld = false
        setControls(hidden: true)
        player.standStill(facing: 1)
        let crowns = won ? GameRules.crowns(letters: letters, totalLetters: 3, damageTaken: damageTaken) : 0
        if won {
            let previous = savedCrowns(for: missionIndex)
            UserDefaults.standard.set(max(previous, crowns), forKey: crownKey(missionIndex))
            UserDefaults.standard.set(true, forKey: completionKey(missionIndex))
        }
        sound.play(frequency: won ? 1_240 : 190, duration: won ? 0.32 : 0.25, volume: 0.15)
        showResults(won: won, crowns: crowns)
    }

    private func updateCamera() {
        let target = max(size.width / 2, min(currentLevel.worldWidth - size.width / 2, player.position.x + size.width * 0.19))
        cameraNode.position.x += (target - cameraNode.position.x) * 0.11
    }

    private func showStageCard() {
        overlay.removeAllChildren()
        addVeil(alpha: 0.18)
        let panel = makePanel(size: CGSize(width: 540, height: 186))
        overlay.addChild(panel)
        addText("MISSION \(missionIndex + 1)", fontSize: 14, color: .yellow, y: 59, parent: overlay)
        addText(currentLevel.title, fontSize: 30, color: .white, y: 22, parent: overlay)
        addText(currentLevel.tagline, fontSize: 14, color: UIColor(red: 1, green: 0.70, blue: 0.87, alpha: 1), y: -12, parent: overlay)
        addText("RIGHT: JUMP + TWIRL    •    LEFT: SLIDE", fontSize: 12, color: .white, y: -49, parent: overlay)
    }

    private func showCountdown() {
        overlay.removeAllChildren()
        let label = addText("RUN!", fontSize: 82, color: .yellow, y: 0, parent: overlay)
        label.verticalAlignmentMode = .center
        label.setScale(0.35)
        label.run(.group([.scale(to: 1.2, duration: 0.22), .fadeOut(withDuration: 0.45)]))
    }

    private func showRescueCard() {
        overlay.removeAllChildren()
        let flash = SKSpriteNode(color: .white, size: size)
        flash.alpha = 0.48
        flash.zPosition = 190
        overlay.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        let panel = makePanel(size: CGSize(width: 520, height: 174))
        panel.setScale(0.70)
        overlay.addChild(panel)
        panel.run(.sequence([.scale(to: 1.04, duration: 0.18), .scale(to: 1, duration: 0.12)]))
        let puppy = SKSpriteNode(texture: Self.puppyTexture(frame: currentLevel.puppy.frame))
        puppy.size = CGSize(width: 118, height: 118)
        puppy.position = CGPoint(x: -166, y: 2)
        puppy.zPosition = 204
        overlay.addChild(puppy)
        addText("\(currentLevel.puppy.name.uppercased()) RESCUED!", fontSize: 31, color: .white, x: 70, y: 24, parent: overlay)
        addText("NOW RUN HOME TOGETHER", fontSize: 15, color: .yellow, x: 70, y: -20, parent: overlay)
    }

    private func showResults(won: Bool, crowns: Int) {
        overlay.removeAllChildren()
        addVeil(alpha: 0.48)
        let panel = makePanel(size: CGSize(width: 620, height: 306))
        overlay.addChild(panel)
        addText(won ? "RESCUE COMPLETE" : "THE GARDEN GOT FIERCE", fontSize: 32, color: .white, y: 93, parent: overlay)
        addText(won ? currentLevel.puppy.name.uppercased() + " IS HOME" : "TRY THE MISSION AGAIN", fontSize: 16, color: .yellow, y: 59, parent: overlay)
        addText(won ? crownString(crowns) : "♡  ♡  ♡", fontSize: 40, color: won ? .yellow : .lightGray, y: 7, parent: overlay)
        let status = won ? "RESCUE  •  \(letters)/3 LETTERS  •  \(damageTaken == 0 ? "FLAWLESS" : "\(damageTaken) HIT\(damageTaken == 1 ? "" : "S")")" : "Keep moving. Jump late. Twirl once in the air."
        addText(status, fontSize: 14, color: UIColor(red: 1, green: 0.72, blue: 0.87, alpha: 1), y: -35, parent: overlay)
        let primaryName = won && missionIndex < LevelDefinition.all.count - 1 ? "menu:next" : "menu:retry"
        let primaryTitle = won && missionIndex < LevelDefinition.all.count - 1 ? "NEXT MISSION" : "RUN AGAIN"
        let primary = makeButton(title: primaryTitle, width: 210, name: primaryName)
        primary.position = CGPoint(x: -120, y: -91)
        overlay.addChild(primary)
        let map = makeButton(title: "MISSION MAP", width: 190, name: "menu:missions")
        map.position = CGPoint(x: 120, y: -91)
        overlay.addChild(map)
    }

    private func showToast(_ text: String) {
        let old = overlay.childNode(withName: "toast")
        old?.removeFromParent()
        let toast = SKShapeNode(rectOf: CGSize(width: 410, height: 48), cornerRadius: 20)
        toast.name = "toast"
        toast.fillColor = UIColor(red: 0.18, green: 0.01, blue: 0.25, alpha: 0.91)
        toast.strokeColor = .yellow
        toast.lineWidth = 2
        toast.position.y = 72
        toast.zPosition = 240
        overlay.addChild(toast)
        addText(text, fontSize: 14, color: .white, y: -5, parent: toast)
        toast.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func addVeil(alpha: CGFloat) {
        let veil = SKSpriteNode(color: .black, size: size)
        veil.alpha = alpha
        veil.zPosition = 180
        overlay.addChild(veil)
    }

    @discardableResult
    private func addText(_ text: String, fontSize: CGFloat, color: UIColor, x: CGFloat = 0, y: CGFloat, parent: SKNode) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 205
        parent.addChild(label)
        return label
    }

    private func makePanel(size: CGSize) -> SKShapeNode {
        let panel = SKShapeNode(rectOf: size, cornerRadius: 30)
        panel.fillColor = UIColor(red: 0.12, green: 0.005, blue: 0.18, alpha: 0.93)
        panel.strokeColor = UIColor(red: 1, green: 0.69, blue: 0.12, alpha: 1)
        panel.lineWidth = 3
        panel.glowWidth = 7
        panel.zPosition = 198
        return panel
    }

    private func makeButton(title: String, width: CGFloat, name: String) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 44), cornerRadius: 18)
        button.name = name
        button.fillColor = UIColor(red: 0.82, green: 0.02, blue: 0.43, alpha: 0.96)
        button.strokeColor = UIColor(red: 1, green: 0.78, blue: 0.20, alpha: 1)
        button.lineWidth = 2
        button.zPosition = 210
        addText(title, fontSize: 14, color: .white, y: -5, parent: button)
        return button
    }

    private func isMissionUnlocked(_ index: Int) -> Bool {
        index == 0 || isMissionComplete(index - 1)
    }

    private func isMissionComplete(_ index: Int) -> Bool {
        UserDefaults.standard.bool(forKey: completionKey(index))
    }

    private func savedCrowns(for index: Int) -> Int {
        UserDefaults.standard.integer(forKey: crownKey(index))
    }

    private func crownKey(_ index: Int) -> String { "LoveRun.verticalSlice.mission.\(index).crowns" }
    private func completionKey(_ index: Int) -> String { "LoveRun.verticalSlice.mission.\(index).complete" }

    private func crownString(_ count: Int) -> String {
        (0..<3).map { $0 < count ? "◆" : "◇" }.joined(separator: "  ")
    }

    private static func objectTexture(column: Int, row: Int, crop: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> SKTexture {
        let sheet = SKTexture(imageNamed: "RomanceObjects")
        let cellWidth: CGFloat = 1 / 4
        let cellHeight: CGFloat = 1 / 3
        let texture = SKTexture(rect: CGRect(
            x: CGFloat(column) * cellWidth + crop.minX * cellWidth,
            y: CGFloat(2 - row) * cellHeight + crop.minY * cellHeight,
            width: crop.width * cellWidth,
            height: crop.height * cellHeight
        ), in: sheet)
        texture.filteringMode = .linear
        return texture
    }

    private static func puppyTexture(frame: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "PuppyParade")
        let column = frame % 4
        let row = frame / 4
        let texture = SKTexture(rect: CGRect(x: CGFloat(column) / 4, y: CGFloat(2 - row) / 3, width: 1 / 4, height: 1 / 3), in: sheet)
        texture.filteringMode = .linear
        return texture
    }

    private static func controlTexture(index: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "CrystalControls")
        let rects = [
            CGRect(x: 0.008, y: 0.14, width: 0.28, height: 0.80),
            CGRect(x: 0.297, y: 0.14, width: 0.269, height: 0.80),
            CGRect(x: 0.564, y: 0.013, width: 0.436, height: 0.987)
        ]
        let texture = SKTexture(rect: rects[index], in: sheet)
        texture.filteringMode = .linear
        return texture
    }

    private func sparkleBurst(at position: CGPoint, colors: [UIColor], count: Int) {
        for index in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4.5))
            dot.fillColor = colors[index % colors.count]
            dot.strokeColor = .clear
            dot.position = position
            dot.zPosition = 50
            world.addChild(dot)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            let distance = CGFloat.random(in: 30...82)
            dot.run(.sequence([.group([
                .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.42),
                .fadeOut(withDuration: 0.42), .scale(to: 0.15, duration: 0.42)
            ]), .removeFromParent()]))
        }
    }
}

private final class TonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(frequency: Double, duration: Double, volume: Float) {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = Float(pow(1 - Double(frame) / Double(frameCount), 2.2))
            samples[frame] = sin(Float(time * frequency * 2 * .pi)) * envelope * volume
        }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer)
        if !player.isPlaying { player.play() }
    }
}
