// Fuzzy 3D portraits reuse Nathan's native Fonsters geometry and studio lighting.
// Source hashes and adaptations: Tools/ReleaseChecks/fuzzy-fonster-provenance.json.
// No AR session, camera, microphone, network, or continuous renderer is created.
import Foundation
import CoreGraphics
import simd

/// Each request produces one local 256px image. The caller serializes requests,
/// caches the result, and releases the GPU renderer before the next portrait.
@available(macOS 15.0, iOS 18.0, visionOS 2.0, *)
@MainActor enum MountainFuzzyPortrait {
    static func render(seed: String) async throws -> CGImage {
        try Task.checkCancellation()
        // Race keeps the resulting still, so temporary 3D surface meshes need
        // not remain cached after completion, failure, or cancellation.
        defer { MountainPortraitCreatureFur.releaseCachedSurfaces() }
        guard let device = MTLCreateSystemDefaultDevice() else { throw CocoaError(.featureUnsupported) }
        let appearance = MountainPortraitCreatureAppearanceDescriptor.resolve(seed: seed)
        let rig = try MountainPortraitCreatureRig(appearance, furDetail: .portrait)
        // Some legacy seeds have no face. Their resolved fuzzy volume stays
        // intact; a portrait-only expression makes those identities welcoming.
        if !appearance.supported {
            let bounds = rig.head.visualBounds(relativeTo: rig.head)
            let center = bounds.center
            let spacing = min(0.34, bounds.extents.x * 0.17)
            let radius = min(0.14, max(0.065, bounds.extents.x * 0.075))
            for x in [-spacing, spacing] {
                let location = center + SIMD3<Float>(x, bounds.extents.y * 0.09, bounds.extents.z / 2 + 0.035)
                _ = rig.ball(MountainPortraitFonsterPlatformColor(srgbRed: 0.98, green: 0.96, blue: 0.88, alpha: 1),
                             scale: [radius, radius * 1.12, radius * 0.65], at: location, parent: rig.head)
                _ = rig.ball(MountainPortraitFonsterPlatformColor(srgbRed: 0.035, green: 0.07, blue: 0.09, alpha: 1),
                             scale: [radius * 0.48, radius * 0.64, radius * 0.32],
                             at: location + [0.015, 0, radius * 0.61], parent: rig.head)
                _ = rig.ball(.white, scale: .init(repeating: radius * 0.17),
                             at: location + [-0.014, radius * 0.28, radius * 0.91], parent: rig.head)
            }
            try rig.addMouth()
            rig.mouth?.position = center + [0, -bounds.extents.y * 0.15, bounds.extents.z / 2 + 0.035]
        }
        rig.express(smile: 0.72, smilingEyes: 0.15, opening: 0.9)
        rig.root.orientation = simd_quatf(angle: -0.16, axis: [0, 1, 0])
        let bounds = rig.root.visualBounds(relativeTo: nil)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 33
        camera.camera.near = 0.01; camera.camera.far = 100
        let distance = max(bounds.extents.x, bounds.extents.y) * 0.5 / tan(Float.pi * 33 / 360) * 1.22 + bounds.extents.z / 2
        camera.look(at: bounds.center, from: bounds.center + [0, 0.08, max(2, distance)], relativeTo: nil)
        let key = DirectionalLight()
        key.light.intensity = 1800
        key.light.color = MountainPortraitFonsterPlatformColor(srgbRed: 1, green: 0.9, blue: 0.8, alpha: 1)
        key.look(at: .zero, from: [-2, 4, 3], relativeTo: nil)
        var entities: [Entity] = [rig.root, camera, key]
        entities.append(try await MountainPortraitCreatureSceneLighting.studio(for: entities))
        try Task.checkCancellation()
        let renderer = try RealityRenderer()
        renderer.entities.append(contentsOf: entities)
        renderer.activeCamera = camera
        renderer.cameraSettings.colorBackground = .color(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        let side = 256
        let description = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: side, height: side, mipmapped: false)
        description.usage = [.renderTarget, .shaderRead]; description.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: description) else { throw CocoaError(.featureUnsupported) }
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        // A bounded warm-up lets the native material/lighting resources resolve.
        for _ in 0..<5 {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do { try renderer.updateAndRender(deltaTime: 1.0 / 30, cameraOutput: output, onComplete: { _ in continuation.resume() }) }
                catch { continuation.resume(throwing: error) }
            }
        }
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        texture.getBytes(&bytes, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
}

// MARK: - Adapted from Fonsters/CreatureAvatar/CreatureRaster.swift
//
//  CreatureRaster.swift
//  Fonsters
//
//  Converts creature grid + palette to RGBA buffer, CGImage, and animated GIF.
//  Used for display (CreatureAvatarView), PNG export, and GIF export. Works on
//  iOS and macOS (UIKit/AppKit for image types).
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private let defaultHex = "#888888"

/// Boosts brightness and saturation by 20% each. All creature colors pass through this.
internal func boostColorBrightnessAndSaturation(r: UInt8, g: UInt8, b: UInt8) -> (UInt8, UInt8, UInt8) {
    let rn = Double(r) / 255, gn = Double(g) / 255, bn = Double(b) / 255
    let cmax = max(rn, gn, bn), cmin = min(rn, gn, bn)
    let delta = cmax - cmin
    var h: Double = 0, s: Double = 0
    let l = (cmax + cmin) / 2
    if delta > 0 {
        s = l <= 0.5 ? delta / (cmax + cmin) : delta / (2 - cmax - cmin)
        switch cmax {
        case rn: h = (gn - bn) / delta + (gn < bn ? 6 : 0)
        case gn: h = (bn - rn) / delta + 2
        default: h = (rn - gn) / delta + 4
        }
        h /= 6
    }
    let s2 = min(1, s * 1.2)
    let l2 = min(1, l * 1.2)
    // HSL to RGB
    guard s2 > 0 else {
        let v = UInt8(l2 * 255 + 0.5)
        return (v, v, v)
    }
    let q = l2 < 0.5 ? l2 * (1 + s2) : l2 + s2 - l2 * s2
    let p = 2 * l2 - q
    func hueToRgb(_ t: Double) -> Double {
        let tt = t < 0 ? t + 1 : (t > 1 ? t - 1 : t)
        if tt < 1/6 { return p + (q - p) * 6 * tt }
        if tt < 1/2 { return q }
        if tt < 2/3 { return p + (q - p) * (2/3 - tt) * 6 }
        return p
    }
    let r2 = UInt8(hueToRgb(h + 1/3) * 255 + 0.5)
    let g2 = UInt8(hueToRgb(h) * 255 + 0.5)
    let b2 = UInt8(hueToRgb(h - 1/3) * 255 + 0.5)
    return (min(255, r2), min(255, g2), min(255, b2))
}

private func hexToRgba(_ hex: String) -> (UInt8, UInt8, UInt8, UInt8) {
    if hex == TRANSPARENT { return (0, 0, 0, 0) }
    guard hex.hasPrefix("#"), let n = Int(hex.dropFirst(), radix: 16) else {
        return (0x88, 0x88, 0x88, 255)
    }
    let r = UInt8((n >> 16) & 0xFF)
    let g = UInt8((n >> 8) & 0xFF)
    let b = UInt8(n & 0xFF)
    let (r2, g2, b2) = boostColorBrightnessAndSaturation(r: r, g: g, b: b)
    // Retain Race's existing warm pastel treatment on the genuine 3D coat.
    return (UInt8(Double(r2) * 0.5 + 127.5), UInt8(Double(g2) * 0.5 + 121.125), UInt8(Double(b2) * 0.5 + 104.55), 255)
}

/// Fill RGBA buffer (32*32*4 bytes) from grid and palette.
public func gridToRgbaBuffer(grid: Grid, palette: [String], _ hasOpaqueBackground: Bool) -> [UInt8] {
    let colors: [(UInt8, UInt8, UInt8, UInt8)] = [
        hexToRgba(palette.indices.contains(0) ? palette[0] : "#000000"),
        hexToRgba(palette.indices.contains(1) ? palette[1] : defaultHex),
        hexToRgba(palette.indices.contains(2) ? palette[2] : "#cccccc"),
        hexToRgba(palette.indices.contains(3) ? palette[3] : "#ffffff"),
        hexToRgba(palette.indices.contains(4) ? palette[4] : defaultHex),
        hexToRgba(palette.indices.contains(5) ? palette[5] : "#dddddd"),
    ]
    var buf = [UInt8](repeating: 0, count: GRID_SIZE * GRID_SIZE * 4)
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let idx = grid[y][x]
            let i = (y * GRID_SIZE + x) * 4
            if idx == -1 {
                buf[i] = 0
                buf[i + 1] = 0
                buf[i + 2] = 0
                buf[i + 3] = 0
            } else {
                let c = colors[min(Int(idx), colors.count - 1)]
                buf[i] = c.0
                buf[i + 1] = c.1
                buf[i + 2] = c.2
                buf[i + 3] = c.3
            }
        }
    }
    return buf
}



// MARK: - Adapted from Fonsters/Playroom/ResolvedCreatureTrace.swift
// Version 1 trace of legacy creature geometry. Deliberately duplicates the frozen
// drawing decisions; every supported result is checked against generateCreatureGrid.
// Do not "fix" quirks here without bumping the descriptor version and fixtures.
import Foundation

final class MountainPortraitResolvedRasterTrace {
    var pixels: Grid = Array(repeating: Array(repeating: -1, count: 32), count: 32)
    var roles = Array(repeating: Array(repeating: "background", count: 32), count: 32)
    var beforeClipping: [[String]] = []
    var currentRole = "head"
    var headPixels: Set<Int> = []
    func set(x: Int, y: Int, index: Int8, role: String? = nil) {
        pixels[y][x] = index
        roles[y][x] = index == -1 ? "background" : (role ?? currentRole)
    }
    func mirror(x: Int, y: Int, sourceX: Int, sourceY: Int) {
        let source = roles[sourceY][sourceX]
        pixels[y][x] = pixels[sourceY][sourceX]
        roles[y][x] = source.replacingOccurrences(of: "L", with: "R")
    }
}

func MountainPortraittraceResolvedCreature(seed: String) -> MountainPortraitResolvedRasterTrace {
    let trace = MountainPortraitResolvedRasterTrace()
    resolvedDrawCreature(seed: seed, config: resolveConfig(seed: seed), grid: trace)
    return trace
}

private func resolvedInCircle(x: Double, y: Double, cx: Double, cy: Double, r: Double) -> Bool {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
}

private func resolvedInEllipse(x: Double, y: Double, cx: Double, cy: Double, rx: Double, ry: Double) -> Bool {
    return ((x - cx) * (x - cx)) / (rx * rx) + ((y - cy) * (y - cy)) / (ry * ry) <= 1
}

private func resolvedInPolygon(px: Double, py: Double, cx: Double, cy: Double, r: Double, nSides: Int) -> Bool {
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

private func resolvedInCoreShape(x: Double, y: Double, cx: Double, cy: Double, r: Double, shape: ShapeMask, ellipseAspect: (Double, Double)) -> Bool {
    switch shape {
    case .rect: return true
    case .shape(.circle): return resolvedInCircle(x: x, y: y, cx: cx, cy: cy, r: r)
    case .shape(.ellipse): return resolvedInEllipse(x: x, y: y, cx: cx, cy: cy, rx: r * ellipseAspect.0, ry: r * ellipseAspect.1)
    case .shape(let s):
        if let n = POLYGON_SIDES[s.rawValue] {
            return resolvedInPolygon(px: x, py: y, cx: cx, cy: cy, r: r, nSides: n)
        }
        return false
    }
}

private func resolvedInEyeShape(px: Double, py: Double, eyeCx: Double, eyeCy: Double, shape: EyeShape, size: Double) -> Bool {
    switch shape {
    case .square: return abs(px - eyeCx) <= size && abs(py - eyeCy) <= size
    case .circle: return resolvedInCircle(x: px, y: py, cx: eyeCx, cy: eyeCy, r: size)
    case .ellipse: return resolvedInEllipse(x: px, y: py, cx: eyeCx, cy: eyeCy, rx: size * 1.2, ry: size * 0.8)
    default:
        if let n = POLYGON_SIDES[shape.rawValue] {
            return resolvedInPolygon(px: px, py: py, cx: eyeCx, cy: eyeCy, r: size, nSides: n)
        }
        return false
    }
}

private func resolvedSetPixel(grid: MountainPortraitResolvedRasterTrace, x: Double, y: Double, idx: CellColorIndex) {
    let ix = Int(round(x)), iy = Int(round(y))
    if ix >= 0 && ix < GRID_SIZE && iy >= 0 && iy < GRID_SIZE {
        grid.set(x: ix, y: iy, index: idx)
    }
}

private func resolvedDrawThickLine(grid: MountainPortraitResolvedRasterTrace, x0: Double, y0: Double, angleDeg: Double, length: Double, thicknessStart: Double, idx: CellColorIndex, taperEnd: Double = 1) {
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
            resolvedSetPixel(grid: grid, x: x, y: y, idx: idx)
        } else {
            let r = Double(max(1, th))
            for oy in Int(-r)...Int(r) {
                for ox in Int(-r)...Int(r) {
                    if Double(ox * ox + oy * oy) <= r * r + 0.5 {
                        resolvedSetPixel(grid: grid, x: x + Double(ox), y: y + Double(oy), idx: idx)
                    }
                }
            }
        }
    }
}

private func resolvedDrawAppendages(seed: String, config: CreatureConfig, grid: MountainPortraitResolvedRasterTrace, midX: Double, headRadius: Double, headCyLogical: Double, fillColorIndex: CellColorIndex) {
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
        grid.currentRole = "limbL\(i)"
        var angle = baseAngle + (segmentHash(seed: seed, segmentId: "leg_angle_\(i)") - 0.5) * 36
        if config.upsideDown { angle = 360 - angle }
        let len = baseLength + segmentHash(seed: seed, segmentId: "append_\(i)") * 4
        let thickness = Double(max(1, Int(baseThickness) + segmentPick(seed: seed, segmentId: "leg_thick_\(i)", n: 3) - 1))
        let rad = angle * .pi / 180
        let x0 = cx + startR * cos(rad)
        let y0 = cy + startR * sin(rad)
        resolvedDrawThickLine(grid: grid, x0: x0, y0: y0, angleDeg: angle, length: len, thicknessStart: thickness, idx: fillColorIndex, taperEnd: taperEnd)
    }
}

private func resolvedApplyShapeMask(grid: MountainPortraitResolvedRasterTrace, config: CreatureConfig) {
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    let r = Double(min(GRID_SIZE, GRID_SIZE)) / 2 - 0.5
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let inside = resolvedInCoreShape(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r, shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            if !inside { grid.set(x: x, y: y, index: -1) }
        }
    }
}

// MARK: - Draw modes

private func resolvedDrawHornAndAntlers(grid: MountainPortraitResolvedRasterTrace, config: CreatureConfig, midX: Double, headCy: Double, headRadius: Double, fillColorIndex: CellColorIndex) {
    if !config.hasHorn && !config.hasAntlers { return }
    let headCyDisplay = config.upsideDown ? Double(GRID_SIZE - 1) - headCy : headCy
    let topHeadRow = config.upsideDown ? headCyDisplay + headRadius : headCyDisplay - headRadius
    let dir: Double = config.upsideDown ? 1 : -1
    let ix = Int(round(midX))

    if config.hasHorn {
        grid.currentRole = "horn"
        for i in 0...4 {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                resolvedSetPixel(grid: grid, x: Double(ix), y: Double(row), idx: fillColorIndex)
                if ix - 1 >= 0 { resolvedSetPixel(grid: grid, x: Double(ix - 1), y: Double(row), idx: fillColorIndex) }
                if ix + 1 < GRID_SIZE { resolvedSetPixel(grid: grid, x: Double(ix + 1), y: Double(row), idx: fillColorIndex) }
            }
        }
    }

    if config.hasAntlers {
        grid.currentRole = "antler"
        let stemLen = 5
        let branchLen = 6.0
        for i in 0...stemLen {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                resolvedSetPixel(grid: grid, x: midX, y: Double(row), idx: fillColorIndex)
            }
        }
        let branchStartRow = topHeadRow + dir * Double(stemLen)
        resolvedDrawThickLine(grid: grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 135 : 225, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
        resolvedDrawThickLine(grid: grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 45 : 315, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
    }
}

private func resolvedDrawCreature(seed: String, config: CreatureConfig, grid: MountainPortraitResolvedRasterTrace) {
    let tier = config.complexityTier
    let midX = Double(GRID_SIZE) / 2
    let midY = Double(GRID_SIZE) / 2

    let bgColorIndex: CellColorIndex = config.hasOpaqueBackground ? 0 : -1
    let fillColorIndex: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = 3

    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid.set(x: x, y: y, index: config.hasOpaqueBackground && !config.palette.isEmpty ? 0 : -1, role: "background")
        }
    }

    if tier == 1 {
        let r = 10.0
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if resolvedInCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid.set(x: x, y: y, index: fillColorIndex, role: "head") }
            }
        }
        return
    }

    if tier == 2 {
        let r = 9 + segmentHash(seed: seed, segmentId: "size") * 4
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if resolvedInCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid.set(x: x, y: y, index: fillColorIndex, role: "head") }
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
                inHead = resolvedInCircle(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius))
            case .shape:
                inHead = resolvedInCoreShape(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius), shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            }

            var idx: CellColorIndex = bgColorIndex
            var role = "background"
            if inHead {
                grid.headPixels.insert(y * 32 + x)
                idx = fillColorIndex
                role = "head"
                if config.hasEyes && tier >= 4 {
                    let eyeY = headCy - 3
                    let eyeDx = 4.0
                    let eyeSize = 1.4
                    if resolvedInEyeShape(px: mx, py: my, eyeCx: midX - eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1; role = "eyeL" }
                    if resolvedInEyeShape(px: mx, py: my, eyeCx: midX + eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1; role = "eyeR" }
                }
                if config.hasMouth && tier >= 4 && my >= headCy + 2 && my <= headCy + 5 && abs(mx - midX) <= 3 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                    role = "mouth"
                }
                if config.hasNose && tier >= 4 {
                    let noseY = headCy
                    if my >= noseY - 1 && my <= noseY + 2 && abs(mx - midX) <= 2 { idx = accent1; role = "nose" }
                }
                if config.hasEyebrows && tier >= 4 && my >= headCy - 6 && my <= headCy - 4 {
                    if (mx >= midX - 5 && mx <= midX - 2) || (mx >= midX + 2 && mx <= midX + 5) {
                        idx = config.palette.count > 2 ? accent2 : accent1
                        role = "brow"
                    }
                }
                if config.hasBeard && tier >= 4 && my >= headCy + 5 && my <= headCy + 10 && abs(mx - midX) <= 5 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                    role = "beard"
                }
            }
            if config.hasEars && tier >= 4 {
                let earCy = headCy - 2
                let earCx = midX - Double(headRadius) - 1.5
                if resolvedInCircle(x: mx, y: my, cx: earCx, cy: earCy, r: 2.5) { idx = fillColorIndex; role = "earL" }
            }
            if config.hasBody && tier >= 4 && my > midY + 6 {
                if abs(mx - midX) <= 8 { idx = fillColorIndex; role = "body" }
            }
            if config.hasHair && tier >= 4 && my < headCy - Double(headRadius) + 2 {
                if abs(mx - midX) <= 6 { idx = config.palette.count > 2 ? accent2 : accent1; role = "hair" }
            }
            if idx != -1 && config.palette.count <= Int(idx) { idx = fillColorIndex }
            let outY = config.upsideDown ? GRID_SIZE - 1 - y : y
            grid.set(x: x, y: outY, index: idx, role: role)
        }
    }

    resolvedDrawHornAndAntlers(grid: grid, config: config, midX: midX, headCy: headCy, headRadius: Double(headRadius), fillColorIndex: fillColorIndex)
    resolvedDrawAppendages(seed: seed, config: config, grid: grid, midX: midX, headRadius: Double(headRadius), headCyLogical: headCy, fillColorIndex: fillColorIndex)

    if config.symmetricVertical {
        if config.symmetryAxis == .vertical {
            for y in 0..<GRID_SIZE {
                for x in Int(ceil(midX))..<GRID_SIZE {
                    let srcX = Int(floor(2 * midX - 1 - Double(x)))
                    if srcX >= 0 { grid.mirror(x: x, y: y, sourceX: srcX, sourceY: y) }
                }
            }
        } else {
            for x in 0..<GRID_SIZE {
                for y in Int(ceil(midY))..<GRID_SIZE {
                    let srcY = Int(floor(2 * midY - 1 - Double(y)))
                    if srcY >= 0 { grid.mirror(x: x, y: y, sourceX: x, sourceY: srcY) }
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
                grid.set(x: ax, y: ay, index: Int8(min(ac, 5)), role: "marking")
            }
        }
    }

    grid.beforeClipping = grid.roles
    resolvedApplyShapeMask(grid: grid, config: config)
}



// MARK: - Adapted from Fonsters/Playroom/MountainPortraitCreatureAppearanceDescriptor.swift
import Foundation

/// Portable resolved appearance, never a private seed or user identifier.
/// v1 deliberately preserves the exact legacy raster, including clipping and draw order.
struct MountainPortraitCreatureAppearanceDescriptor: Codable, Equatable {
    static let currentVersion = 1
    let version: Int
    let legacyRendererVersion: String
    let palette: [String]
    let rgbaPalette: [[UInt8]]
    let raster: [Int8]
    let silhouette: [Pixel]
    let head: Head
    let parts: [Part]
    let clippingMask: String
    let supported: Bool
    let fallbackReason: String?
    /// Additive, versioned resolved geometry for families outside the original
    /// articulated rig. Existing v1 visit descriptors decode with nil here.
    var volume: Volume? = nil
    struct Volume: Codable, Equatable {
        let version: Int
        let family: String
        let pixels: [Pixel]
    }

    struct Pixel: Codable, Hashable { let x: Int; let y: Int }
    struct Head: Codable, Equatable {
        let shape: String
        let centerX: Double
        let centerY: Double
        let radius: Double
        let ellipseX: Double
        let ellipseY: Double
        let footprint: [Pixel]
    }
    struct Part: Codable, Equatable, Identifiable {
        let id: String
        let kind: String
        let style: String
        let pixels: [Pixel]
        let clippedPixels: [Pixel]
        let paletteIndices: [Int8]
        // Resolved visible extent is used for the joint, not the unbounded config length.
        var centerX: Double { Double(pixels.map(\.x).reduce(0, +)) / Double(max(1, pixels.count)) }
        var centerY: Double { Double(pixels.map(\.y).reduce(0, +)) / Double(max(1, pixels.count)) }
    }

    static func resolve(seed: String) -> Self {
        let effective = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
        let config = resolveConfig(seed: effective)
        let raster = generateCreatureGrid(seed: effective)
        let trace = MountainPortraittraceResolvedCreature(seed: effective)
        let familySupported = config.avatarMode == .creature && config.complexityTier >= 4 &&
            config.symmetryAxis == .vertical && config.symmetricVertical && !config.upsideDown
        let supported = familySupported && trace.pixels == raster
        let skin: Int8 = config.hasOpaqueBackground ? 1 : 0
        var groups: [String: [Pixel]] = [:], clipped: [String: [Pixel]] = [:]
        var headFootprint: [Pixel] = []
        var silhouette: [Pixel] = []
        for y in 0..<32 {
            for x in 0..<32 {
                let pixel = Pixel(x: x, y: y)
                if trace.headPixels.contains(y * 32 + x), raster[y][x] != -1 { headFootprint.append(pixel) }
                let role = trace.roles[y][x]
                guard role != "background", raster[y][x] >= 0 else {
                    if trace.beforeClipping.count == 32 {
                        let previous = trace.beforeClipping[y][x]
                        if previous != "background" { clipped[previous, default: []].append(pixel) }
                    }
                    continue
                }
                silhouette.append(pixel)
                // In a three-colour palette the legacy mouth/brows can collapse to skin.
                // Those flags do not create visible features; never invent them in 3D.
                let invisibleMark = ["mouth", "brow", "beard", "hair", "nose", "eyeL", "eyeR"].contains(role) && raster[y][x] == skin
                let visibleRole = invisibleMark ? "head" : (role == "brow" ? (x < 16 ? "browL" : "browR") : role)
                groups[visibleRole, default: []].append(pixel)
            }
        }
        let parts = groups.keys.sorted().map { role in
            let kind: String
            if role.hasPrefix("limb") { kind = "appendage" }
            else if role.hasPrefix("eye") { kind = "eye" }
            else if role.hasPrefix("ear") { kind = "ear" }
            else if role.hasPrefix("brow") { kind = "brow" }
            else { kind = role }
            return Part(id: role, kind: kind, style: kind == "appendage" ? config.appendageStyle : (kind == "eye" ? config.eyeShape.rawValue : kind),
                        pixels: groups[role]!, clippedPixels: clipped[role] ?? [],
                        paletteIndices: groups[role]!.map { raster[$0.y][$0.x] })
        }
        let mask: String
        switch config.shapeMask { case .rect: mask = "canvas"; case .shape(let shape): mask = shape.rawValue }
        let paletteRGBA = (0..<6).map { index -> [UInt8] in
            let testGrid: Grid = Array(repeating: Array(repeating: Int8(index), count: 32), count: 32)
            return Array(gridToRgbaBuffer(grid: testGrid, palette: config.palette, false).prefix(4))
        }
        var result = Self(version: currentVersion, legacyRendererVersion: "legacy-6e34657", palette: config.palette,
                    rgbaPalette: paletteRGBA, raster: raster.flatMap { $0 }, silhouette: silhouette,
                    head: Head(shape: mask == "canvas" ? "circle" : mask, centerX: 15.5,
                               centerY: (config.hasBody ? 12.0 : 16.0) - 0.5,
                               radius: config.creatureType == "alien" ? 13 : 11,
                               ellipseX: config.ellipseAspect.0, ellipseY: config.ellipseAspect.1, footprint: headFootprint),
                    parts: parts, clippingMask: mask, supported: supported,
                    fallbackReason: supported ? nil : "This appearance stays in its original 2D form. The first 3D family supports upright, vertically mirrored creatures with visible features.")
        if !supported {
            // Trace semantics are trustworthy only when they match the raster.
            // Other generator modes have their own actual foreground mask.
            let pixels: [Pixel]
            if config.avatarMode == .creature && trace.pixels == raster {
                pixels = silhouette
            } else {
                pixels = (0..<32).flatMap { y in (0..<32).compactMap { x in
                    raster[y][x] >= 0 && (!config.hasOpaqueBackground || raster[y][x] != 0) ? Pixel(x: x, y: y) : nil
                } }
            }
            result.volume = .init(version: 1, family: config.avatarMode.rawValue, pixels: pixels)
        }
        return result
    }
}

/// Closed colored volume with curved front/back and boundary walls. Unlike a
/// radial head, this preserves holes, asymmetry and disconnected islands.
struct MountainPortraitResolvedCreatureVolume {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var materials: [UInt32] = []
    static func make(_ appearance: MountainPortraitCreatureAppearanceDescriptor) -> Self {
        let pixels = appearance.volume?.pixels ?? appearance.silhouette
        let cells = Set(pixels.map { $0.y * 32 + $0.x })
        func filled(_ x: Int, _ y: Int) -> Bool { (0..<32).contains(x) && (0..<32).contains(y) && cells.contains(y * 32 + x) }
        var result = Self(), vertices: [Int: UInt32] = [:]
        func vertex(_ x: Int, _ y: Int, _ front: Bool, cellX: Int, cellY: Int) -> UInt32 {
            // Diagonal-only islands must not share the vertical boundary edge:
            // doing so would attach four wall faces to one non-manifold edge.
            let diagonal = (filled(x-1,y-1) && filled(x,y) && !filled(x,y-1) && !filled(x-1,y)) ||
                (filled(x,y-1) && filled(x-1,y) && !filled(x-1,y-1) && !filled(x,y))
            let sector = diagonal ? (cellX < x ? 1 : 2) : 0
            let key = ((y * 33 + x) * 2 + (front ? 1 : 0)) * 3 + sector
            if let saved = vertices[key] { return saved }
            // Distance to the nearest exposed cell determines rounded thickness.
            var edgeDistance: Float = 0
            for radius in 1...10 {
                let interior = (-radius..<radius).allSatisfy { dy in
                    (-radius..<radius).allSatisfy { dx in filled(x + dx, y + dy) }
                }
                if !interior { break }; edgeDistance = Float(radius)
            }
            let depth = 0.22 + 0.42 * sqrt(min(1, edgeDistance / 8))
            let index = UInt32(result.positions.count)
            result.positions.append([(Float(x) - 16) * 0.0625, (16 - Float(y)) * 0.0625, front ? depth : -depth])
            result.normals.append(.zero); vertices[key] = index; return index
        }
        func quad(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ palette: UInt32) {
            result.indices += [a, b, c, a, c, d]; result.materials += [palette, palette]
        }
        for p in pixels {
            let x = p.x, y = p.y, palette = UInt32(max(0, appearance.raster[y * 32 + x]))
            let corners = [(x,y), (x+1,y), (x+1,y+1), (x,y+1)]
            let f = corners.map { vertex($0.0, $0.1, true, cellX: x, cellY: y) }
            let b = corners.map { vertex($0.0, $0.1, false, cellX: x, cellY: y) }
            quad(f[0], f[3], f[2], f[1], palette); quad(b[0], b[1], b[2], b[3], palette)
            for (edge, nx, ny) in [(0,x,y-1), (1,x+1,y), (2,x,y+1), (3,x-1,y)] where !filled(nx, ny) {
                let next = (edge + 1) % 4; quad(f[edge], f[next], b[next], b[edge], palette)
            }
        }
        for i in stride(from: 0, to: result.indices.count, by: 3) {
            let ids = (0..<3).map { Int(result.indices[i + $0]) }
            let a = result.positions[ids[1]] - result.positions[ids[0]], b = result.positions[ids[2]] - result.positions[ids[0]]
            let n = SIMD3<Float>(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x)
            for id in ids { result.normals[id] += n }
        }
        result.normals = result.normals.map { n in n / max(0.000001, sqrt(n.x*n.x+n.y*n.y+n.z*n.z)) }
        return result
    }
}



// MARK: - Adapted from Fonsters/Playroom/MountainPortraitFonsterPlatformColor.swift
#if os(macOS)
import AppKit
typealias MountainPortraitFonsterPlatformColor = NSColor
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
typealias MountainPortraitFonsterPlatformColor = UIColor
extension UIColor {
    convenience init(srgbRed: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: srgbRed, green: green, blue: blue, alpha: alpha)
    }
}
#endif


// MARK: - Adapted from Fonsters/Playroom/MountainPortraitCreatureRig.swift
#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit
import Metal
import simd

@available(macOS 15.0, iOS 18.0, visionOS 2.0, tvOS 26.0, *)
@MainActor
final class MountainPortraitCreatureRig {
    enum FurDetail: String { case portrait, lobby, world }
    let root = Entity()
    let head = Entity()
    let descriptor: MountainPortraitCreatureAppearanceDescriptor
    var eyes: [Entity] = []
    var pupils: [Entity] = []
    var pupilTravel: [SIMD2<Float>] = []
    var mouth: Entity?
    private(set) var facialGeometry: MountainPortraitCreatureFacialGeometry?
    private var smilingLids: [(Entity, Float)] = []
    var expressionPhase: Float { Float(furSeed % 997) / 997 * 2 * .pi }
    var limbs: [(joint: Entity, bend: Entity, angle: Float)] = []
    let pixel: Float = 0.0625
    let depth: Float = 0.64
    var baseHead: SIMD3<Float> = .zero
    var groundOffset: Float = 0
    var brows: [Entity] = []
    private(set) var furStrands = 0
    private(set) var furTriangles = 0
    private(set) var furSurfaces = 0
    private(set) var groomedFaceStrands = 0
    private lazy var outlineRadii = headRadii()
    private lazy var furMaterials = MountainPortraitCreatureFur.materials(for: descriptor)
    private lazy var furSeed = MountainPortraitCreatureFur.seed(for: descriptor)
    private lazy var coatKey = MountainPortraitCreatureFur.appearanceKey(descriptor) + ":fur-v\(MountainPortraitCreatureFur.styleVersion):" + furDetail.rawValue
    let furDetail: FurDetail
    private var skinIndex = 0
    init(_ descriptor: MountainPortraitCreatureAppearanceDescriptor, furDetail: FurDetail = .portrait) throws {
        self.descriptor = descriptor
        self.furDetail = furDetail
        root.name = "companion"
        root.addChild(head)
        if !descriptor.supported {
            try addResolvedVolume()
            groundOffset = -1.08 - root.visualBounds(relativeTo: root).min.y
            return
        }
        let h = descriptor.head
        baseHead = point(h.centerX, h.centerY)
        head.position = baseHead
        skinIndex = Int(descriptor.parts.first(where: { $0.kind == "head" })?.paletteIndices.first ?? 0)
        let skin = color(skinIndex)
        var surface = material(skin)
        surface.roughness = .init(floatLiteral: 0.96); surface.clearcoat = .init(floatLiteral: 0)
        if let image = skinTexture(skinIndex: skinIndex) {
            let texture = try TextureResource(image: image, options: .init(semantic: .color))
            let sampler = MTLSamplerDescriptor()
            sampler.minFilter = .nearest; sampler.magFilter = .nearest
            surface.baseColor = .init(tint: .white, texture: .init(texture, sampler: .init(sampler)))
        }
        let mesh = try headMesh()
        let model = ModelEntity(mesh: mesh, materials: [surface, material(skin, roughness: 1)])
        model.name = "resolved-head"
        head.addChild(model)
        let coat = try MountainPortraitCreatureFur.surface(key: coatKey + ":head", name: "fuzzy-head") {
            MountainPortraitCreatureFur.head(descriptor, radii: outlineRadii, pixel: pixel, depth: depth, skinIndex: skinIndex,
                             count: furDetail == .portrait ? 22_000 : (furDetail == .lobby ? 7_000 : 2_800), toneVariation: furDetail == .portrait)
        }
        addCoat(coat, to: head, name: "fuzzy-head")
        groomedFaceStrands = coat.trimmedStrands
        for part in descriptor.parts {
            switch part.kind {
            case "eye": addEye(part)
            case "body": addBody(part, skin: skin)
            case "appendage": addLimb(part, skin: skin)
            case "ear": addEar(part, skin: skin)
            case "horn": addHorn(part, skin: skin)
            case "antler": addAntlers(part, skin: skin)
            case "brow": addBrow(part)
            case "nose": addNose(part)
            default: break // Texture carries hair, beard and markings; the happy mouth is added below.
            }
        }
        try addMouth()
        if let furError { throw furError }
        groundOffset = -1.08 - root.visualBounds(relativeTo: root).min.y
    }

    private func addResolvedVolume() throws {
        let geometry = MountainPortraitResolvedCreatureVolume.make(descriptor)
        guard !geometry.positions.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        var mesh = MeshDescriptor(name: "resolved-colored-volume-v1")
        mesh.positions = MeshBuffers.Positions(geometry.positions)
        mesh.normals = MeshBuffers.Normals(geometry.normals)
        mesh.primitives = .triangles(geometry.indices)
        mesh.materials = .perFace(geometry.materials)
        let body = ModelEntity(mesh: try MeshResource.generate(from: [mesh]), materials: (0..<6).map { material(color($0), roughness: 1) })
        body.name = "resolved-volumetric-body"; head.addChild(body)
        let coat = try MountainPortraitCreatureFur.surface(key: coatKey + ":resolved-volume", name: "fuzzy-resolved-volume") {
            MountainPortraitCreatureFur.volume(geometry, seed: furSeed, count: furDetail == .portrait ? 12000 : (furDetail == .lobby ? 4000 : 1800), toneVariation: furDetail == .portrait)
        }
        addCoat(coat, to: head, name: "fuzzy-resolved-volume")
    }

    func point(_ x: Double, _ y: Double, z: Float = 0) -> SIMD3<Float> {
        [(Float(x) - 15.5) * pixel, (15.5 - Float(y)) * pixel, z]
    }
    func color(_ index: Int) -> MountainPortraitFonsterPlatformColor {
        let p = descriptor.rgbaPalette[min(5, max(0, index))]
        return MountainPortraitFonsterPlatformColor(srgbRed: CGFloat(p[0]) / 255, green: CGFloat(p[1]) / 255,
                       blue: CGFloat(p[2]) / 255, alpha: 1)
    }
    func material(_ color: MountainPortraitFonsterPlatformColor, roughness: Float = 0.94) -> PhysicallyBasedMaterial {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.roughness = .init(floatLiteral: roughness)
        mat.metallic = .init(floatLiteral: 0)
        mat.specular = .init(floatLiteral: 0.12)
        mat.clearcoat = .init(floatLiteral: 0)
        mat.clearcoatRoughness = .init(floatLiteral: 0.35)
        return mat
    }
    func ball(_ color: MountainPortraitFonsterPlatformColor, radius: Float = 1, scale: SIMD3<Float>, at position: SIMD3<Float>, parent: Entity, furry: Bool = false) -> ModelEntity {
        var surface = material(color, roughness: furry ? 1 : 0.88)
        if furry { surface.clearcoat = .init(floatLiteral: 0) }
        let model = ModelEntity(mesh: .generateSphere(radius: radius), materials: [surface])
        model.scale = scale; model.position = position; parent.addChild(model)
        if furry {
            do {
                let coat = try MountainPortraitCreatureFur.surface(key: coatKey + ":surface:\(furSurfaces)", name: "fuzzy-surface-\(furSurfaces)") {
                    MountainPortraitCreatureFur.ellipsoid(axes: scale * radius, palette: skinIndex, seed: furSeed ^ UInt64(furSurfaces + 1),
                                          density: furDetail == .portrait ? 1 : (furDetail == .lobby ? 0.5 : 0.24), toneVariation: furDetail == .portrait)
                }
                addCoat(coat, to: model, name: "fuzzy-surface-\(furSurfaces)")
            }
            catch { furError = error }
        }
        return model
    }
    private var furError: Error?
    private func addCoat(_ surface: MountainPortraitCreatureFur.Surface, to parent: Entity, name: String) {
        let model = ModelEntity(mesh: surface.mesh, materials: furMaterials)
        model.name = name; parent.addChild(model)
        furStrands += surface.strands; furTriangles += surface.triangles; furSurfaces += 1
    }
    func extent(_ p: MountainPortraitCreatureAppearanceDescriptor.Part) -> (Float, Float) {
        (Float((p.pixels.map(\.x).max() ?? 0) - (p.pixels.map(\.x).min() ?? 0) + 1) * pixel,
         Float((p.pixels.map(\.y).max() ?? 0) - (p.pixels.map(\.y).min() ?? 0) + 1) * pixel)
    }
    func faceDepth(_ x: Double, _ y: Double) -> Float {
        let h = descriptor.head
        let dx = Float((x - h.centerX) / (h.radius * (h.shape == "ellipse" ? h.ellipseX : 1)))
        let dy = Float((y - h.centerY) / (h.radius * (h.shape == "ellipse" ? h.ellipseY : 1)))
        return depth * sqrt(max(0.12, 1 - dx * dx - dy * dy))
    }
    func facePosition(_ p: MountainPortraitCreatureAppearanceDescriptor.Part) -> SIMD3<Float> {
        point(p.centerX, p.centerY, z: faceDepth(p.centerX, p.centerY) + 0.025) - baseHead
    }

    // A closed, smooth volume: the legacy head outline is inflated through 40 rings.
    // The front and back have independent materials, and thickness is comparable to width.
    private func headRadii() -> [Float] {
        let h = descriptor.head
        let cells = Set(h.footprint.map { $0.y * 32 + $0.x })
        let around = 96
        var radii: [Float] = []
        for j in 0...around {
            let theta = Float(j) / Float(around) * 2 * .pi
            var radius: Float = 0
            for step in 0...400 {
                let r = Float(step) / 20
                let x = Int((Float(h.centerX) + r * cos(theta)).rounded())
                let y = Int((Float(h.centerY) - r * sin(theta)).rounded())
                if x < 0 || x >= 32 || y < 0 || y >= 32 || !cells.contains(y * 32 + x) { break }
                radius = r
            }
            radii.append(max(radius, 0.5))
        }
        // Suppress pixel stair steps without changing the overall resolved shape.
        for _ in 0..<3 {
            let old = radii
            for j in 0..<around { radii[j] = (old[(j + around - 1) % around] + 2 * old[j] + old[(j + 1) % around]) / 4 }
            radii[around] = radii[0]
        }
        return radii
    }
    func headMesh() throws -> MeshResource {
        let h = descriptor.head, radii = outlineRadii
        let around = radii.count - 1, rings = 40
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = []
        for i in 0...rings {
            let latitude = -Float.pi / 2 + Float(i) / Float(rings) * .pi
            for j in 0...around {
                let theta = Float(j) / Float(around) * 2 * .pi
                let r = radii[j] * pixel
                let x = r * cos(theta) * cos(latitude), y = r * sin(theta) * cos(latitude)
                let z = depth * sin(latitude)
                positions.append([x, y, z])
                normals.append(simd_normalize(SIMD3<Float>(x / max(0.01, r * r), y / max(0.01, r * r), z / (depth * depth))))
                uv.append([(x / pixel + Float(h.centerX) + 0.5) / 32,
                           (32 - (Float(h.centerY) - y / pixel + 0.5)) / 32])
            }
        }
        var indices: [UInt32] = [], materials: [UInt32] = []
        for i in 0..<rings {
            for j in 0..<around {
                let a = UInt32(i * (around + 1) + j), b = a + 1, c = a + UInt32(around + 1), d = c + 1
                indices += [a, b, c, b, d, c]
                materials += [i >= rings / 2 ? 0 : 1, i >= rings / 2 ? 0 : 1]
            }
        }
        var descriptor = MeshDescriptor(name: "inflated-resolved-silhouette-v1")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .perFace(materials)
        return try MeshResource.generate(from: [descriptor])
    }

    func skinTexture(skinIndex: Int) -> CGImage? {
        var grid = Array(repeating: Array(repeating: Int8(skinIndex), count: 32), count: 32)
        for part in descriptor.parts where ["beard", "hair", "marking"].contains(part.kind) {
            for (i, p) in part.pixels.enumerated() { grid[p.y][p.x] = part.paletteIndices[i] }
        }
        var bytes = gridToRgbaBuffer(grid: grid, palette: descriptor.palette, false)
        return bytes.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
                      bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    func addEye(_ part: MountainPortraitCreatureAppearanceDescriptor.Part) {
        let eye = Entity(); eye.name = part.id; eye.position = facePosition(part)
        let (w, h) = extent(part)
        // The resolved eye shape is retained as a rounded outline, with a glossy iris.
        let white = MountainPortraitFonsterPlatformColor(srgbRed: 0.98, green: 0.96, blue: 0.88, alpha: 1)
        if part.style == "square" {
            let model = ModelEntity(mesh: .generateBox(size: [w * 1.35, h * 1.35, 0.15], cornerRadius: 0.045), materials: [material(white, roughness: 0.65)])
            eye.addChild(model)
        } else {
            _ = ball(white, scale: [w * 0.74, h * 0.74, 0.13], at: .zero, parent: eye)
        }
        let pupil = Entity(); pupil.position = [0, 0, 0.105]
        _ = ball(color(Int(part.paletteIndices.first ?? 2)), scale: [w * 0.44, h * 0.44, 0.062], at: .zero, parent: pupil)
        _ = ball(MountainPortraitFonsterPlatformColor(srgbRed: 0.05, green: 0.035, blue: 0.07, alpha: 1), scale: [w * 0.21, h * 0.31, 0.045], at: [0, 0, 0.046], parent: pupil)
        _ = ball(.white, scale: [0.028, 0.028, 0.015], at: [-0.025, 0.034, 0.09], parent: pupil)
        eye.addChild(pupil); head.addChild(eye); eyes.append(eye); pupils.append(pupil); pupilTravel.append([w * 0.22, h * 0.20])
        let lid = ball(color(skinIndex), scale: [w * 0.76, h * 0.24, 0.095], at: [0, h * 0.96, 0.12], parent: eye)
        lid.name = "smiling-upper-lid"; lid.isEnabled = false; smilingLids.append((lid, h))
    }
    struct SmileLayout {
        let centerX: Double, centerY: Double
        let width: Float, height: Float
        let paletteIndex: Int
        let hasLegacyMouth: Bool
        /// Clockwise outline with raised corners and a gentle upper curve.
        var outline: [SIMD2<Float>] {
            let steps = 32
            func point(_ i: Int, lower: Bool) -> SIMD2<Float> {
                let t = Float(i) / Float(steps) * 2 - 1
                let y: Float = lower ? -0.52 + 0.82 * t * t : -0.02 + 0.32 * t * t
                return [t * width / 2, y * height]
            }
            return (0...steps).map { point($0, lower: false) } +
                (1..<steps).reversed().map { point($0, lower: true) }
        }
    }
    /// A render-only expression. The descriptor retains the exact original mouth,
    /// including absence; no identity, portrait, visit format or saved feeling changes.
    static func smileLayout(for descriptor: MountainPortraitCreatureAppearanceDescriptor) -> SmileLayout {
        let pixel: Float = 0.0625
        if let part = descriptor.parts.first(where: { $0.kind == "mouth" }) {
            let w = Float((part.pixels.map(\.x).max() ?? 0) - (part.pixels.map(\.x).min() ?? 0) + 1) * pixel
            let h = Float((part.pixels.map(\.y).max() ?? 0) - (part.pixels.map(\.y).min() ?? 0) + 1) * pixel
            return .init(centerX: part.centerX, centerY: part.centerY,
                         width: max(0.44, min(0.78, w * 1.32)), height: max(0.28, min(0.40, h * 0.90)),
                         paletteIndex: Int(part.paletteIndices.first ?? 3), hasLegacyMouth: true)
        }
        let h = descriptor.head
        let obstacles = descriptor.parts.filter { $0.kind == "eye" || $0.kind == "nose" }
            .flatMap(\.pixels).map(\.y).max().map { Double($0) + 1.6 } ?? h.centerY
        let y = min(h.centerY + h.radius * 0.72, max(h.centerY + h.radius * 0.40, obstacles))
        return .init(centerX: h.centerX, centerY: y, width: 0.48, height: 0.30,
                     paletteIndex: 3, hasLegacyMouth: false)
    }
    func addMouth() throws {
        let layout = Self.smileLayout(for: descriptor)
        let group = Entity(); group.name = "expressive-mouth"
        group.position = point(layout.centerX, layout.centerY, z: faceDepth(layout.centerX, layout.centerY) + 0.025) - baseHead
        var cavityMaterial = material(MountainPortraitFonsterPlatformColor(srgbRed: 0.085, green: 0.045, blue: 0.075, alpha: 1), roughness: 0.85)
        cavityMaterial.clearcoat = .init(floatLiteral: 0)
        let geometry = try MountainPortraitCreatureFacialGeometry(width: layout.width, height: layout.height,
            cavityMaterial: cavityMaterial, rimMaterial: material(color(layout.paletteIndex), roughness: 0.96))
        group.addChild(geometry.cavity); group.addChild(geometry.rim)
        facialGeometry = geometry; head.addChild(group); mouth = group
    }
    func express(smile: Float, smilingEyes: Float, opening: Float) {
        facialGeometry?.update(smile: smile, opening: opening)
        let lift = min(1, max(0, smilingEyes))
        for (lid, height) in smilingLids {
            lid.isEnabled = lift > 0.03
            lid.position.y = height * 0.96 - height * 0.14 * lift
        }
    }
    func addBrow(_ part: MountainPortraitCreatureAppearanceDescriptor.Part) {
        let (w, h) = extent(part)
        let brow = ModelEntity(mesh: .generateBox(size: [w, h, 0.05], cornerRadius: min(0.04, h * 0.25)),
                               materials: [material(color(Int(part.paletteIndices.first ?? 3)))])
        // The legacy raster's fixed brow band can overlap an enlarged 3D eye.
        // Resolve the nearest eye and leave room above its full expressive outline.
        if let eye = descriptor.parts.filter({ $0.kind == "eye" }).min(by: {
            abs($0.centerX - part.centerX) < abs($1.centerX - part.centerX)
        }) {
            let (_, eyeHeight) = extent(eye)
            let clearance = eyeHeight * 1.20 + h / 2 + 0.06
            let y = min(part.centerY, eye.centerY - Double(clearance / pixel))
            brow.position = point(eye.centerX, y, z: faceDepth(eye.centerX, y) + 0.04) - baseHead
        } else {
            brow.position = facePosition(part)
        }
        brow.name = part.id
        head.addChild(brow); brows.append(brow)
    }
    func addNose(_ part: MountainPortraitCreatureAppearanceDescriptor.Part) {
        let (w, h) = extent(part)
        _ = ball(color(Int(part.paletteIndices.first ?? 2)), scale: [w * 0.52, h * 0.51, 0.14], at: facePosition(part), parent: head)
    }
    func addBody(_ part: MountainPortraitCreatureAppearanceDescriptor.Part, skin: MountainPortraitFonsterPlatformColor) {
        let (w, h) = extent(part)
        let body = ball(skin, scale: [w * 0.52, h * 0.52, 0.4], at: point(part.centerX, part.centerY, z: -0.10), parent: root, furry: true)
        body.name = "body"
    }
    func addEar(_ part: MountainPortraitCreatureAppearanceDescriptor.Part, skin: MountainPortraitFonsterPlatformColor) {
        let (w, h) = extent(part)
        _ = ball(skin, scale: [w * 0.55, h * 0.55, 0.20], at: point(part.centerX, part.centerY, z: 0.02) - baseHead, parent: head, furry: true)
    }
    func addHorn(_ part: MountainPortraitCreatureAppearanceDescriptor.Part, skin: MountainPortraitFonsterPlatformColor) {
        let (w, h) = extent(part)
        let horn = ModelEntity(mesh: .generateCone(height: h, radius: w * 0.52), materials: [material(skin)])
        horn.position = point(part.centerX, part.centerY) - baseHead
        head.addChild(horn)
    }
    func addAntlers(_ part: MountainPortraitCreatureAppearanceDescriptor.Part, skin: MountainPortraitFonsterPlatformColor) {
        guard let top = part.pixels.map(\.y).min(), let bottom = part.pixels.map(\.y).max(),
              let left = part.pixels.map(\.x).min(), let right = part.pixels.map(\.x).max() else { return }
        let stemTop = point(15.5, Double(top + 2)) - baseHead
        let stemBottom = point(15.5, Double(bottom)) - baseHead
        tube(from: stemBottom, to: stemTop, radius: 0.043, color: skin, parent: head)
        tube(from: stemTop, to: point(Double(left), Double(top), z: -0.02) - baseHead, radius: 0.035, color: skin, parent: head)
        tube(from: stemTop, to: point(Double(right), Double(top), z: -0.02) - baseHead, radius: 0.035, color: skin, parent: head)
    }
    func tube(from: SIMD3<Float>, to: SIMD3<Float>, radius: Float, color: MountainPortraitFonsterPlatformColor, parent: Entity) {
        let delta = to - from
        let length = simd_length(delta)
        guard length > 0.001 else { return }
        let sphere = ball(color, scale: [radius, length / 2 + radius, radius], at: (from + to) / 2, parent: parent, furry: true)
        sphere.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
    }
    func addLimb(_ part: MountainPortraitCreatureAppearanceDescriptor.Part, skin: MountainPortraitFonsterPlatformColor) {
        let h = descriptor.head
        let sorted = part.pixels.sorted {
            hypot(Double($0.x) - h.centerX, Double($0.y) - h.centerY) < hypot(Double($1.x) - h.centerX, Double($1.y) - h.centerY)
        }
        guard let first = sorted.first, let last = sorted.last else { return }
        // Visible raster strokes can start beyond the smoothed contour. Place their
        // joints inside the nearest resolved head cell, while retaining the clipped tip.
        // This makes the appendages physically connected from every viewing angle.
        let attachment = h.footprint.min {
            hypot(Double($0.x - first.x), Double($0.y - first.y)) < hypot(Double($1.x - first.x), Double($1.y - first.y))
        } ?? first
        let surfaceAnchor = point(Double(attachment.x), Double(attachment.y))
        let start = baseHead + (surfaceAnchor - baseHead) * 0.92
        let end = point(Double(last.x), Double(last.y), z: 0.05)
        let length = simd_distance(start, end)
        guard length > 0.045 else { return }
        let joint = Entity(); joint.name = part.id; joint.position = start
        let angle = atan2(end.y - start.y, end.x - start.x) - Float.pi / 2
        joint.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
        let radius = min(0.12, max(0.045, Float(part.pixels.count) * pixel * pixel / max(length, 0.01) * 0.38))
        tube(from: .zero, to: [0, length * 0.52, 0.05], radius: radius, color: skin, parent: joint)
        let bend = Entity(); bend.position = [0, length * 0.52, 0.05]
        tube(from: .zero, to: [0, length * 0.48, 0.03], radius: radius * 0.8, color: skin, parent: bend)
        _ = ball(skin, scale: [radius * 1.22, radius, radius * 1.3], at: [0, length * 0.48, 0.03], parent: bend, furry: true)
        joint.addChild(bend); root.addChild(joint); limbs.append((joint, bend, angle))
    }
}
#endif


// MARK: - Adapted from Fonsters/Playroom/MountainPortraitCreatureFur.swift
#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit
import CryptoKit
import simd

/// Original curved fibre geometry, batched per skin surface. No assets, textures or
/// per-fibre entities/animation. The resolved appearance supplies every coat colour.
@available(macOS 15.0, iOS 18.0, visionOS 2.0, tvOS 26.0, *)
@MainActor
enum MountainPortraitCreatureFur {
    static let styleVersion = 3
    static let segments = 3
    static let sides = 4
    struct Surface {
        let mesh: MeshResource
        let strands: Int
        let triangles: Int
        let trimmedStrands: Int
        let estimatedBytes: Int
    }
    private static var cache: [String: Surface] = [:]
    private static var recent: [String] = []
    private static var cachedBytes = 0
    static func releaseCachedSurfaces() {
        cache.removeAll(); recent.removeAll(); cachedBytes = 0
    }
    /// Only immutable mesh resources are reused; each rig gets new animated entities.
    static func surface(key: String, name: String, make: () -> Geometry) throws -> Surface {
        if let saved = cache[key] {
            recent.removeAll { $0 == key }; recent.append(key)
            return saved
        }
        let geometry = make()
        let surface = Surface(mesh: try geometry.resource(name: name), strands: geometry.strands,
                              triangles: geometry.triangles, trimmedStrands: geometry.trimmedStrands,
                              estimatedBytes: (geometry.positions.count + geometry.normals.count) * 12 +
                                (geometry.indices.count + geometry.materials.count) * 4)
        cache[key] = surface; recent.append(key)
        cachedBytes += surface.estimatedBytes
        while recent.count > 80 || cachedBytes > 64 * 1024 * 1024 {
            if let old = cache.removeValue(forKey: recent.removeFirst()) { cachedBytes -= old.estimatedBytes }
        }
        return surface
    }
    struct Geometry {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var materials: [UInt32] = []
        var strands = 0
        var trimmedStrands = 0
        var maximumLength: Float = 0
        var triangles: Int { indices.count / 3 }
        @MainActor func resource(name: String) throws -> MeshResource {
            var mesh = MeshDescriptor(name: name)
            mesh.positions = MeshBuffers.Positions(positions)
            mesh.normals = MeshBuffers.Normals(normals)
            mesh.primitives = .triangles(indices)
            mesh.materials = .perFace(materials)
            return try MeshResource.generate(from: [mesh])
        }
    }
    private struct Noise {
        var state: UInt64
        mutating func unit() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 40) & 0xffffff) / Float(0xffffff)
        }
    }
    static func seed(for descriptor: MountainPortraitCreatureAppearanceDescriptor) -> UInt64 {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: (try? encoder.encode(descriptor)) ?? Data())
        return digest.prefix(8).reduce(UInt64(styleVersion)) { ($0 << 8) ^ UInt64($1) }
    }
    static func appearanceKey(_ descriptor: MountainPortraitCreatureAppearanceDescriptor) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: (try? encoder.encode(descriptor)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
    static func materials(for descriptor: MountainPortraitCreatureAppearanceDescriptor) -> [PhysicallyBasedMaterial] {
        descriptor.rgbaPalette.flatMap { rgba in
            [0.95, 1.0, 1.06].map { tone in
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: MountainPortraitFonsterPlatformColor(srgbRed: min(1, CGFloat(rgba[0]) / 255 * tone),
                    green: min(1, CGFloat(rgba[1]) / 255 * tone), blue: min(1, CGFloat(rgba[2]) / 255 * tone), alpha: 1))
                material.roughness = .init(floatLiteral: 1)
                material.specular = .init(floatLiteral: 0.06)
                material.metallic = .init(floatLiteral: 0)
                material.clearcoat = .init(floatLiteral: 0)
                return material
            }
        }
    }
    static func head(_ descriptor: MountainPortraitCreatureAppearanceDescriptor, radii: [Float], pixel: Float, depth: Float,
                     skinIndex: Int, count: Int = 12_000, toneVariation: Bool = true) -> Geometry {
        let h = descriptor.head, around = radii.count - 1
        let seed = seed(for: descriptor)
        var noise = Noise(state: seed)
        var geometry = Geometry()
        reserve(&geometry, count: count)
        var paint = Array(repeating: skinIndex, count: 1024)
        for part in descriptor.parts where ["beard", "hair", "marking"].contains(part.kind) {
            for (i, p) in part.pixels.enumerated() { paint[p.y * 32 + p.x] = Int(part.paletteIndices[i]) }
        }
        var features = descriptor.parts.filter { ["eye", "brow", "nose"].contains($0.kind) }.map { part in
            let w = Float((part.pixels.map(\.x).max() ?? 0) - (part.pixels.map(\.x).min() ?? 0) + 1) * pixel
            let height = Float((part.pixels.map(\.y).max() ?? 0) - (part.pixels.map(\.y).min() ?? 0) + 1) * pixel
            return (x: Float(part.centerX - h.centerX) * pixel, y: Float(h.centerY - part.centerY) * pixel,
                    rx: w * 0.80 + 0.025, ry: height * 0.80 + 0.025)
        }
        let smile = MountainPortraitCreatureRig.smileLayout(for: descriptor)
        features.append((x: Float(smile.centerX - h.centerX) * pixel, y: Float(h.centerY - smile.centerY) * pixel,
                         rx: smile.width * 0.70 + 0.025, ry: smile.height * 0.78 + 0.025))
        for i in 0..<count {
            let z = 1 - 2 * (Float(i) + 0.5) / Float(count)
            let angle = (Float(i) * 2.39996323 + noise.unit() * 0.24).truncatingRemainder(dividingBy: 2 * .pi)
            let index = angle / (2 * .pi) * Float(around), lower = Int(index)
            let r = (radii[lower] + (radii[lower + 1] - radii[lower]) * (index - Float(lower))) * pixel
            let ring = sqrt(max(0, 1 - z * z))
            let root = SIMD3<Float>(r * cos(angle) * ring, r * sin(angle) * ring, depth * z)
            let normal = simd_normalize(SIMD3<Float>(root.x / (r * r), root.y / (r * r), root.z / (depth * depth)))
            let nearFeature = z > 0 && features.contains { f in
                let x = (root.x - f.x) / f.rx, y = (root.y - f.y) / f.ry
                return x * x + y * y < 1
            }
            let length: Float = nearFeature ? 0.007 + noise.unit() * 0.005 : 0.028 + pow(noise.unit(), 1.4) * 0.049
            let width: Float = nearFeature ? 0.0011 : 0.0025 + noise.unit() * 0.0016
            let px = min(31, max(0, Int((root.x / pixel + Float(h.centerX)).rounded())))
            let py = min(31, max(0, Int((Float(h.centerY) - root.y / pixel).rounded())))
            let color = z > 0 ? paint[py * 32 + px] : skinIndex
            append(&geometry, root: root - normal * 0.002, normal: normal, length: length, width: width,
                   palette: color, scale: .one, toneVariation: toneVariation, noise: &noise)
            if nearFeature { geometry.trimmedStrands += 1 }
        }
        return geometry
    }
    /// The mesh lives under the original ellipsoid model. Inverse scale gives
    /// each fibre a consistent world-space length even on narrow arms and feet.
    static func ellipsoid(axes: SIMD3<Float>, palette: Int, seed: UInt64, density: Float = 1,
                          toneVariation: Bool = true) -> Geometry {
        let area = 4 * Float.pi * pow((pow(axes.x * axes.y, 1.6075) + pow(axes.y * axes.z, 1.6075) + pow(axes.x * axes.z, 1.6075)) / 3, 1 / 1.6075)
        let count = min(Int(4200 * density), max(80, Int(area * 2200 * density)))
        var geometry = Geometry(), noise = Noise(state: seed)
        reserve(&geometry, count: count)
        let length = min(0.049, max(0.018, min(axes.x, axes.z) * 0.16))
        for i in 0..<count {
            let z = 1 - 2 * (Float(i) + 0.5) / Float(count)
            let angle = Float(i) * 2.39996323 + noise.unit() * 0.18, ring = sqrt(max(0, 1 - z * z))
            let point = SIMD3<Float>(cos(angle) * ring, sin(angle) * ring, z)
            let root = point * axes, normal = simd_normalize(point / axes)
            append(&geometry, root: root - normal * 0.001, normal: normal,
                   length: length * (0.7 + noise.unit() * 0.8), width: 0.0020 + noise.unit() * 0.0010,
                   palette: palette, scale: axes, toneVariation: toneVariation, noise: &noise)
        }
        return geometry
    }
    private static func reserve(_ geometry: inout Geometry, count: Int) {
        geometry.positions.reserveCapacity(count * (segments + 1) * sides)
        geometry.normals.reserveCapacity(count * (segments + 1) * sides)
        geometry.indices.reserveCapacity(count * segments * sides * 6)
        geometry.materials.reserveCapacity(count * segments * sides * 2)
    }
    static func volume(_ surface: MountainPortraitResolvedCreatureVolume, seed: UInt64, count: Int, toneVariation: Bool) -> Geometry {
        var geometry = Geometry(), noise = Noise(state: seed), cumulative: [Float] = [], area: Float = 0
        for i in stride(from: 0, to: surface.indices.count, by: 3) {
            let a = surface.positions[Int(surface.indices[i])], b = surface.positions[Int(surface.indices[i+1])], c = surface.positions[Int(surface.indices[i+2])]
            area += simd_length(simd_cross(b-a, c-a)) * 0.5; cumulative.append(area)
        }
        guard area > 0 else { return geometry }
        reserve(&geometry, count: count)
        for _ in 0..<count {
            let target = noise.unit() * area
            var lower = 0, upper = cumulative.count - 1
            while lower < upper { let mid = (lower + upper) / 2; if cumulative[mid] < target { lower = mid + 1 } else { upper = mid } }
            let indices = (0..<3).map { Int(surface.indices[lower * 3 + $0]) }
            let a = sqrt(noise.unit()), b = noise.unit(), weights: [Float] = [1-a, a*(1-b), a*b]
            var root = SIMD3<Float>.zero, normal = SIMD3<Float>.zero
            for i in 0..<3 { root += surface.positions[indices[i]] * weights[i]; normal += surface.normals[indices[i]] * weights[i] }
            normal = simd_normalize(normal)
            let length: Float = 0.025 + noise.unit() * 0.035
            append(&geometry, root: root - normal * 0.002, normal: normal, length: length,
                   width: 0.0022, palette: Int(surface.materials[lower]), scale: .init(repeating: 1), toneVariation: toneVariation, noise: &noise)
        }
        return geometry
    }
    private static func append(_ geometry: inout Geometry, root: SIMD3<Float>, normal: SIMD3<Float>,
                               length: Float, width: Float, palette: Int, scale: SIMD3<Float>,
                               toneVariation: Bool, noise: inout Noise) {
        let reference: SIMD3<Float> = abs(normal.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
        let u = simd_normalize(simd_cross(normal, reference)), v = simd_cross(normal, u)
        let swirl = noise.unit() * 2 * .pi
        let randomTangent = u * cos(swirl) + v * sin(swirl)
        let comb = SIMD3<Float>(0, -1, 0) - normal * simd_dot(SIMD3<Float>(0, -1, 0), normal)
        let tangent = randomTangent * 0.55 + comb * 0.65
        let start = UInt32(geometry.positions.count)
        let brightness = noise.unit()
        for band in 0...segments {
            let t = Float(band) / Float(segments)
            let center = root + normal * length * t + tangent * length * (0.18 * t + 1.12 * t * t)
            let direction = simd_normalize(normal + tangent * (0.18 + 2.24 * t))
            let a = simd_normalize(simd_cross(direction, reference)), b = simd_cross(direction, a)
            let radius = width * (1 - t * 0.86)
            for side in 0..<sides {
                let radial: SIMD3<Float>
                switch side { case 0: radial = a; case 1: radial = b; case 2: radial = -a; default: radial = -b }
                geometry.positions.append((center + radial * radius) / scale)
                // A rounded wool tuft shares its surface normal with its neighbors.
                // Softer shading avoids a forest of black needle highlights.
                geometry.normals.append(simd_normalize((radial * 0.32 + normal * 0.68) * scale))
            }
        }
        for band in 0..<segments {
            let tone = toneVariation ? (band == 0 ? 0 : (band == segments - 1 && brightness > 0.28 ? 2 : 1)) : 1
            let material = UInt32(min(5, max(0, palette)) * 3 + tone)
            for side in 0..<sides {
                let a = start + UInt32(band * sides + side), b = start + UInt32(band * sides + (side + 1) % sides)
                let c = a + UInt32(sides), d = b + UInt32(sides)
                geometry.indices.append(a); geometry.indices.append(b); geometry.indices.append(c)
                geometry.indices.append(b); geometry.indices.append(d); geometry.indices.append(c)
                geometry.materials.append(material); geometry.materials.append(material)
            }
        }
        geometry.strands += 1; geometry.maximumLength = max(geometry.maximumLength, length)
    }
}
#endif


// MARK: - Adapted from Fonsters/Playroom/MountainPortraitCreatureFacialGeometry.swift
#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import RealityKit
import Metal
import simd

/// Two fixed-topology volumetric meshes. Only existing vertex buffers change;
/// no per-frame mesh/entity/material creation and no additional shader toolchain.
@available(macOS 15.0, iOS 18.0, visionOS 2.0, tvOS 26.0, *)
@MainActor final class MountainPortraitCreatureFacialGeometry {
    struct Vertex { var position: SIMD3<Float>; var normal: SIMD3<Float> }
    let cavity: ModelEntity
    let rim: ModelEntity
    // Retain native buffers: MeshResource.contents omits LowLevelMesh vertices.
    let cavityMesh: LowLevelMesh
    let rimMesh: LowLevelMesh
    let width: Float, height: Float
    private let steps = 32, sides = 8
    private var lastSmile: Float = -10, lastOpening: Float = -10
    private(set) var curvature: Float = 0.45

    init(width: Float, height: Float, cavityMaterial: PhysicallyBasedMaterial, rimMaterial: PhysicallyBasedMaterial) throws {
        self.width = width; self.height = height
        let count = 66, stations = 33
        var cavityIndices: [UInt32] = []
        for i in 0..<32 {
            let a = UInt32(i * 2), b = a + 2, back = UInt32(stations * 2)
            cavityIndices += [a, a + 1, b, a + 1, b + 1, b,
                              a + back, b + back, a + 1 + back, a + 1 + back, b + back, b + 1 + back]
        }
        let sideStart = UInt32(stations * 4)
        for i in 0..<count {
            let a = sideStart + UInt32(i * 4)
            cavityIndices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        var rimIndices: [UInt32] = []
        for i in 0..<count { for j in 0..<8 {
            let a = UInt32(i * 8 + j), b = UInt32(i * 8 + (j + 1) % 8)
            let c = UInt32((i + 1) % count * 8 + j), d = UInt32((i + 1) % count * 8 + (j + 1) % 8)
            rimIndices += [a, b, c, b, d, c]
        } }
        let bounds = BoundingBox(min: [-width * 0.6, -height * 1.2, -0.015], max: [width * 0.6, height * 1.2, 0.1])
        func make(_ vertices: Int, _ indices: [UInt32]) throws -> LowLevelMesh {
            var descriptor = LowLevelMesh.Descriptor()
            descriptor.vertexCapacity = vertices; descriptor.indexCapacity = indices.count; descriptor.indexType = .uint32
            descriptor.vertexAttributes = [
                .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
                .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal)!)]
            descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
            let mesh = try LowLevelMesh(descriptor: descriptor)
            mesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
                let target = bytes.bindMemory(to: Vertex.self)
                for i in 0..<vertices { target[i] = .init(position: .zero, normal: [0, 0, 1]) }
            }
            mesh.withUnsafeMutableIndices { bytes in
                let target = bytes.bindMemory(to: UInt32.self)
                for i in indices.indices { target[i] = indices[i] }
            }
            mesh.parts.replaceAll([.init(indexCount: indices.count, topology: .triangle, bounds: bounds)])
            return mesh
        }
        cavityMesh = try make(stations * 4 + count * 4, cavityIndices)
        rimMesh = try make(count * 8, rimIndices)
        cavity = ModelEntity(mesh: try MeshResource(from: cavityMesh), materials: [cavityMaterial]); cavity.name = "smile-cavity"
        rim = ModelEntity(mesh: try MeshResource(from: rimMesh), materials: [rimMaterial]); rim.name = "smile-rim"
        update(smile: 0.45, opening: 1)
    }
    func update(smile: Float, opening: Float) {
        guard smile.isFinite, opening.isFinite else { return }
        let smile = min(1, max(-0.85, smile)), opening = min(1.4, max(0.3, opening))
        guard abs(smile - lastSmile) > 0.002 || abs(opening - lastOpening) > 0.003 else { return }
        lastSmile = smile; lastOpening = opening; curvature = smile
        let edges = (0...steps).map { MountainPortraitCreatureMouthCurve.edges(t: Float($0) / Float(steps) * 2 - 1, width: width, height: height, smile: smile, opening: opening) }
        let outline = edges.map { $0.0 } + edges.reversed().map { $0.1 }
        cavityMesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
            let vertices = bytes.bindMemory(to: Vertex.self)
            for i in edges.indices {
                let (top, bottom) = edges[i]
                vertices[i * 2] = .init(position: [top.x, top.y, 0.052], normal: [0, 0, 1])
                vertices[i * 2 + 1] = .init(position: [bottom.x, bottom.y, 0.052], normal: [0, 0, 1])
                let back = edges.count * 2 + i * 2
                vertices[back] = .init(position: [top.x, top.y, 0.016], normal: [0, 0, -1])
                vertices[back + 1] = .init(position: [bottom.x, bottom.y, 0.016], normal: [0, 0, -1])
            }
            for i in outline.indices {
                let a = outline[i], b = outline[(i + 1) % outline.count], delta = b - a
                let normal = simd_normalize(SIMD3<Float>(-delta.y, delta.x, 0))
                let start = edges.count * 4 + i * 4
                for (j, point) in [SIMD3<Float>(a.x, a.y, 0.052), [b.x, b.y, 0.052], [a.x, a.y, 0.016], [b.x, b.y, 0.016]].enumerated() {
                    vertices[start + j] = .init(position: point, normal: normal)
                }
            }
        }
        rimMesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
            let vertices = bytes.bindMemory(to: Vertex.self)
            let radius = min(0.023, width * 0.032)
            for i in outline.indices {
                let tangent = simd_normalize(outline[(i + 1) % outline.count] - outline[(i + outline.count - 1) % outline.count])
                let outward = SIMD3<Float>(-tangent.y, tangent.x, 0)
                for side in 0..<sides {
                    let angle = Float(side) / Float(sides) * 2 * .pi
                    let normal = outward * cos(angle) + SIMD3<Float>(0, 0, sin(angle))
                    let point = outline[i]
                    vertices[i * sides + side] = .init(position: SIMD3<Float>(point.x, point.y, 0.057) + normal * radius, normal: normal)
                }
            }
        }
    }
}
#endif


// MARK: - Adapted from Fonsters/Playroom/CreatureFaceDynamics.swift
enum MountainPortraitCreatureMouthCurve {
    static func edges(t: Float, width: Float, height: Float, smile: Float, opening: Float) -> (SIMD2<Float>, SIMD2<Float>) {
        let smile = min(1, max(-0.85, smile)), opening = min(1.4, max(0.3, opening))
        let center = smile * height * (-0.02 + 0.32 * t * t)
        let gap = height * (0.024 + 0.5 * max(0, smile) * opening) * (1 - 0.97 * t * t)
        return ([t * width / 2, center + gap * 0.05], [t * width / 2, center - gap * 0.95])
    }
}


// MARK: - Adapted from Fonsters/Playroom/MountainPortraitCreatureSceneLighting.swift
#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit

/// An original soft studio environment shared by the native view and scene exports.
@available(macOS 15.0, iOS 18.0, visionOS 2.0, tvOS 26.0, *)
@MainActor
enum MountainPortraitCreatureSceneLighting {
    static let name = "fonsters-soft-studio"
    private static var cached: EnvironmentResource?

    static func environment() async throws -> EnvironmentResource {
        if let cached { return cached }
        let width = 256, height = 128
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let vertical = Float(y) / Float(height - 1)
            for x in 0..<width {
                let horizontal = Float(x) / Float(width - 1)
                let softbox = exp(-pow((horizontal - 0.35) / 0.20, 2) - pow((vertical - 0.30) / 0.28, 2))
                let light = 0.53 + (1 - vertical) * 0.25 + softbox * 0.20
                let i = (y * width + x) * 4
                bytes[i] = UInt8(min(255, light * 255))
                bytes[i + 1] = UInt8(min(255, light * 0.97 * 255))
                bytes[i + 2] = UInt8(min(255, light * 0.94 * 255))
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw CocoaError(.featureUnsupported) }
        let resource = try await EnvironmentResource(equirectangular: image, withName: name)
        cached = resource
        return resource
    }

    static func studio(for entities: [Entity]) async throws -> Entity {
        let light = Entity(); light.name = name
        light.components.set(ImageBasedLightComponent(source: .single(try await environment()), intensityExponent: 1.0))
        bind(entities, to: light)
        return light
    }

    /// Cloning a scene requires reconnecting the receiver to that scene's own light.
    static func bind(_ entities: [Entity], to light: Entity) {
        func visit(_ entity: Entity) {
            if entity.components[ModelComponent.self] != nil {
                entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
            }
            for child in entity.children { visit(child) }
        }
        for entity in entities { visit(entity) }
    }
}
#endif

