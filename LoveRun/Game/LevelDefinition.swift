import CoreGraphics

enum PlatformStyle: CaseIterable { case stone, picnic, cloud }
enum PlatformBehavior { case fixed, moving, crumbling }

struct PlatformSpec {
    let rect: CGRect
    let style: PlatformStyle
    let behavior: PlatformBehavior

    init(rect: CGRect, style: PlatformStyle, behavior: PlatformBehavior = .fixed) {
        self.rect = rect
        self.style = style
        self.behavior = behavior
    }
}

enum HazardStyle: CaseIterable { case puddle, hedge, thorns }
struct HazardSpec { let rect: CGRect; let style: HazardStyle }
enum PickupStyle: String { case heart, goldenHeart, letter }
struct PickupSpec { let position: CGPoint; let style: PickupStyle }

struct PuppySpec {
    let name: String
    let frame: Int
    let position: CGPoint
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
    let puppies: [PuppySpec]

    static let all: [LevelDefinition] = {
        let worlds: [(String, String, String, CGFloat)] = [
            ("BLOOMING PARK", "Petals, platforms, and main-character energy.", "BloomingPark", 3_450),
            ("SUNSET ROOFTOPS", "High standards. Higher jumps.", "SunsetRooftops", 3_600),
            ("PARIS FASHION DISTRICT", "Couture courage on every corner.", "ParisFashionDistrict", 3_750),
            ("CANDY BOARDWALK", "Sugar rush. Seaside sparkle.", "CandyBoardwalk", 3_900),
            ("NEON MOON GARDEN", "Glow hard. Love harder.", "NeonMoonGarden", 4_050),
            ("CRYSTAL HEART PALACE", "The royal rescue finale.", "CrystalHeartPalace", 4_200)
        ]
        let names = ["Honey", "Bijou", "Velvet", "Biscuit", "Pom-Pom", "Gigi", "Pearl", "Pixie", "Luna", "Trixie", "Angel", "Lucky"]
        return worlds.enumerated().map { index, world in
            LevelDefinition(
                name: world.0,
                tagline: world.1,
                backgroundAsset: world.2,
                worldWidth: world.3,
                friendFrame: index % 4,
                platforms: platformRoute(world: index),
                hazards: hazardRoute(world: index),
                bouncePads: [CGPoint(x: 350, y: 58), CGPoint(x: 1_485 + CGFloat(index * 24), y: 58), CGPoint(x: 2_680 + CGFloat(index * 38), y: 58)],
                pickups: pickupRoute(offset: CGFloat(index * 34)),
                puppies: [
                    PuppySpec(name: names[index * 2], frame: index * 2, position: CGPoint(x: 1_830 + CGFloat(index * 40), y: 58)),
                    PuppySpec(name: names[index * 2 + 1], frame: index * 2 + 1, position: CGPoint(x: world.3 - 165, y: 58))
                ]
            )
        }
    }()

    private static func platformRoute(world: Int) -> [PlatformSpec] {
        let lift = CGFloat(world % 3) * 7
        let xs: [CGFloat] = [450, 750, 1_055, 1_365, 1_690, 2_020, 2_355, 2_700, 3_030, 3_365, 3_700]
        return xs.enumerated().map { index, x in
            let y: CGFloat = (index.isMultiple(of: 2) ? 105 : 170) + lift + CGFloat((index * 13 + world * 9) % 24)
            let behavior: PlatformBehavior
            if world >= 2 && index % 5 == 1 { behavior = .moving }
            else if world >= 3 && index % 5 == 3 { behavior = .crumbling }
            else { behavior = .fixed }
            return PlatformSpec(
                rect: CGRect(x: x + CGFloat(world * 20), y: y, width: 145 + CGFloat((index % 3) * 15), height: 24),
                style: PlatformStyle.allCases[(index + world) % 3],
                behavior: behavior
            )
        }
    }

    private static func hazardRoute(world: Int) -> [HazardSpec] {
        [640, 1_180, 1_610, 2_200, 2_900, 3_520].enumerated().map { index, x in
            let style = HazardStyle.allCases[(index + world) % 3]
            return HazardSpec(
                rect: CGRect(x: CGFloat(x + world * 22), y: 53, width: style == .hedge ? 68 : 88, height: style == .hedge ? 40 : 17),
                style: style
            )
        }
    }

    private static func pickupRoute(offset: CGFloat) -> [PickupSpec] {
        let route: [(CGFloat, CGFloat)] = [
            (245, 110), (330, 150), (420, 188), (525, 150), (610, 170),
            (785, 215), (875, 235), (1_050, 155), (1_145, 180),
            (1_360, 230), (1_455, 250), (1_675, 170), (1_765, 195),
            (2_000, 240), (2_095, 260), (2_330, 180), (2_430, 205),
            (2_675, 230), (2_770, 255), (3_030, 150), (3_265, 205), (3_520, 165)
        ]
        var result = route.map { PickupSpec(position: CGPoint(x: $0.0 + offset, y: $0.1), style: .heart) }
        result.append(PickupSpec(position: CGPoint(x: 1_490 + offset, y: 292), style: .goldenHeart))
        result.append(PickupSpec(position: CGPoint(x: 2_810 + offset, y: 292), style: .letter))
        return result
    }
}
