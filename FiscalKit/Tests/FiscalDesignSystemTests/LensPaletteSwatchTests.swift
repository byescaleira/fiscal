import Foundation
import Testing

@testable import FiscalDesignSystem

struct LensPaletteSwatchTests {
    @Test func everyPaletteHasAMirrorOnTheOtherSide() {
        for swatch in LensPaletteSwatch.allCases {
            #expect(swatch.mirror != swatch)
            #expect(swatch.mirror.mirror == swatch)
        }
        let paired = LensPaletteSwatch.leading + LensPaletteSwatch.leading.map(\.mirror)
        #expect(paired.count == LensPaletteSwatch.allCases.count)
        #expect(Set(paired) == Set(LensPaletteSwatch.allCases))
    }

    @Test func greenAndYellowNeverStandAlone() {
        #expect(LensPaletteSwatch.forest.mirror == .annatto)
        #expect(LensPaletteSwatch.leading.contains(.forest))
    }

    @Test(arguments: LensPaletteSwatch.allCases)
    func accentReadsOnTheBackground(swatch: LensPaletteSwatch) {
        #expect(Self.contrast(swatch.hexes.light, 0xFFFFFF) >= 4.5)
        #expect(Self.contrast(swatch.hexes.dark, 0x000000) >= 4.5)
    }

    @Test func namesMatchStoredIdentifiers() {
        #expect(LensPaletteSwatch.named("forest") == .forest)
        #expect(LensPaletteSwatch.named("neutral") == nil)
        #expect(LensPaletteSwatch.named(nil) == nil)
    }

    private static func contrast(_ lhs: UInt32, _ rhs: UInt32) -> Double {
        let values = [luminance(lhs), luminance(rhs)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        let channels = [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255].map { channel in
            let value = Double(channel) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
