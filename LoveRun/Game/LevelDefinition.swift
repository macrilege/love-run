import CoreGraphics

enum PlatformStyle {
    case stone
    case picnic
    case cloud
}

struct PlatformSpec {
    let rect: CGRect
    let style: PlatformStyle
}

enum HazardStyle {
    case puddle
    case hedge
    case thorns
}

struct HazardSpec {
    let rect: CGRect
    let style: HazardStyle
}

enum PickupStyle: String {
    case heart
    case goldenHeart
    case letter
}

struct PickupSpec {
    let position: CGPoint
    let style: PickupStyle
}

struct LevelDefinition {
    let name: String
    let tagline: String
    let backgroundAsset: String
    let worldWidth: CGFloat
    let puppyName: String
    let puppyFrame: Int
    let platforms: [PlatformSpec]
    let hazards: [HazardSpec]
    let bouncePads: [CGPoint]
    let pickups: [PickupSpec]
    let puppyPosition: CGPoint

    static let all: [LevelDefinition] = [
        LevelDefinition(
            name: "BLOOMING PARK",
            tagline: "Petals. Platforms. Main-character energy.",
            backgroundAsset: "BloomingPark",
            worldWidth: 3_250,
            puppyName: "Honey",
            puppyFrame: 0,
            platforms: [
                PlatformSpec(rect: CGRect(x: 470, y: 91, width: 155, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 750, y: 142, width: 180, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 1_055, y: 98, width: 145, height: 24), style: .stone),
                PlatformSpec(rect: CGRect(x: 1_330, y: 158, width: 170, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 1_650, y: 112, width: 165, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 1_965, y: 174, width: 180, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 2_300, y: 122, width: 160, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 2_610, y: 162, width: 175, height: 25), style: .stone)
            ],
            hazards: [
                HazardSpec(rect: CGRect(x: 650, y: 53, width: 82, height: 13), style: .puddle),
                HazardSpec(rect: CGRect(x: 1_215, y: 55, width: 62, height: 38), style: .hedge),
                HazardSpec(rect: CGRect(x: 1_840, y: 54, width: 88, height: 18), style: .thorns),
                HazardSpec(rect: CGRect(x: 2_485, y: 53, width: 90, height: 14), style: .puddle)
            ],
            bouncePads: [CGPoint(x: 385, y: 58), CGPoint(x: 1_535, y: 58), CGPoint(x: 2_185, y: 58)],
            pickups: LevelDefinition.routePickups(offset: 0),
            puppyPosition: CGPoint(x: 3_080, y: 58)
        ),
        LevelDefinition(
            name: "SUNSET ROOFTOPS",
            tagline: "High heels optional. High standards required.",
            backgroundAsset: "SunsetRooftops",
            worldWidth: 3_400,
            puppyName: "Bijou",
            puppyFrame: 1,
            platforms: [
                PlatformSpec(rect: CGRect(x: 430, y: 115, width: 170, height: 24), style: .picnic),
                PlatformSpec(rect: CGRect(x: 730, y: 174, width: 145, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 1_025, y: 118, width: 180, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 1_335, y: 181, width: 165, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 1_665, y: 126, width: 150, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 1_965, y: 188, width: 190, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 2_315, y: 134, width: 160, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 2_650, y: 190, width: 190, height: 22), style: .cloud)
            ],
            hazards: [
                HazardSpec(rect: CGRect(x: 620, y: 54, width: 82, height: 18), style: .thorns),
                HazardSpec(rect: CGRect(x: 920, y: 54, width: 72, height: 40), style: .hedge),
                HazardSpec(rect: CGRect(x: 1_535, y: 53, width: 92, height: 14), style: .puddle),
                HazardSpec(rect: CGRect(x: 2_190, y: 54, width: 82, height: 18), style: .thorns),
                HazardSpec(rect: CGRect(x: 2_930, y: 54, width: 72, height: 40), style: .hedge)
            ],
            bouncePads: [CGPoint(x: 330, y: 58), CGPoint(x: 1_245, y: 58), CGPoint(x: 2_520, y: 58)],
            pickups: LevelDefinition.routePickups(offset: 55),
            puppyPosition: CGPoint(x: 3_220, y: 58)
        ),
        LevelDefinition(
            name: "NEON MOON GARDEN",
            tagline: "Glow hard. Love harder. Rescue the queen.",
            backgroundAsset: "NeonMoonGarden",
            worldWidth: 3_550,
            puppyName: "Velvet",
            puppyFrame: 2,
            platforms: [
                PlatformSpec(rect: CGRect(x: 455, y: 130, width: 160, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 760, y: 188, width: 175, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 1_090, y: 126, width: 170, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 1_420, y: 198, width: 160, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 1_760, y: 137, width: 180, height: 25), style: .stone),
                PlatformSpec(rect: CGRect(x: 2_100, y: 204, width: 180, height: 25), style: .picnic),
                PlatformSpec(rect: CGRect(x: 2_455, y: 145, width: 165, height: 22), style: .cloud),
                PlatformSpec(rect: CGRect(x: 2_805, y: 205, width: 185, height: 25), style: .stone)
            ],
            hazards: [
                HazardSpec(rect: CGRect(x: 650, y: 54, width: 94, height: 18), style: .thorns),
                HazardSpec(rect: CGRect(x: 970, y: 53, width: 88, height: 14), style: .puddle),
                HazardSpec(rect: CGRect(x: 1_625, y: 54, width: 78, height: 42), style: .hedge),
                HazardSpec(rect: CGRect(x: 2_325, y: 54, width: 96, height: 18), style: .thorns),
                HazardSpec(rect: CGRect(x: 3_060, y: 53, width: 90, height: 14), style: .puddle)
            ],
            bouncePads: [CGPoint(x: 350, y: 58), CGPoint(x: 1_315, y: 58), CGPoint(x: 2_680, y: 58)],
            pickups: LevelDefinition.routePickups(offset: 105),
            puppyPosition: CGPoint(x: 3_360, y: 58)
        )
    ]

    private static func routePickups(offset: CGFloat) -> [PickupSpec] {
        let route: [(CGFloat, CGFloat)] = [
            (250, 105), (330, 145), (410, 180),
            (520, 150), (600, 165),
            (780, 205), (855, 225),
            (1_040, 150), (1_120, 175),
            (1_355, 220), (1_440, 240),
            (1_675, 160), (1_755, 185),
            (1_990, 235), (2_075, 255),
            (2_330, 175), (2_420, 200),
            (2_650, 220), (2_745, 245),
            (2_930, 125)
        ]
        var result = route.map { PickupSpec(position: CGPoint(x: $0.0 + offset, y: $0.1), style: .heart) }
        result.append(PickupSpec(position: CGPoint(x: 1_475 + offset, y: 285), style: .goldenHeart))
        result.append(PickupSpec(position: CGPoint(x: 2_760 + offset, y: 285), style: .letter))
        return result
    }
}
