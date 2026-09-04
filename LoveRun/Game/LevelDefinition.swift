import CoreGraphics

enum PlatformStyle: CaseIterable { case stone, picnic, cloud }
enum PlatformBehavior { case fixed, moving, crumbling }

struct PlatformSpec {
    let rect: CGRect
    let style: PlatformStyle
    let behavior: PlatformBehavior
}

enum HazardStyle: CaseIterable { case puddle, hedge, thorns }
struct HazardSpec { let rect: CGRect; let style: HazardStyle }
enum PickupStyle: String { case heart, goldenHeart, letter }
struct PickupSpec { let position: CGPoint; let style: PickupStyle }

struct PuppySpec {
    let name: String
    let frame: Int
    let position: CGPoint
    let requiredSeals: Int
}

struct LevelDefinition {
    let name: String
    let tagline: String
    let backgroundAsset: String
    let worldWidth: CGFloat
    let friendFrame: Int
    let platforms: [PlatformSpec]
    let hazards: [HazardSpec]
    let bouncePads: [CGPoint]
    let pickups: [PickupSpec]
    let checkpoints: [CGFloat]
    let puppies: [PuppySpec]

    static let all: [LevelDefinition] = {
        let worlds: [(String, String, String, CGFloat)] = [
            ("BLOOMING PARK", "Petals, platforms, and main-character energy.", "BloomingPark", 7_200),
            ("SUNSET ROOFTOPS", "High standards. Higher jumps.", "SunsetRooftops", 7_500),
            ("PARIS FASHION DISTRICT", "Couture courage on every corner.", "ParisFashionDistrict", 7_800),
            ("CANDY BOARDWALK", "Sugar rush. Seaside sparkle.", "CandyBoardwalk", 8_100),
            ("NEON MOON GARDEN", "Glow hard. Love harder.", "NeonMoonGarden", 8_400),
            ("CRYSTAL HEART PALACE", "The royal rescue finale.", "CrystalHeartPalace", 8_700)
        ]
        let names = ["Honey", "Bijou", "Velvet", "Biscuit", "Pom-Pom", "Gigi", "Pearl", "Pixie", "Luna", "Trixie", "Angel", "Lucky"]
        return worlds.enumerated().map { index, world in
            let firstPuppyX = world.3 * 0.57
            return LevelDefinition(
                name: world.0,
                tagline: world.1,
                backgroundAsset: world.2,
                worldWidth: world.3,
                friendFrame: index % 4,
                platforms: platformRoute(world: index, width: world.3),
                hazards: hazardRoute(world: index, width: world.3),
                bouncePads: bounceRoute(world: index, width: world.3),
                pickups: pickupRoute(world: index, width: world.3, firstPuppyX: firstPuppyX),
                checkpoints: [world.3 * 0.28, world.3 * 0.72],
                puppies: [
                    PuppySpec(name: names[index * 2], frame: index * 2, position: CGPoint(x: firstPuppyX, y: 58), requiredSeals: 1),
                    PuppySpec(name: names[index * 2 + 1], frame: index * 2 + 1, position: CGPoint(x: world.3 - 180, y: 58), requiredSeals: 3)
                ]
            )
        }
    }()

    private static func platformRoute(world: Int, width: CGFloat) -> [PlatformSpec] {
        var result: [PlatformSpec] = []
        var x: CGFloat = 430
        var index = 0
        while x < width - 280 {
            let upperLane = (index + world) % 4 == 1 || (index + world) % 7 == 4
            let y: CGFloat = (upperLane ? 176 : 104) + CGFloat((index * 17 + world * 11) % 22)
            let behavior: PlatformBehavior
            if world >= 1 && index % 6 == 2 { behavior = .moving }
            else if world >= 2 && index % 7 == 5 { behavior = .crumbling }
            else { behavior = .fixed }
            result.append(PlatformSpec(
                rect: CGRect(x: x, y: y, width: 145 + CGFloat((index % 3) * 15), height: 24),
                style: PlatformStyle.allCases[(index + world) % 3],
                behavior: behavior
            ))
            x += 285 + CGFloat((index * 19 + world * 13) % 70)
            index += 1
        }
        return result
    }

    private static func hazardRoute(world: Int, width: CGFloat) -> [HazardSpec] {
        var result: [HazardSpec] = []
        var x: CGFloat = 670
        var index = 0
        while x < width - 250 {
            let style = HazardStyle.allCases[(index + world) % 3]
            result.append(HazardSpec(
                rect: CGRect(x: x, y: 53, width: style == .hedge ? 68 : 88, height: style == .hedge ? 40 : 17),
                style: style
            ))
            x += 455 + CGFloat((index * 23 + world * 17) % 115)
            index += 1
        }
        return result
    }

    private static func bounceRoute(world: Int, width: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = [CGPoint(x: 350, y: 58)]
        var x: CGFloat = 1_550 + CGFloat(world * 35)
        while x < width - 500 {
            result.append(CGPoint(x: x, y: 58))
            x += 1_350 + CGFloat((result.count % 2) * 170)
        }
        return result
    }

    private static func pickupRoute(world: Int, width: CGFloat, firstPuppyX: CGFloat) -> [PickupSpec] {
        var result: [PickupSpec] = []
        var x: CGFloat = 245
        var index = 0
        while x < width - 130 {
            let wave = CGFloat((index * 37 + world * 29) % 135)
            result.append(PickupSpec(position: CGPoint(x: x, y: 105 + wave), style: .heart))
            x += 145 + CGFloat((index + world) % 3) * 18
            index += 1
        }
        let seals = [width * 0.18, width * 0.46, width * 0.79]
        result.append(contentsOf: seals.map { PickupSpec(position: CGPoint(x: $0, y: 255), style: .letter) })
        for goldenX in [width * 0.31, firstPuppyX - 360, width * 0.68, width * 0.9] {
            result.append(PickupSpec(position: CGPoint(x: goldenX, y: 292), style: .goldenHeart))
        }
        return result
    }
}
