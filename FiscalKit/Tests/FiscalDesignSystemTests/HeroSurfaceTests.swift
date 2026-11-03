import Foundation
import SwiftUI
import Testing

@testable import FiscalDesignSystem

@MainActor
struct HeroSurfaceTests {
    private static let table = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "scripts/party-palette.json")

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init?(hex: String) {
            guard let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        }

        func over(_ base: RGB, opacity: Double) -> RGB {
            RGB(
                red: red * opacity + base.red * (1 - opacity),
                green: green * opacity + base.green * (1 - opacity),
                blue: blue * opacity + base.blue * (1 - opacity))
        }

        var luminance: Double {
            func linear(_ value: Double) -> Double {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        func contrast(with other: RGB) -> Double {
            let lighter = max(luminance, other.luminance)
            let darker = min(luminance, other.luminance)
            return (lighter + 0.05) / (darker + 0.05)
        }
    }

    private static let row = RGB(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    private static let label = RGB(red: 0, green: 0, blue: 0)

    @Test func everyPartyColorKeepsTheTextReadableInLightMode() throws {
        let data = try Data(contentsOf: Self.table)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let parties = try #require(root["parties"] as? [String: [String: String]])
        #expect(parties.count >= 20)
        for (party, colors) in parties {
            for hex in colors.values {
                let tint = try #require(RGB(hex: hex))
                let surface = tint.over(Self.row, opacity: .opacitySoft)
                let secondary = Self.label.over(surface, opacity: .opacityStrong)
                #expect(surface.contrast(with: Self.label) >= 4.5, "\(party) \(hex)")
                #expect(surface.contrast(with: secondary) >= 3, "\(party) \(hex)")
            }
        }
    }

    @Test func eachToneBringsItsColors() {
        #expect(HeroTone.vote.tints.count == 2)
        #expect(HeroTone.party("PT").tints.count == 2)
        #expect(HeroTone.parties("PT", "PL").tints.count == 2)
        #expect(HeroTone.colors([.red]).tints == [.red])
    }

    @Test func theInkOnlyChangesInLightMode() {
        let dark = HeroInk(.dark)
        let light = HeroInk(.light)
        #expect(dark.primary == .white)
        #expect(dark.signal(.voteYes) == .white)
        #expect(light.primary == .primary)
        #expect(light.signal(.voteYes) == .voteYes)
    }
}
