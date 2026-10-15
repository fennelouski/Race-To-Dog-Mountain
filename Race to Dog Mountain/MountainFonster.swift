// Name-based avatars adapted from Nathan’s Fonsters.
// See Tools/ReleaseChecks/fonster-provenance.json for exact source hashes.


//
//  CreatureTypes.swift
//  Fonsters
//
//  Types for the deterministic creature avatar generator. Matches the web
//  implementation (nathanfennel.com creature-avatar) so the same seed
//  produces the same 32×32 image. Grid cells are color index 0–5 or -1 (transparent).
//

import Foundation

/// Grid width and height; creature is always 32×32.
public let GRID_SIZE = 32

/// Cell value: -1 = transparent, 0–5 = index into palette.
public typealias CellColorIndex = Int8

public typealias Grid = [[CellColorIndex]]

/// 1–5; derived from seed hash (content-sensitive). Drives which features (eyes, mouth, appendages, etc.) are allowed.
public typealias ComplexityTier = Int

/// Body/head mask shape.
public enum CoreShape: String, CaseIterable {
    case circle
    case ellipse
    case triangle
    case pentagon
    case hexagon
    case septagon
    case octagon
}

public enum EyeShape: String, CaseIterable {
    case square
    case circle
    case ellipse
    case triangle
    case pentagon
    case hexagon
    case septagon
    case octagon
}

public enum AvatarMode: String, CaseIterable {
    case creature
    case cloud
    case flower
    case repeating
    case space
}

public enum SymmetryAxis: String, CaseIterable {
    case vertical
    case horizontal
}

/// Resolved config for one generation; all decisions come from segment hash of the seed.
public struct CreatureConfig {
    public var avatarMode: AvatarMode
    public var symmetryAxis: SymmetryAxis
    public var complexityTier: ComplexityTier
    public var palette: [String]
    public var hasOpaqueBackground: Bool
    public var creatureType: String
    public var symmetricVertical: Bool
    public var symmetricDiagonal: Bool
    public var upsideDown: Bool
    public var shapeMask: ShapeMask
    public var ellipseAspect: (Double, Double)
    public var eyeShape: EyeShape
    public var hasEyes: Bool
    public var hasMouth: Bool
    public var mouthStyle: String
    public var hasNose: Bool
    public var noseParams: (Int, Int, Int, Int)
    public var hasBody: Bool
    public var hasHair: Bool
    public var hasEyebrows: Bool
    public var hasBeard: Bool
    public var hasEars: Bool
    public var hasHorn: Bool
    public var hasAntlers: Bool
    public var hasAppendages: Bool
    public var appendageCount: Int
    public var appendageStyle: String
    public var appendageRadial: Bool
}

public enum ShapeMask {
    case rect
    case shape(CoreShape)
}

//
//  CreatureConstants.swift
//  Fonsters
//
//  Probability constants (CreaturePROB) and palettes (PALETTES) used by the
//  generator. Values match the web app so outputs are identical for the same seed.
//

import Foundation

/// Probabilities for avatar mode, features (eyes, mouth, etc.); all in [0, 1].
public struct CreaturePROB {
    public static let avatarModeCloud: Double = 0.01
    public static let avatarModeFlower: Double = 0.01
    public static let avatarModeRepeating: Double = 0.01
    public static let avatarModeSpace: Double = 0.01
    public static let symmetryAxisHorizontal: Double = 0.04
    public static let creatureTypeAnimal: Double = 0.7
    public static let creatureTypeAlien: Double = 0.2
    public static let symmetricVertical: Double = 0.98
    public static let symmetricDiagonal: Double = 0.09
    public static let upsideDown: Double = 0.06
    public static let shapeCircleOrEllipse: Double = 0.35
    public static let shapePolygon: Double = 0.5
    public static let hasEyes: Double = 0.95
    public static let hasMouth: Double = 0.55
    public static let mouthNeutral: Double = 0.4
    public static let mouthOpen: Double = 0.2
    public static let mouthSmiling: Double = 0.4
    public static let hasNose: Double = 0.23
    public static let hasBody: Double = 0.17
    public static let hasHair: Double = 0.04
    public static let hasEyebrows: Double = 0.38
    public static let hasBeard: Double = 0.26
    public static let hasEars: Double = 0.07
    public static let hasHorn: Double = 0.18
    public static let hasAntlers: Double = 0.12
    public static let opaqueBackground: Double = 0.11
}

public let POLYGON_SIDES: [String: Int] = [
    "triangle": 3,
    "pentagon": 5,
    "hexagon": 6,
    "septagon": 7,
    "octagon": 8
]

public let PALETTES: [[String]] = [
    ["#1a1a2e", "#e94560", "#0f3460", "#16213e", "#533483", "#0d7377"],
    ["#2d132c", "#ee4540", "#c72c41", "#801336", "#ffc947", "#14ffec"],
    ["#0d0221", "#0f084b", "#c2e9fb", "#a0e7e5", "#e94560", "#4e9f3d"],
    ["#1b262c", "#0f4c75", "#3282b8", "#bbe1fa", "#1e5128", "#ff6b6b"],
    ["#2c003e", "#4a0e4e", "#fe346e", "#ffc947", "#0d7377", "#a0e7e5"],
    ["#0c0c0c", "#1e5128", "#4e9f3d", "#d8e9a8", "#801336", "#c2e9fb"],
    ["#212121", "#323232", "#0d7377", "#14ffec", "#e94560", "#d8e9a8"],
    ["#1a1a2e", "#16213e", "#e94560", "#0f3460", "#4e9f3d", "#ffab91"],
    ["#2d132c", "#801336", "#c72c41", "#ee4540", "#0f4c75", "#14ffec"],
    ["#0f0f23", "#1a1a3e", "#ff6b6b", "#4ecdc4", "#533483", "#1e5128"],
    ["#1b1b2f", "#162447", "#e43f5a", "#1f4068", "#0d7377", "#ffc947"],
    ["#0c1445", "#1a237e", "#ffab91", "#80deea", "#4e9f3d", "#c72c41"],
]

public let TRANSPARENT = "transparent"

//
//  CreatureHash.swift
//  Fonsters
//
//  Hash the seed ONCE to produce 256 bits. Each segment uses a different COMBINATION
//  of those bits (keyed by segmentId). The string is never used directly—only its
//  hash. Any change to the string changes the entire hash, so all segments change.
//

import Foundation

private let DJB2_INIT: UInt32 = 5381

private func mix32(_ h: UInt32, _ byte: UInt8) -> UInt32 {
    ((h << 5) &+ h) ^ UInt32(byte)
}

/// MurmurHash3-style finalizer: avalanches bits so similar inputs produce very different outputs.
private func fmix32(_ h: UInt32) -> UInt32 {
    var k = h
    k ^= k >> 16
    k = k &* 0x85ebca6b
    k ^= k >> 13
    k = k &* 0xc2b2ae35
    k ^= k >> 16
    return k
}

/// Hash the seed string ONCE. Returns 8×32-bit lanes.
/// Each character updates ALL lanes (with position-dependent mixing) so that adding,
/// removing, or changing any character changes the entire hash. Length is not used.
private func seedHash256(_ seed: String) -> (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) {
    var lanes: [UInt32] = [
        DJB2_INIT, DJB2_INIT + 1, DJB2_INIT + 2, DJB2_INIT + 3,
        DJB2_INIT + 4, DJB2_INIT + 5, DJB2_INIT + 6, DJB2_INIT + 7
    ]
    let utf16 = Array(seed.utf16)
    for (i, codeUnit) in utf16.enumerated() {
        let low = UInt8(codeUnit & 0xFF)
        let high = UInt8((codeUnit >> 8) & 0xFF)
        for lane in 0..<8 {
            let k = UInt32(i) &* 31 &+ UInt32(lane) &* 17
            lanes[lane] = mix32(lanes[lane], low ^ UInt8((k >> 0) & 0xFF))
            lanes[lane] = mix32(lanes[lane], high ^ UInt8((k >> 8) & 0xFF))
        }
    }
    return (
        fmix32(lanes[0]), fmix32(lanes[1]), fmix32(lanes[2]), fmix32(lanes[3]),
        fmix32(lanes[4]), fmix32(lanes[5]), fmix32(lanes[6]), fmix32(lanes[7])
    )
}

/// 53-bit mixer from segmentId. Used to pick which combination of seed-hash bits we use.
private func segmentMixer53(_ segmentId: String) -> UInt64 {
    var lo: UInt32 = 5381
    var hi: UInt32 = 5381
    for (j, byte) in segmentId.utf8.enumerated() {
        let b = UInt32(byte)
        if j % 2 == 0 {
            lo = ((lo << 5) &+ lo) ^ b
        } else {
            hi = ((hi << 5) &+ hi) ^ b
        }
    }
    return (UInt64(fmix32(hi)) << 21) | UInt64(fmix32(lo) >> 11)
}

/// Returns a value in [0, 1) for the given seed and segment id.
/// Uses the seed hash ONCE; segmentId's 53-bit mixer picks how we combine those 256 bits.
/// No string properties—only hash-derived bits.
public func segmentHash(seed: String, segmentId: String) -> Double {
    let (l0, l1, l2, l3, l4, l5, l6, l7) = seedHash256(seed)
    let m53 = segmentMixer53(segmentId)
    // Extract 8 values (6 bits each) from the 53-bit mixer; use as per-lane XOR masks.
    let m0 = UInt32((m53 >> 0) & 0x3F), m1 = UInt32((m53 >> 6) & 0x3F)
    let m2 = UInt32((m53 >> 12) & 0x3F), m3 = UInt32((m53 >> 18) & 0x3F)
    let m4 = UInt32((m53 >> 24) & 0x3F), m5 = UInt32((m53 >> 30) & 0x3F)
    let m6 = UInt32((m53 >> 36) & 0x3F), m7 = UInt32((m53 >> 42) & 0x3F)
    let l0m = l0 ^ (m0 &* 0x01010101), l1m = l1 ^ (m1 &* 0x01010101)
    let l2m = l2 ^ (m2 &* 0x01010101), l3m = l3 ^ (m3 &* 0x01010101)
    let l4m = l4 ^ (m4 &* 0x01010101), l5m = l5 ^ (m5 &* 0x01010101)
    let l6m = l6 ^ (m6 &* 0x01010101), l7m = l7 ^ (m7 &* 0x01010101)
    let low = l0m ^ l2m ^ l4m ^ l6m
    let high = l1m ^ l3m ^ l5m ^ l7m
    var top53 = (UInt64(high) << 21) | (UInt64(low) >> 11)
    // Uniformity finalizer: ensures segmentHash is uniformly distributed in [0, 1)
    // so segmentRoll triggers as intended (mouth, nose, body, eyebrows, etc.).
    top53 = (top53 &* 0x9E3779B97F4A7C15) >> 11
    return Double(top53) / 9007199254740992.0  // 2^53
}

/// Pick an option index 0..(n-1) from segment hash.
public func segmentPick(seed: String, segmentId: String, n: Int) -> Int {
    guard n > 0 else { return 0 }
    let u = segmentHash(seed: seed, segmentId: segmentId)
    return Int(floor(u * Double(n))) % n
}

/// Roll: returns true with probability p (0..1).
public func segmentRoll(seed: String, segmentId: String, p: Double) -> Bool {
    return segmentHash(seed: seed, segmentId: segmentId) < p
}

//
//  CreatureGenerator.swift
//  Fonsters
//
//  Deterministic 32×32 creature (or cloud/flower/repeating/space) grid generator.
//  Uses resolveConfig(seed) for all decisions, then draws into a Grid. Same seed
//  always produces the same grid. Ported from the TypeScript implementation.
//

import Foundation

private let CORE_SHAPES: [CoreShape] = [.circle, .ellipse, .triangle, .pentagon, .hexagon, .septagon, .octagon]
private let EYE_SHAPES: [EyeShape] = [.square, .circle, .ellipse, .triangle, .pentagon, .hexagon, .septagon, .octagon]

/// Complexity 3–5 derived from seed hash. Tier 1–2 (plain circles) are never used.
public func getComplexityTier(seed: String) -> ComplexityTier {
    return 3 + segmentPick(seed: seed, segmentId: "complexity_tier", n: 3)  // 3, 4, or 5
}

/// Resolves full creature config from seed using segment hash for every decision.
public func resolveConfig(seed: String) -> CreatureConfig {
    let tier = getComplexityTier(seed: seed)

    let uMode = segmentHash(seed: seed, segmentId: "avatar_mode")
    let avatarMode: AvatarMode
    if uMode < CreaturePROB.avatarModeCloud { avatarMode = .cloud }
    else if uMode < CreaturePROB.avatarModeCloud + CreaturePROB.avatarModeFlower { avatarMode = .flower }
    else if uMode < CreaturePROB.avatarModeCloud + CreaturePROB.avatarModeFlower + CreaturePROB.avatarModeRepeating { avatarMode = .repeating }
    else if uMode < CreaturePROB.avatarModeCloud + CreaturePROB.avatarModeFlower + CreaturePROB.avatarModeRepeating + CreaturePROB.avatarModeSpace { avatarMode = .space }
    else { avatarMode = .creature }

    let symmetryAxis: SymmetryAxis = segmentRoll(seed: seed, segmentId: "symmetry_axis", p: CreaturePROB.symmetryAxisHorizontal) ? .horizontal : .vertical

    let paletteIndex = segmentPick(seed: seed, segmentId: "palette", n: PALETTES.count)
    let rawPalette = PALETTES[paletteIndex]
    let numColors: Int
    if tier == 1 || tier == 2 { numColors = 2 }
    else if tier == 3 { numColors = 2 }
    else if tier == 4 { numColors = 3 }
    else { numColors = 4 + segmentPick(seed: seed, segmentId: "num_colors", n: 3) }
    let palette = Array(rawPalette.prefix(numColors))

    let hasOpaqueBackground = tier >= 4 && segmentRoll(seed: seed, segmentId: "opaque_bg", p: CreaturePROB.opaqueBackground)

    var creatureType = "animal"
    if tier >= 4 {
        let u = segmentHash(seed: seed, segmentId: "creature_type")
        if u < CreaturePROB.creatureTypeAnimal { creatureType = "animal" }
        else if u < CreaturePROB.creatureTypeAnimal + CreaturePROB.creatureTypeAlien { creatureType = "alien" }
        else { creatureType = "other" }
    }

    let symmetricVertical = tier == 1 || tier == 2 || (tier >= 3 && segmentRoll(seed: seed, segmentId: "sym_vertical", p: CreaturePROB.symmetricVertical))
    let symmetricDiagonal = tier >= 4 && segmentRoll(seed: seed, segmentId: "sym_diagonal", p: CreaturePROB.symmetricDiagonal)
    let upsideDown = tier >= 4 && segmentRoll(seed: seed, segmentId: "upside_down", p: CreaturePROB.upsideDown)

    var shapeMask: ShapeMask = .rect
    if tier == 1 { shapeMask = .shape(.circle) }
    else if tier >= 4 {
        if segmentRoll(seed: seed, segmentId: "shape_mask", p: CreaturePROB.shapeCircleOrEllipse) {
            shapeMask = segmentHash(seed: seed, segmentId: "shape_kind") < 0.5 ? .shape(.circle) : .shape(.ellipse)
        } else if segmentRoll(seed: seed, segmentId: "shape_polygon", p: CreaturePROB.shapePolygon) {
            let idx = 2 + segmentPick(seed: seed, segmentId: "shape_poly_kind", n: 5)
            shapeMask = .shape(CORE_SHAPES[idx])
        }
    }

    let ellipseAspect = (
        0.85 + segmentHash(seed: seed, segmentId: "ellipse_rx") * 0.3,
        0.85 + segmentHash(seed: seed, segmentId: "ellipse_ry") * 0.3
    )

    let hasEyes = tier >= 3 && segmentRoll(seed: seed, segmentId: "eyes", p: CreaturePROB.hasEyes)
    let eyeShape: EyeShape = tier >= 3 && hasEyes ? EYE_SHAPES[segmentPick(seed: seed, segmentId: "eye_shape", n: EYE_SHAPES.count)] : .square
    let hasMouth = tier >= 3 && segmentRoll(seed: seed, segmentId: "mouth", p: CreaturePROB.hasMouth)
    var mouthStyle = "neutral"
    if hasMouth && tier >= 4 {
        let u = segmentHash(seed: seed, segmentId: "mouth_style")
        if u < CreaturePROB.mouthNeutral { mouthStyle = "neutral" }
        else if u < CreaturePROB.mouthNeutral + CreaturePROB.mouthOpen { mouthStyle = "open" }
        else { mouthStyle = "smiling" }
    }

    let hasNose = tier >= 4 && segmentRoll(seed: seed, segmentId: "nose", p: CreaturePROB.hasNose)
    let noseParams = (
        segmentPick(seed: seed, segmentId: "nose_0", n: 3),
        segmentPick(seed: seed, segmentId: "nose_1", n: 3),
        segmentPick(seed: seed, segmentId: "nose_2", n: 3),
        segmentPick(seed: seed, segmentId: "nose_3", n: 3)
    )

    let hasBody = tier >= 4 && segmentRoll(seed: seed, segmentId: "body", p: CreaturePROB.hasBody)
    let hasHair = tier >= 4 && segmentRoll(seed: seed, segmentId: "hair", p: CreaturePROB.hasHair)
    let hasEyebrows = tier >= 4 && segmentRoll(seed: seed, segmentId: "eyebrows", p: CreaturePROB.hasEyebrows)
    let hasBeard = tier >= 4 && segmentRoll(seed: seed, segmentId: "beard", p: CreaturePROB.hasBeard)
    let hasEars = tier >= 4 && segmentRoll(seed: seed, segmentId: "ears", p: CreaturePROB.hasEars)
    let hasHorn = tier >= 4 && segmentRoll(seed: seed, segmentId: "horn", p: CreaturePROB.hasHorn)
    let hasAntlers = tier >= 4 && segmentRoll(seed: seed, segmentId: "antlers", p: CreaturePROB.hasAntlers)

    let hasAppendages = tier >= 3 && segmentRoll(seed: seed, segmentId: "appendages", p: 0.55)
    let appendageCount = hasAppendages ? [4, 6, 8][segmentPick(seed: seed, segmentId: "appendage_count", n: 3)] : 4
    let appendageStyle = hasAppendages ? ["tentacle", "arm", "leg"][segmentPick(seed: seed, segmentId: "appendage_style", n: 3)] : "arm"
    let appendageRadial = hasAppendages && segmentRoll(seed: seed, segmentId: "appendage_radial", p: 0.6)

    // Ensure at least 3 of the 5 most prominent features are enabled (eyes, mouth, appendages, body, eyebrows).
    var hasEyesFinal = hasEyes
    var hasMouthFinal = hasMouth
    var hasBodyFinal = hasBody
    var hasEyebrowsFinal = hasEyebrows
    var hasAppendagesFinal = hasAppendages
    if avatarMode == .creature && tier >= 3 {
        var enabled = [hasEyesFinal, hasMouthFinal, hasAppendagesFinal, hasBodyFinal, hasEyebrowsFinal]
        var toEnable = 3 - enabled.filter { $0 }.count
        var boostStep = 0
        while toEnable > 0 {
            var disabledIndices: [Int] = []
            for (i, on) in enabled.enumerated() where !on { disabledIndices.append(i) }
            guard !disabledIndices.isEmpty else { break }
            let pick = segmentPick(seed: seed, segmentId: "prominent_boost_\(boostStep)", n: disabledIndices.count)
            enabled[disabledIndices[pick]] = true
            toEnable -= 1
            boostStep += 1
        }
        hasEyesFinal = enabled[0]
        hasMouthFinal = enabled[1]
        hasAppendagesFinal = enabled[2]
        hasBodyFinal = enabled[3]
        hasEyebrowsFinal = enabled[4]
    }

    return CreatureConfig(
        avatarMode: avatarMode,
        symmetryAxis: symmetryAxis,
        complexityTier: tier,
        palette: palette,
        hasOpaqueBackground: hasOpaqueBackground,
        creatureType: creatureType,
        symmetricVertical: symmetricVertical,
        symmetricDiagonal: symmetricDiagonal,
        upsideDown: upsideDown,
        shapeMask: shapeMask,
        ellipseAspect: ellipseAspect,
        eyeShape: hasEyesFinal ? eyeShape : .square,
        hasEyes: hasEyesFinal,
        hasMouth: hasMouthFinal,
        mouthStyle: mouthStyle,
        hasNose: hasNose,
        noseParams: noseParams,
        hasBody: hasBodyFinal,
        hasHair: hasHair,
        hasEyebrows: hasEyebrowsFinal,
        hasBeard: hasBeard,
        hasEars: hasEars,
        hasHorn: hasHorn,
        hasAntlers: hasAntlers,
        hasAppendages: hasAppendagesFinal,
        appendageCount: appendageCount,
        appendageStyle: appendageStyle,
        appendageRadial: appendageRadial
    )
}

// MARK: - Geometry

private func inCircle(x: Double, y: Double, cx: Double, cy: Double, r: Double) -> Bool {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
}

private func inEllipse(x: Double, y: Double, cx: Double, cy: Double, rx: Double, ry: Double) -> Bool {
    return ((x - cx) * (x - cx)) / (rx * rx) + ((y - cy) * (y - cy)) / (ry * ry) <= 1
}

private func inPolygon(px: Double, py: Double, cx: Double, cy: Double, r: Double, nSides: Int) -> Bool {
    var vertices: [(x: Double, y: Double)] = []
    for i in 0..<nSides {
        let angle = (2 * Double.pi * Double(i)) / Double(nSides) - Double.pi / 2
        vertices.append((cx + r * cos(angle), cy + r * sin(angle)))
    }
    var inside = false
    var j = nSides - 1
    for i in 0..<nSides {
        let xi = vertices[i].x, yi = vertices[i].y
        let xj = vertices[j].x, yj = vertices[j].y
        if (yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi {
            inside.toggle()
        }
        j = i
    }
    return inside
}

private func inCoreShape(x: Double, y: Double, cx: Double, cy: Double, r: Double, shape: ShapeMask, ellipseAspect: (Double, Double)) -> Bool {
    switch shape {
    case .rect: return true
    case .shape(.circle): return inCircle(x: x, y: y, cx: cx, cy: cy, r: r)
    case .shape(.ellipse): return inEllipse(x: x, y: y, cx: cx, cy: cy, rx: r * ellipseAspect.0, ry: r * ellipseAspect.1)
    case .shape(let s):
        if let n = POLYGON_SIDES[s.rawValue] {
            return inPolygon(px: x, py: y, cx: cx, cy: cy, r: r, nSides: n)
        }
        return false
    }
}

private func inEyeShape(px: Double, py: Double, eyeCx: Double, eyeCy: Double, shape: EyeShape, size: Double) -> Bool {
    switch shape {
    case .square: return abs(px - eyeCx) <= size && abs(py - eyeCy) <= size
    case .circle: return inCircle(x: px, y: py, cx: eyeCx, cy: eyeCy, r: size)
    case .ellipse: return inEllipse(x: px, y: py, cx: eyeCx, cy: eyeCy, rx: size * 1.2, ry: size * 0.8)
    default:
        if let n = POLYGON_SIDES[shape.rawValue] {
            return inPolygon(px: px, py: py, cx: eyeCx, cy: eyeCy, r: size, nSides: n)
        }
        return false
    }
}

private func setPixel(grid: inout Grid, x: Double, y: Double, idx: CellColorIndex) {
    let ix = Int(round(x)), iy = Int(round(y))
    if ix >= 0 && ix < GRID_SIZE && iy >= 0 && iy < GRID_SIZE {
        grid[iy][ix] = idx
    }
}

private func drawThickLine(grid: inout Grid, x0: Double, y0: Double, angleDeg: Double, length: Double, thicknessStart: Double, idx: CellColorIndex, taperEnd: Double = 1) {
    let rad = angleDeg * .pi / 180
    let dx = cos(rad), dy = sin(rad)
    let steps = max(2, Int(ceil(length)))
    for s in 0...steps {
        let t = Double(s) / Double(steps)
        let thickness = taperEnd >= 1 ? thicknessStart : thicknessStart * (1 - t * (1 - taperEnd))
        let x = x0 + dx * length * t
        let y = y0 + dy * length * t
        let th = Int(round(thickness))
        if th <= 1 {
            setPixel(grid: &grid, x: x, y: y, idx: idx)
        } else {
            let r = Double(max(1, th))
            for oy in Int(-r)...Int(r) {
                for ox in Int(-r)...Int(r) {
                    if Double(ox * ox + oy * oy) <= r * r + 0.5 {
                        setPixel(grid: &grid, x: x + Double(ox), y: y + Double(oy), idx: idx)
                    }
                }
            }
        }
    }
}

private func drawAppendages(seed: String, config: CreatureConfig, grid: inout Grid, midX: Double, headRadius: Double, headCyLogical: Double, fillColorIndex: CellColorIndex) {
    if !config.hasAppendages { return }
    let n = config.appendageCount
    let baseThickness: Double = config.appendageStyle == "tentacle" ? 1 : 2
    let baseLength = 6 + segmentHash(seed: seed, segmentId: "append_len") * 6
    let countLeft = n / 2
    let startR = headRadius + 1.5
    let headCyDisplay = config.upsideDown ? Double(GRID_SIZE - 1) - headCyLogical : headCyLogical
    let cx = midX - 0.5, cy = headCyDisplay - 0.5
    let taperEnd = segmentRoll(seed: seed, segmentId: "append_taper", p: 0.4) ? 0.4 : 1.0

    var leftAngles: [Double] = []
    if config.appendageRadial {
        for i in 0..<countLeft {
            leftAngles.append(90 + (180 * Double(i + 1)) / Double(countLeft + 1))
        }
    } else {
        for i in 0..<countLeft {
            leftAngles.append(120 + (120 * Double(i)) / Double(max(1, countLeft - 1)))
        }
    }

    for (i, baseAngle) in leftAngles.enumerated() {
        var angle = baseAngle + (segmentHash(seed: seed, segmentId: "leg_angle_\(i)") - 0.5) * 36
        if config.upsideDown { angle = 360 - angle }
        let len = baseLength + segmentHash(seed: seed, segmentId: "append_\(i)") * 4
        let thickness = Double(max(1, Int(baseThickness) + segmentPick(seed: seed, segmentId: "leg_thick_\(i)", n: 3) - 1))
        let rad = angle * .pi / 180
        let x0 = cx + startR * cos(rad)
        let y0 = cy + startR * sin(rad)
        drawThickLine(grid: &grid, x0: x0, y0: y0, angleDeg: angle, length: len, thicknessStart: thickness, idx: fillColorIndex, taperEnd: taperEnd)
    }
}

private func applyShapeMask(grid: inout Grid, config: CreatureConfig) {
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    let r = Double(min(GRID_SIZE, GRID_SIZE)) / 2 - 0.5
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let inside = inCoreShape(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r, shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            if !inside { grid[y][x] = -1 }
        }
    }
}

// MARK: - Draw modes

private func drawCloud(seed: String, config: CreatureConfig, grid: inout Grid) {
    let fill: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent: CellColorIndex = config.palette.count > 2 ? 2 : fill
    let midY = Double(GRID_SIZE - 1) / 2
    let yMax = config.symmetryAxis == .horizontal ? Int(ceil(midY)) : GRID_SIZE
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid[y][x] = config.hasOpaqueBackground ? 0 : -1
        }
    }
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    let n = 4 + segmentPick(seed: seed, segmentId: "cloud_n", n: 4)
    var blobs: [(bx: Double, by: Double, r: Double, c: Int)] = []
    for i in 0..<n {
        let bx = cx + (segmentHash(seed: seed, segmentId: "cloud_x_\(i)") - 0.5) * 20
        let by = cy + (segmentHash(seed: seed, segmentId: "cloud_y_\(i)") - 0.5) * 16
        let r = 5 + segmentHash(seed: seed, segmentId: "cloud_r_\(i)") * 6
        blobs.append((bx, by, r, i % 2 == 0 ? 1 : 0))
    }
    for y in 0..<yMax {
        for x in 0..<GRID_SIZE {
            for b in blobs {
                if inCircle(x: Double(x), y: Double(y), cx: b.bx, cy: b.by, r: b.r) {
                    grid[y][x] = b.c == 0 ? fill : accent
                    break
                }
            }
        }
    }
}

private func drawFlower(seed: String, config: CreatureConfig, grid: inout Grid) {
    let fill: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = config.palette.count > 3 ? 3 : accent1
    let midY = Double(GRID_SIZE - 1) / 2
    let yMax = config.symmetryAxis == .horizontal ? Int(ceil(midY)) : GRID_SIZE
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid[y][x] = config.hasOpaqueBackground ? 0 : -1
        }
    }
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    let centerR = 3 + segmentHash(seed: seed, segmentId: "flower_center") * 2
    let petalCount = 5 + segmentPick(seed: seed, segmentId: "flower_petals", n: 5)
    let petalR = 4 + segmentHash(seed: seed, segmentId: "flower_pr") * 3
    for y in 0..<yMax {
        for x in 0..<GRID_SIZE {
            if inCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: centerR) {
                grid[y][x] = accent1
                continue
            }
            for i in 0..<petalCount {
                let angle = (2 * Double.pi * Double(i)) / Double(petalCount) + segmentHash(seed: seed, segmentId: "flower_a_\(i)") * 0.5
                let px = cx + 8 * cos(angle)
                let py = cy + 8 * sin(angle)
                if inCircle(x: Double(x), y: Double(y), cx: px, cy: py, r: petalR) {
                    grid[y][x] = segmentHash(seed: seed, segmentId: "flower_c_\(i)") < 0.5 ? fill : accent2
                    break
                }
            }
        }
    }
}

private func drawRepeating(seed: String, config: CreatureConfig, grid: inout Grid) {
    let tileSize = 4 + segmentPick(seed: seed, segmentId: "tile_size", n: 2)
    let fill: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = config.palette.count > 3 ? 3 : accent1
    let midY = Double(GRID_SIZE - 1) / 2
    let yMax = config.symmetryAxis == .horizontal ? Int(ceil(midY)) : GRID_SIZE
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid[y][x] = config.hasOpaqueBackground ? 0 : -1
        }
    }
    for dy in 0..<tileSize {
        for dx in 0..<tileSize {
            let u = segmentHash(seed: seed, segmentId: "tile_\(dy)_\(dx)")
            let v = segmentHash(seed: seed, segmentId: "tile_c_\(dy)_\(dx)")
            let idx: CellColorIndex = u < 0.4 ? fill : (v < 0.5 ? accent1 : accent2)
            var ty = 0
            while ty < yMax {
                var tx = 0
                while tx < GRID_SIZE {
                    let y = ty + dy
                    let x = tx + dx
                    if y < yMax && x < GRID_SIZE { grid[y][x] = idx }
                    tx += tileSize
                }
                ty += tileSize
            }
        }
    }
}

private func drawSpace(seed: String, config: CreatureConfig, grid: inout Grid) {
    let fill: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = config.palette.count > 3 ? 3 : accent1
    let midY = Double(GRID_SIZE - 1) / 2
    let yMax = config.symmetryAxis == .horizontal ? Int(ceil(midY)) : GRID_SIZE
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid[y][x] = config.hasOpaqueBackground ? 0 : -1
        }
    }
    let kind = segmentPick(seed: seed, segmentId: "space_kind", n: 4)
    if kind == 0 {
        let moonR = 10 + segmentHash(seed: seed, segmentId: "moon_r") * 4
        for y in 0..<yMax {
            for x in 0..<GRID_SIZE {
                if inCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: moonR) { grid[y][x] = fill }
            }
        }
        let craters = 2 + segmentPick(seed: seed, segmentId: "moon_c", n: 3)
        for i in 0..<craters {
            let cpx = cx + (segmentHash(seed: seed, segmentId: "moon_cx_\(i)") - 0.5) * 12
            let cpy = cy + (segmentHash(seed: seed, segmentId: "moon_cy_\(i)") - 0.5) * 12
            let cr = 1.5 + segmentHash(seed: seed, segmentId: "moon_cr_\(i)") * 2
            for y in 0..<yMax {
                for x in 0..<GRID_SIZE {
                    if inCircle(x: Double(x), y: Double(y), cx: cpx, cy: cpy, r: cr) {
                        grid[y][x] = config.hasOpaqueBackground ? 0 : -1
                    }
                }
            }
        }
    } else if kind == 1 {
        let starCount = 15 + segmentPick(seed: seed, segmentId: "stars_n", n: 25)
        for i in 0..<starCount {
            let sx = segmentPick(seed: seed, segmentId: "star_x_\(i)", n: GRID_SIZE)
            let sy = segmentPick(seed: seed, segmentId: "star_y_\(i)", n: yMax)
            let c: CellColorIndex = segmentHash(seed: seed, segmentId: "star_c_\(i)") < 0.3 ? accent1 : accent2
            if sy < yMax {
                grid[sy][sx] = c
                if sx > 0 { grid[sy][sx - 1] = c }
                if sy > 0 { grid[sy - 1][sx] = c }
            }
        }
    } else if kind == 2 {
        let blobs = 5 + segmentPick(seed: seed, segmentId: "nebula_n", n: 6)
        for i in 0..<blobs {
            let bx = cx + (segmentHash(seed: seed, segmentId: "neb_x_\(i)") - 0.5) * 28
            let by = cy + (segmentHash(seed: seed, segmentId: "neb_y_\(i)") - 0.5) * 28
            let r = 4 + segmentHash(seed: seed, segmentId: "neb_r_\(i)") * 8
            let c: CellColorIndex = i % 2 == 0 ? fill : (segmentHash(seed: seed, segmentId: "neb_c_\(i)") < 0.5 ? accent1 : accent2)
            for y in 0..<yMax {
                for x in 0..<GRID_SIZE {
                    if inEllipse(x: Double(x), y: Double(y), cx: bx, cy: by, rx: r * 1.2, ry: r * 0.8) && grid[y][x] == (config.hasOpaqueBackground ? 0 : -1) {
                        grid[y][x] = c
                    }
                }
            }
        }
    } else {
        let armCount = 2 + segmentPick(seed: seed, segmentId: "galaxy_arms", n: 2)
        let baseR = 6 + segmentHash(seed: seed, segmentId: "galaxy_r") * 6
        for y in 0..<yMax {
            for x in 0..<GRID_SIZE {
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let dist = sqrt(dx * dx + dy * dy)
                let angle = atan2(dy, dx)
                let arm = Int((angle / (2 * Double.pi)) * Double(armCount) + segmentHash(seed: seed, segmentId: "galaxy_\(x)_\(y)") * 0.2) % armCount
                let spiral = dist < baseR + Double(armCount) * 3 && dist > segmentHash(seed: seed, segmentId: "galaxy_d_\(x)_\(y)") * baseR * 0.5
                if spiral {
                    grid[y][x] = segmentHash(seed: seed, segmentId: "galaxy_c_\(arm)") < 0.5 ? fill : accent1
                }
            }
        }
    }
}

private func drawHornAndAntlers(grid: inout Grid, config: CreatureConfig, midX: Double, headCy: Double, headRadius: Double, fillColorIndex: CellColorIndex) {
    if !config.hasHorn && !config.hasAntlers { return }
    let headCyDisplay = config.upsideDown ? Double(GRID_SIZE - 1) - headCy : headCy
    let topHeadRow = config.upsideDown ? headCyDisplay + headRadius : headCyDisplay - headRadius
    let dir: Double = config.upsideDown ? 1 : -1
    let ix = Int(round(midX))

    if config.hasHorn {
        for i in 0...4 {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                setPixel(grid: &grid, x: Double(ix), y: Double(row), idx: fillColorIndex)
                if ix - 1 >= 0 { setPixel(grid: &grid, x: Double(ix - 1), y: Double(row), idx: fillColorIndex) }
                if ix + 1 < GRID_SIZE { setPixel(grid: &grid, x: Double(ix + 1), y: Double(row), idx: fillColorIndex) }
            }
        }
    }

    if config.hasAntlers {
        let stemLen = 5
        let branchLen = 6.0
        for i in 0...stemLen {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                setPixel(grid: &grid, x: midX, y: Double(row), idx: fillColorIndex)
            }
        }
        let branchStartRow = topHeadRow + dir * Double(stemLen)
        drawThickLine(grid: &grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 135 : 225, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
        drawThickLine(grid: &grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 45 : 315, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
    }
}

private func drawCreature(seed: String, config: CreatureConfig, grid: inout Grid) {
    let tier = config.complexityTier
    let midX = Double(GRID_SIZE) / 2
    let midY = Double(GRID_SIZE) / 2

    let bgColorIndex: CellColorIndex = config.hasOpaqueBackground ? 0 : -1
    let fillColorIndex: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = 3

    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid[y][x] = config.hasOpaqueBackground && !config.palette.isEmpty ? 0 : -1
        }
    }

    if tier == 1 {
        let r = 10.0
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if inCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid[y][x] = fillColorIndex }
            }
        }
        return
    }

    if tier == 2 {
        let r = 9 + segmentHash(seed: seed, segmentId: "size") * 4
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if inCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid[y][x] = fillColorIndex }
            }
        }
        return
    }

    let mirrorX: (Double) -> Double = { x in x >= midX ? 2 * midX - 1 - x : x }
    let mirrorY: (Double) -> Double = { y in y >= midY ? 2 * midY - 1 - y : y }
    let headRadius = 11 + (config.creatureType == "alien" ? 2 : 0)
    let headCy = config.hasBody ? midY - 4 : midY

    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let logicalY = config.upsideDown ? Double(GRID_SIZE - 1 - y) : Double(y)
            let mx = config.symmetryAxis == .vertical && config.symmetricVertical ? mirrorX(Double(x)) : Double(x)
            let my = config.symmetryAxis == .horizontal && config.symmetricVertical ? mirrorY(logicalY) : logicalY

            let inHead: Bool
            switch config.shapeMask {
            case .rect:
                inHead = inCircle(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius))
            case .shape:
                inHead = inCoreShape(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius), shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            }

            var idx: CellColorIndex = bgColorIndex
            if inHead {
                idx = fillColorIndex
                if config.hasEyes && tier >= 4 {
                    let eyeY = headCy - 3
                    let eyeDx = 4.0
                    let eyeSize = 1.4
                    if inEyeShape(px: mx, py: my, eyeCx: midX - eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1 }
                    if inEyeShape(px: mx, py: my, eyeCx: midX + eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1 }
                }
                if config.hasMouth && tier >= 4 && my >= headCy + 2 && my <= headCy + 5 && abs(mx - midX) <= 3 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                }
                if config.hasNose && tier >= 4 {
                    let noseY = headCy
                    if my >= noseY - 1 && my <= noseY + 2 && abs(mx - midX) <= 2 { idx = accent1 }
                }
                if config.hasEyebrows && tier >= 4 && my >= headCy - 6 && my <= headCy - 4 {
                    if (mx >= midX - 5 && mx <= midX - 2) || (mx >= midX + 2 && mx <= midX + 5) {
                        idx = config.palette.count > 2 ? accent2 : accent1
                    }
                }
                if config.hasBeard && tier >= 4 && my >= headCy + 5 && my <= headCy + 10 && abs(mx - midX) <= 5 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                }
            }
            if config.hasEars && tier >= 4 {
                let earCy = headCy - 2
                let earCx = midX - Double(headRadius) - 1.5
                if inCircle(x: mx, y: my, cx: earCx, cy: earCy, r: 2.5) { idx = fillColorIndex }
            }
            if config.hasBody && tier >= 4 && my > midY + 6 {
                if abs(mx - midX) <= 8 { idx = fillColorIndex }
            }
            if config.hasHair && tier >= 4 && my < headCy - Double(headRadius) + 2 {
                if abs(mx - midX) <= 6 { idx = config.palette.count > 2 ? accent2 : accent1 }
            }
            if idx != -1 && config.palette.count <= Int(idx) { idx = fillColorIndex }
            let outY = config.upsideDown ? GRID_SIZE - 1 - y : y
            grid[outY][x] = idx
        }
    }

    drawHornAndAntlers(grid: &grid, config: config, midX: midX, headCy: headCy, headRadius: Double(headRadius), fillColorIndex: fillColorIndex)
    drawAppendages(seed: seed, config: config, grid: &grid, midX: midX, headRadius: Double(headRadius), headCyLogical: headCy, fillColorIndex: fillColorIndex)

    if config.symmetricVertical {
        if config.symmetryAxis == .vertical {
            for y in 0..<GRID_SIZE {
                for x in Int(ceil(midX))..<GRID_SIZE {
                    let srcX = Int(floor(2 * midX - 1 - Double(x)))
                    if srcX >= 0 { grid[y][x] = grid[y][srcX] }
                }
            }
        } else {
            for x in 0..<GRID_SIZE {
                for y in Int(ceil(midY))..<GRID_SIZE {
                    let srcY = Int(floor(2 * midY - 1 - Double(y)))
                    if srcY >= 0 { grid[y][x] = grid[srcY][x] }
                }
            }
        }
    }

    if config.symmetricVertical && segmentRoll(seed: seed, segmentId: "asym_enable", p: 0.25) {
        let nAsym = segmentPick(seed: seed, segmentId: "asym_count", n: 5)
        let rightStart = Int(ceil(midX))
        let rightWidth = GRID_SIZE - rightStart
        for i in 0..<nAsym {
            let ax = rightStart + segmentPick(seed: seed, segmentId: "asym_x_\(i)", n: max(1, rightWidth))
            let ay = segmentPick(seed: seed, segmentId: "asym_y_\(i)", n: GRID_SIZE)
            let ac = segmentPick(seed: seed, segmentId: "asym_c_\(i)", n: config.palette.count)
            if ay >= 0 && ay < GRID_SIZE && ax >= 0 && ax < GRID_SIZE {
                grid[ay][ax] = Int8(min(ac, 5))
            }
        }
    }

    applyShapeMask(grid: &grid, config: config)
}

// MARK: - Public API

/// Produces a 32×32 grid for the given seed. Deterministic; empty seed treated as " ".
public func generateCreatureGrid(seed: String) -> Grid {
    let effectiveSeed = seed.isEmpty ? " " : seed
    let config = resolveConfig(seed: effectiveSeed)
    var grid: Grid = (0..<GRID_SIZE).map { _ in (0..<GRID_SIZE).map { _ in -1 } }

    switch config.avatarMode {
    case .cloud: drawCloud(seed: effectiveSeed, config: config, grid: &grid)
    case .flower: drawFlower(seed: effectiveSeed, config: config, grid: &grid)
    case .repeating: drawRepeating(seed: effectiveSeed, config: config, grid: &grid)
    case .space: drawSpace(seed: effectiveSeed, config: config, grid: &grid)
    default: drawCreature(seed: effectiveSeed, config: config, grid: &grid)
    }

    if config.avatarMode != .creature && config.symmetryAxis == .horizontal {
        let midY = Double(GRID_SIZE - 1) / 2
        for x in 0..<GRID_SIZE {
            for y in Int(ceil(midY))..<GRID_SIZE {
                let srcY = Int(floor(2 * midY - 1 - Double(y)))
                if srcY >= 0 { grid[y][x] = grid[srcY][x] }
            }
        }
    }

    return grid
}

/// Returns palette (hex strings) and hasOpaqueBackground for the seed; used when rasterizing.
public func getPaletteForSeed(seed: String) -> (palette: [String], hasOpaqueBackground: Bool) {
    let config = resolveConfig(seed: seed.isEmpty ? " " : seed)
    return (config.palette, config.hasOpaqueBackground)
}

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Name identities use Fonsters' generator. Modern systems display cached fuzzy
/// 3D stills for exports. Visible modern avatars use the live 3D window.
@MainActor enum MountainFonster {
    private static let images = NSCache<NSString, CGImage>()
    private static let portraits = NSCache<NSString, CGImage>()
    private static var lastRequest: Task<CGImage?, Never>?
    private static var lastRequestID: UUID?

    static func portrait(seed: String) async -> CGImage? {
        if let cached = portraits.object(forKey: seed as NSString) { return cached }
        guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else { return image(seed: seed) }
        let predecessor = lastRequest
        let requestID = UUID()
        let request = Task { @MainActor in
            _ = await predecessor?.value
            guard !Task.isCancelled else { return nil as CGImage? }
            if let cached = portraits.object(forKey: seed as NSString) { return cached }
            guard let rendered = try? await MountainFuzzyPortrait.render(seed: seed), !Task.isCancelled else { return nil }
            portraits.countLimit = 64
            portraits.totalCostLimit = 16 * 1024 * 1024
            portraits.setObject(rendered, forKey: seed as NSString, cost: rendered.bytesPerRow * rendered.height)
            return rendered
        }
        lastRequest = request; lastRequestID = requestID
        let rendered = await withTaskCancellationHandler(operation: { await request.value }, onCancel: { request.cancel() })
        if lastRequestID == requestID { lastRequest = nil; lastRequestID = nil }
        return rendered
    }

    static func image(seed: String) -> CGImage? {
        let key = seed as NSString
        if let cached = images.object(forKey: key) { return cached }
        let grid = generateCreatureGrid(seed: seed)
        let config = resolveConfig(seed: seed)
        let palette = getPaletteForSeed(seed: seed).palette
        func softColor(_ index: Int) -> CGColor {
            let defaults = ["#202A32", "#88AAAA", "#CCCCCC", "#FFFFFF", "#888888", "#DDDDDD"]
            let hex = UInt32((palette.indices.contains(index) ? palette[index] : defaults[min(index, 5)]).dropFirst(), radix: 16) ?? 0x88AAAA
            let components = [16, 8, 0].map { shift in Double((hex >> shift) & 255) / 255 }
            return CGColor(red: components[0] * 0.5 + 0.5, green: components[1] * 0.5 + 0.475, blue: components[2] * 0.5 + 0.41, alpha: 1)
        }
        guard let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 512,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: 128); context.scaleBy(x: 1, y: -1)
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE where grid[y][x] >= 0 {
                context.setFillColor(softColor(Int(grid[y][x])))
                context.addPath(CGPath(roundedRect: CGRect(x: x * 4, y: y * 4, width: 4, height: 4), cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)); context.fillPath()
            }
        }
        // Fonsters' tier-three grid has no face. Give every creature a soft,
        // legible expression at 48pt while retaining its exact seeded silhouette.
        if config.avatarMode == .creature {
            let head = Double(config.hasBody ? 12 : 16) * 4
            let centerY = config.upsideDown ? 128 - head : head
            context.setFillColor(softColor(config.hasOpaqueBackground ? 1 : 0))
            context.fillEllipse(in: CGRect(x: 40, y: centerY - 21, width: 48, height: 44))
            for x in [52.0, 76.0] {
                context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.91, alpha: 1))
                context.fillEllipse(in: CGRect(x: x - 7, y: centerY - 12, width: 14, height: 16))
                context.setFillColor(CGColor(red: 0.025, green: 0.12, blue: 0.17, alpha: 1))
                context.fillEllipse(in: CGRect(x: x - 3, y: centerY - 7, width: 6, height: 8))
            }
            context.setStrokeColor(CGColor(red: 0.025, green: 0.12, blue: 0.17, alpha: 0.9)); context.setLineWidth(3); context.setLineCap(.round)
            context.move(to: CGPoint(x: 56, y: centerY + 12)); context.addQuadCurve(to: CGPoint(x: 72, y: centerY + 12), control: CGPoint(x: 64, y: centerY + 21)); context.strokePath()
        }
        guard let image = context.makeImage() else { return nil }
        images.countLimit = 128; images.setObject(image, forKey: key, cost: 65536)
        return image
    }
}

struct MountainAvatar: View {
    let name: String
    var symbol = "person.fill"
    var style = "fonster"
    var photoID: String? = nil
    var size: CGFloat = 48
    @State private var photo: CGImage?
    var activity = MountainAvatarActivity()
    var body: some View {
        Group {
            if style == "photo" {
                if let photo {
                    Image(decorative: photo, scale: 1).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill").resizable().scaledToFit().padding(size * 0.2)
                }
            } else if style == "symbol" {
                Image(systemName: symbol).resizable().scaledToFit().padding(size * 0.2)
            } else if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
                MountainFonsterWindow(seed: name, size: size, activity: activity)
                    .id(name)
            } else if let generated = MountainFonster.image(seed: name) {
                Image(decorative: generated, scale: 1).resizable().scaledToFit().padding(size * 0.05)
            }
        }.frame(width: size, height: size).background(MountainStyle.cream.opacity(0.12), in: Circle())
            .clipShape(Circle()).accessibilityHidden(true)
            .task(id: [name, style, photoID ?? ""]) {
                photo = nil
                guard style != "symbol" else { return }
                if style == "photo", let photoID {
                    let loaded = await Task.detached(priority: .userInitiated) { MountainAvatarPhotos.read(photoID) }.value
                    guard !Task.isCancelled, self.photoID == photoID, style == "photo" else { return }
                    photo = loaded
                    if loaded != nil { return }
                }
            }
    }
}

/// Only picker-selected, downsampled JPEGs are kept locally; no photo bytes travel
/// through saves, Game Center, Messages, exports, or external-display snapshots.
enum MountainAvatarPhotos {
    private static func url(_ id: String) -> URL? {
        guard UUID(uuidString: id) != nil else { return nil }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MountainAvatars", isDirectory: true).appendingPathComponent(id + ".jpg")
    }
    static func prepare(_ data: Data) -> Data? {
        guard data.count <= 25_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 256] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= 262_144 else { return nil }
        return output as Data
    }
    static func save(_ data: Data) throws -> String {
        let id = UUID().uuidString
        guard data.count <= 262_144, let target = url(id) else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
        return id
    }
    static func read(_ id: String) -> CGImage? {
        guard let target = url(id), let data = try? Data(contentsOf: target), data.count <= 262_144,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
