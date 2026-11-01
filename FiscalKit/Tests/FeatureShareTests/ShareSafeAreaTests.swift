import CoreGraphics
import FeatureCore
import FiscalData
import FiscalDesignSystem
import Foundation
import SwiftUI
import Testing

@testable import FeatureShare

@MainActor
struct ShareSafeAreaTests {
    @Test func ninebysixteenKeepsTheSafeZone() {
        let format = FeatureShare.ShareFormat.stories
        #expect(format.size.height / format.size.width == CGFloat(640) / 360)
        #expect(format.safeRect == CGRect(x: 22, y: 90, width: 316, height: 326))
        let insets = format.textInsets
        #expect(insets.top >= .shareSafeTop)
        #expect(insets.bottom >= .shareSafeBottom)
        #expect(insets.leading >= .shareSafeSide)
        #expect(insets.trailing >= .shareSafeSide)
        let margin = format.textFormat.margin
        let extra = format.safeExtra(beyond: margin)
        #expect(margin + extra.top == .shareSafeTop)
        #expect(margin + extra.bottom == .shareSafeBottom)
        #expect(margin + extra.leading >= .shareSafeSide)
        #expect(format.textFormat.contentWidth <= format.safeRect.width)
        #expect(FeatureShare.ShareFormat.feed.safeInsets == EdgeInsets())
        #expect(FeatureShare.ShareFormat.message.safeInsets == EdgeInsets())
    }

    @Test func nothingIsDrawnOutsideTheZoneOnSolidStyles() async throws {
        let follows = try await ShareFixtures.follows([
            ShareFixtures.person("ana-souza", "Ana Souza")
        ])
        for subject in try await ShareFixtures.subjects() {
            let model = ShareFixtures.model(subject, follows: follows)
            await model.load()
            model.format = .stories
            for style in [ShareStyle.typographic, .data] {
                model.style = style
                let card = try #require(model.card, "\(subject)")
                let pixels = try #require(Pixels(card: card, code: model.code))
                let zone = card.format.safeRect.insetBy(dx: -1, dy: -1)
                #expect(pixels.offender(outside: zone) == nil, "\(subject) \(style)")
            }
        }
    }

    @Test func longTextStaysInTheZone() async throws {
        let service = ShowcasePublicData(scenario: .longNames, now: ShareFixtures.now)
        let highlight = try #require(try await service.highlights()?.items.first?.id)
        let subjects: [ShareSubject] = [
            .person(slug: "maria-da-conceicao-albuquerque"), .vote(id: "camara-18732026"),
            .expenses(slug: "maria-da-conceicao-albuquerque", year: 2026),
            .highlight(id: highlight),
        ]
        for subject in subjects {
            let model = ShareModel(subject: subject, service: service)
            await model.load()
            #expect(model.phase == .loaded, "\(subject)")
            model.format = .stories
            for style in [ShareStyle.typographic, .data] {
                model.style = style
                let card = try #require(model.card, "\(subject)")
                let pixels = try #require(Pixels(card: card, code: model.code))
                let zone = card.format.safeRect.insetBy(dx: -1, dy: -1)
                #expect(pixels.offender(outside: zone) == nil, "\(subject) \(style)")
            }
        }
    }
}

@MainActor
private struct Pixels {
    let data: [UInt8]
    let width: Int
    let height: Int

    init?(card: ShareCard, code: CGImage?) {
        let size = card.format.size
        let renderer = ImageRenderer(
            content: ShareRenderer.frame(card, code: code, portraits: nil)
                .frame(width: size.width, height: size.height))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }
        let pixelWidth = image.width
        let pixelHeight = image.height
        var bytes = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: pixelWidth, height: pixelHeight,
                    bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            return true
        }
        guard drawn else { return nil }
        width = pixelWidth
        height = pixelHeight
        data = bytes
    }

    func offender(outside zone: CGRect) -> CGPoint? {
        let field = pixel(0, 0)
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                guard !zone.contains(point) else { continue }
                let current = pixel(x, y)
                let close = zip(field, current).allSatisfy { abs(Int($0) - Int($1)) <= 2 }
                if !close { return point }
            }
        }
        return nil
    }

    private func pixel(_ x: Int, _ y: Int) -> [UInt8] {
        let start = (y * width + x) * 4
        return Array(data[start..<(start + 4)])
    }
}
