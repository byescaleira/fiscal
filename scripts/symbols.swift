import AppKit
import CoreText
import Foundation

let side = 40

func mask(_ draw: (CGContext) -> Void) -> [UInt8] {
    let ctx = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
    draw(ctx)
    let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: side * side)
    return (0..<side * side).map { pixels[$0] < 128 ? 1 : 0 }
}

func fitted(_ path: CGPath) -> [UInt8] {
    let box = path.boundingBoxOfPath
    guard box.width > 0, box.height > 0 else { return [] }
    let scale = Double(side - 4) / max(box.width, box.height)
    return mask { ctx in
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.translateBy(
            x: (Double(side) - box.width * scale) / 2 - box.minX * scale,
            y: (Double(side) - box.height * scale) / 2 - box.minY * scale)
        ctx.scaleBy(x: scale, y: scale)
        ctx.addPath(path)
        ctx.fillPath(using: .evenOdd)
    }
}

func systemMask(_ name: String) -> [UInt8]? {
    let configuration = NSImage.SymbolConfiguration(pointSize: 200, weight: .regular)
        .applying(.preferringMonochrome())
    guard
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    else { return nil }
    let big = 400
    let ctx = CGContext(
        data: nil, width: big, height: big, bitsPerComponent: 8, bytesPerRow: big * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    image.draw(
        in: CGRect(
            x: (Double(big) - image.size.width) / 2, y: (Double(big) - image.size.height) / 2,
            width: image.size.width, height: image.size.height))
    let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: big * big * 4)
    func on(_ x: Int, _ y: Int) -> Bool { pixels[(y * big + x) * 4 + 3] > 128 }
    var minX = big, minY = big, maxX = -1, maxY = -1
    for y in 0..<big {
        for x in 0..<big where on(x, y) {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { return nil }
    let width = maxX - minX + 1, height = maxY - minY + 1
    let scale = Double(side - 4) / Double(max(width, height))
    return mask { ctx in
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.translateBy(
            x: (Double(side) - Double(width) * scale) / 2,
            y: (Double(side) - Double(height) * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -Double(minX), y: -Double(big - 1 - maxY))
        for y in minY...maxY {
            for x in minX...maxX where on(x, y) {
                ctx.fill(CGRect(x: x, y: big - 1 - y, width: 1, height: 1))
            }
        }
    }
}

func overlap(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var inter = 0, union = 0
    for k in 0..<a.count {
        if a[k] == 1 && b[k] == 1 { inter += 1 }
        if a[k] == 1 || b[k] == 1 { union += 1 }
    }
    return union == 0 ? 0 : Double(inter) / Double(union)
}

func resolve(_ names: [String], cache: inout [String: String]) {
    let missing = names.filter { cache[$0] == nil }
    guard !missing.isEmpty else { return }
    let font = CTFontCreateWithName("SFPro-Regular" as CFString, 100, nil)
    var glyphs: [(String, [UInt8])] = []
    for glyph in 0..<CTFontGetGlyphCount(font) {
        guard let name = CTFontCopyNameForGlyph(font, CGGlyph(glyph)) as String?,
            name.hasPrefix("uni1"), let path = CTFontCreatePathForGlyph(font, CGGlyph(glyph), nil)
        else { continue }
        let bitmap = fitted(path)
        if !bitmap.isEmpty { glyphs.append((name, bitmap)) }
    }
    for name in missing {
        guard let target = systemMask(name) else {
            FileHandle.standardError.write("unknown symbol \(name)\n".data(using: .utf8)!)
            continue
        }
        var best = ("", 0.0)
        for (glyph, bitmap) in glyphs {
            let score = overlap(target, bitmap)
            if score > best.1 { best = (glyph, score) }
        }
        FileHandle.standardError.write(
            "\(name) -> \(best.0) (\(String(format: "%.2f", best.1)))\n".data(using: .utf8)!)
        cache[name] = best.0
    }
}

func lottiePaths(_ path: CGPath) -> [[String: Any]] {
    let box = path.boundingBoxOfPath
    let cx = box.midX, cy = box.midY
    func point(_ p: CGPoint) -> [Double] { [p.x - cx, cy - p.y] }
    var paths: [[String: Any]] = []
    var vertices: [[Double]] = [], ins: [[Double]] = [], outs: [[Double]] = []
    var current = CGPoint.zero
    func flush(closed: Bool) {
        if !vertices.isEmpty {
            paths.append(["v": vertices, "i": ins, "o": outs, "c": closed])
        }
        vertices = []
        ins = []
        outs = []
    }
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint:
            flush(closed: false)
            current = e.points[0]
            vertices.append(point(current))
            ins.append([0, 0])
            outs.append([0, 0])
        case .addLineToPoint:
            current = e.points[0]
            vertices.append(point(current))
            ins.append([0, 0])
            outs.append([0, 0])
        case .addQuadCurveToPoint:
            let control = e.points[0], end = e.points[1]
            let c1 = CGPoint(
                x: current.x + 2 / 3 * (control.x - current.x),
                y: current.y + 2 / 3 * (control.y - current.y))
            let c2 = CGPoint(
                x: end.x + 2 / 3 * (control.x - end.x), y: end.y + 2 / 3 * (control.y - end.y))
            outs[outs.count - 1] = [c1.x - current.x, -(c1.y - current.y)]
            vertices.append(point(end))
            ins.append([c2.x - end.x, -(c2.y - end.y)])
            outs.append([0, 0])
            current = end
        case .addCurveToPoint:
            let c1 = e.points[0], c2 = e.points[1], end = e.points[2]
            outs[outs.count - 1] = [c1.x - current.x, -(c1.y - current.y)]
            vertices.append(point(end))
            ins.append([c2.x - end.x, -(c2.y - end.y)])
            outs.append([0, 0])
            current = end
        case .closeSubpath:
            if vertices.count > 1, let first = vertices.first, let last = vertices.last,
                abs(first[0] - last[0]) < 0.01, abs(first[1] - last[1]) < 0.01
            {
                ins[0] = ins[ins.count - 1]
                vertices.removeLast()
                ins.removeLast()
                outs.removeLast()
            }
            flush(closed: true)
        @unknown default:
            break
        }
    }
    flush(closed: false)
    return paths
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("usage: symbols <weight> <cache.json> <out.json> <symbol>...")
    exit(1)
}
let weight = arguments[1], cacheURL = URL(fileURLWithPath: arguments[2])
let outURL = URL(fileURLWithPath: arguments[3])
let names = Array(arguments.dropFirst(4))
var cache =
    (try? JSONSerialization.jsonObject(with: Data(contentsOf: cacheURL)) as? [String: String]) ?? [:]
resolve(names, cache: &cache)
try JSONSerialization.data(withJSONObject: cache, options: [.prettyPrinted, .sortedKeys])
    .write(to: cacheURL)
let font = CTFontCreateWithName("SFPro-\(weight)" as CFString, 100, nil)
var output: [String: Any] = [:]
for name in names {
    guard let glyphName = cache[name] else { continue }
    let glyph = CTFontGetGlyphWithName(font, glyphName as CFString)
    guard glyph != 0, let path = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
    let box = path.boundingBoxOfPath
    output[name] = ["w": box.width, "h": box.height, "paths": lottiePaths(path)]
}
try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]).write(to: outURL)
