import CoreGraphics

enum PlatformStyle: CaseIterable { case stone, picnic, cloud }
enum PlatformBehavior: Equatable { case fixed, moving, crumbling }

struct PlatformSpec {
    let rect: CGRect
    let style: PlatformStyle
    let behavior: PlatformBehavior
}

enum HazardStyle: CaseIterable { case puddle, hedge, thorns, branch }
struct HazardSpec { let rect: CGRect; let style: HazardStyle }
enum PickupStyle: String { case heart, goldenHeart, letter }
struct PickupSpec { let position: CGPoint; let style: PickupStyle }

struct PuppySpec {
    let name: String
    let frame: Int
    let position: CGPoint
}

struct LevelDefinition {
    let title: String
    let tagline: String
    let backgroundAsset: String
    let worldWidth: CGFloat
    let runSpeed: CGFloat
    let puppy: PuppySpec
    let exitX: CGFloat
    let platforms: [PlatformSpec]
    let hazards: [HazardSpec]
    let bouncePads: [CGPoint]
    let pickups: [PickupSpec]
    let checkpoints: [CGFloat]

    static let all: [LevelDefinition] = [
        LevelDefinition(
            title: "PETAL PATH",
            tagline: "Find three love letters. Bring Honey home.",
            backgroundAsset: "BloomingPark",
            worldWidth: 5_400,
            runSpeed: 250,
            puppy: PuppySpec(name: "Honey", frame: 0, position: CGPoint(x: 3_280, y: 58)),
            exitX: 5_180,
            platforms: makePlatforms([
                (470, 105, 165, .picnic, .fixed), (805, 170, 150, .cloud, .fixed),
                (1_120, 112, 175, .stone, .fixed), (1_455, 188, 150, .picnic, .fixed),
                (1_780, 120, 170, .cloud, .fixed), (2_090, 205, 155, .stone, .fixed),
                (2_430, 128, 180, .picnic, .fixed), (2_760, 190, 150, .cloud, .fixed),
                (3_080, 112, 170, .stone, .fixed), (3_590, 168, 165, .picnic, .fixed),
                (3_930, 112, 155, .cloud, .fixed), (4_250, 198, 175, .stone, .fixed),
                (4_590, 126, 155, .picnic, .fixed), (4_910, 178, 170, .cloud, .fixed)
            ]),
            hazards: makeHazards([
                (685, 53, .puddle), (990, 53, .hedge), (1_315, 102, .branch),
                (1_650, 53, .thorns), (1_970, 53, .puddle), (2_290, 102, .branch),
                (2_625, 53, .hedge), (3_720, 53, .thorns), (4_065, 102, .branch),
                (4_410, 53, .puddle), (4_760, 53, .hedge), (5_035, 102, .branch)
            ]),
            bouncePads: [CGPoint(x: 1_520, y: 58), CGPoint(x: 4_330, y: 58)],
            pickups: makePickups(
                hearts: heartRibbon(from: 260, through: 5_050, step: 195, mission: 0),
                letters: [CGPoint(x: 1_175, y: 176), CGPoint(x: 2_155, y: 268), CGPoint(x: 2_820, y: 255)],
                golden: [CGPoint(x: 1_535, y: 285), CGPoint(x: 4_350, y: 292)]
            ),
            checkpoints: [2_040]
        ),
        LevelDefinition(
            title: "FOUNTAIN FLIGHT",
            tagline: "Ride the moving garden and rescue Bijou.",
            backgroundAsset: "BloomingPark",
            worldWidth: 6_050,
            runSpeed: 265,
            puppy: PuppySpec(name: "Bijou", frame: 1, position: CGPoint(x: 3_680, y: 58)),
            exitX: 5_820,
            platforms: makePlatforms([
                (450, 112, 170, .stone, .fixed), (770, 188, 155, .cloud, .moving),
                (1_105, 126, 180, .picnic, .fixed), (1_440, 220, 145, .cloud, .moving),
                (1_775, 142, 170, .stone, .fixed), (2_110, 205, 155, .picnic, .moving),
                (2_445, 118, 180, .cloud, .fixed), (2_785, 224, 150, .stone, .moving),
                (3_120, 138, 165, .picnic, .fixed), (3_455, 192, 160, .cloud, .fixed),
                (3_980, 128, 175, .stone, .moving), (4_320, 215, 150, .picnic, .fixed),
                (4_660, 132, 180, .cloud, .moving), (5_010, 226, 150, .stone, .fixed),
                (5_355, 142, 175, .picnic, .moving), (5_675, 190, 150, .cloud, .fixed)
            ]),
            hazards: makeHazards([
                (650, 53, .hedge), (965, 102, .branch), (1_290, 53, .puddle),
                (1_630, 53, .thorns), (1_975, 102, .branch), (2_310, 53, .hedge),
                (2_660, 53, .puddle), (3_010, 102, .branch), (3_350, 53, .thorns),
                (3_900, 53, .hedge), (4_220, 102, .branch), (4_545, 53, .puddle),
                (4_890, 53, .thorns), (5_235, 102, .branch), (5_565, 53, .hedge)
            ]),
            bouncePads: [CGPoint(x: 1_495, y: 58), CGPoint(x: 2_840, y: 58), CGPoint(x: 5_065, y: 58)],
            pickups: makePickups(
                hearts: heartRibbon(from: 250, through: 5_700, step: 188, mission: 1),
                letters: [CGPoint(x: 815, y: 252), CGPoint(x: 2_165, y: 270), CGPoint(x: 3_170, y: 202)],
                golden: [CGPoint(x: 1_510, y: 302), CGPoint(x: 5_080, y: 310)]
            ),
            checkpoints: [1_980]
        ),
        LevelDefinition(
            title: "ROSE RUSH",
            tagline: "Outrun the collapsing garden and save Velvet.",
            backgroundAsset: "BloomingPark",
            worldWidth: 6_650,
            runSpeed: 280,
            puppy: PuppySpec(name: "Velvet", frame: 2, position: CGPoint(x: 4_050, y: 58)),
            exitX: 6_400,
            platforms: makePlatforms([
                (440, 120, 170, .picnic, .fixed), (760, 202, 150, .cloud, .crumbling),
                (1_095, 132, 180, .stone, .fixed), (1_430, 218, 150, .picnic, .moving),
                (1_770, 145, 165, .cloud, .crumbling), (2_105, 230, 150, .stone, .fixed),
                (2_445, 130, 180, .picnic, .moving), (2_790, 214, 150, .cloud, .crumbling),
                (3_125, 142, 170, .stone, .fixed), (3_470, 232, 145, .picnic, .moving),
                (3_810, 132, 180, .cloud, .fixed), (4_330, 210, 150, .stone, .crumbling),
                (4_675, 138, 175, .picnic, .moving), (5_020, 230, 145, .cloud, .crumbling),
                (5_365, 145, 180, .stone, .fixed), (5_715, 215, 150, .picnic, .moving),
                (6_040, 130, 170, .cloud, .crumbling), (6_320, 205, 145, .stone, .fixed)
            ]),
            hazards: makeHazards([
                (640, 53, .thorns), (955, 102, .branch), (1_280, 53, .hedge),
                (1_615, 53, .puddle), (1_955, 102, .branch), (2_290, 53, .thorns),
                (2_635, 53, .hedge), (2_980, 102, .branch), (3_320, 53, .puddle),
                (3_670, 53, .thorns), (4_280, 102, .branch), (4_610, 53, .hedge),
                (4_950, 53, .puddle), (5_290, 102, .branch), (5_635, 53, .thorns),
                (5_960, 53, .hedge), (6_240, 102, .branch)
            ]),
            bouncePads: [CGPoint(x: 1_485, y: 58), CGPoint(x: 3_525, y: 58), CGPoint(x: 5_770, y: 58)],
            pickups: makePickups(
                hearts: heartRibbon(from: 245, through: 6_280, step: 182, mission: 2),
                letters: [CGPoint(x: 1_480, y: 302), CGPoint(x: 2_845, y: 278), CGPoint(x: 3_525, y: 315)],
                golden: [CGPoint(x: 2_160, y: 312), CGPoint(x: 5_780, y: 300)]
            ),
            checkpoints: [2_180]
        )
    ]

    private static func makePlatforms(_ values: [(CGFloat, CGFloat, CGFloat, PlatformStyle, PlatformBehavior)]) -> [PlatformSpec] {
        values.map { PlatformSpec(rect: CGRect(x: $0.0, y: $0.1, width: $0.2, height: 24), style: $0.3, behavior: $0.4) }
    }

    private static func makeHazards(_ values: [(CGFloat, CGFloat, HazardStyle)]) -> [HazardSpec] {
        values.map {
            let size: CGSize
            switch $0.2 {
            case .hedge: size = CGSize(width: 64, height: 42)
            case .branch: size = CGSize(width: 92, height: 38)
            default: size = CGSize(width: 82, height: 18)
            }
            return HazardSpec(rect: CGRect(origin: CGPoint(x: $0.0, y: $0.1), size: size), style: $0.2)
        }
    }

    private static func makePickups(hearts: [CGPoint], letters: [CGPoint], golden: [CGPoint]) -> [PickupSpec] {
        hearts.map { PickupSpec(position: $0, style: .heart) }
            + letters.map { PickupSpec(position: $0, style: .letter) }
            + golden.map { PickupSpec(position: $0, style: .goldenHeart) }
    }

    private static func heartRibbon(from start: CGFloat, through end: CGFloat, step: CGFloat, mission: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        var x = start
        var index = 0
        while x <= end {
            let pattern = (index * 47 + mission * 31) % 145
            points.append(CGPoint(x: x, y: 104 + CGFloat(pattern)))
            x += step
            index += 1
        }
        return points
    }
}
