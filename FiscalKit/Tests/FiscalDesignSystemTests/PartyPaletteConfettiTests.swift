import SwiftUI
import Testing

@testable import FiscalDesignSystem

struct PartyPaletteConfettiTests {
    private func resolved(_ palette: PartyPalette) -> [Color.Resolved] {
        [palette.primary, palette.secondary].map { $0.resolve(in: EnvironmentValues()) }
    }

    private func resolved(_ colors: [Color]) -> [Color.Resolved] {
        colors.map { $0.resolve(in: EnvironmentValues()) }
    }

    @Test func aPartyUsesItsOwnColors() {
        #expect(
            resolved(PartyPalette.liking(party: "PSB")) == resolved(PartyPalette.of(party: "PSB")))
        #expect(resolved(PartyPalette.liking(party: "PSB")) != resolved(PartyPalette.hearts))
    }

    @Test(arguments: [nil, ""] as [String?])
    func withoutAPartyTheHeartsAreRed(party: String?) {
        #expect(resolved(PartyPalette.liking(party: party)) == resolved(PartyPalette.hearts))
    }

    @Test func theConfettiHasFourTonesFromTheParty() {
        let palette = PartyPalette.of(party: "PT")
        let plain = resolved(palette.confetti(lightened: 0))
        #expect(plain.count == 4)
        let base = resolved(palette)
        #expect(
            zip(plain.prefix(2), base).allSatisfy {
                abs($0.red - $1.red) < 0.01 && abs($0.green - $1.green) < 0.01
                    && abs($0.blue - $1.blue) < 0.01
            })
        let lighter = resolved(palette.confetti(lightened: .opacitySoft))
        #expect(zip(lighter, plain).allSatisfy { $0.green >= $1.green && $0.blue >= $1.blue })
        #expect(lighter != plain)
    }
}
