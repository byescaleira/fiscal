import Foundation
import SwiftUI
import Testing

@testable import FiscalDesignSystem

@MainActor
struct PortraitTests {
    private static let table = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "scripts/party-palette.json")

    @Test func scriptTableMatchesThePartyPalette() throws {
        let data = try Data(contentsOf: Self.table)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let parties = try #require(root["parties"] as? [String: [String: String]])
        #expect(parties.count >= 20)
        for (party, colors) in parties {
            let palette = PartyPalette.of(party: party)
            #expect(Self.hex(palette.primary) == colors["primary"], "\(party)")
            #expect(Self.hex(palette.secondary) == colors["secondary"], "\(party)")
        }
        let fallback = try #require(root["fallback"] as? [[String: String]])
        #expect(
            Self.hex(PartyPalette.of(party: "sem partido").primary) == fallback.first?["primary"])
    }

    @Test func genericPortraitUsesTheInitials() {
        #expect(PersonPortrait(slug: "lula", name: "Lula", party: "PT").initials == "L")
        #expect(
            PersonPortrait(slug: "x", name: "Professora Maria do Carmo", party: "PL").initials
                == "PC")
        #expect(PersonPortrait(slug: "x", name: "Ana de Sá", party: "PT").initials == "A")
    }

    @Test func portraitAsksForTheDrawingByPersonAndParty() {
        let request = PersonPortrait(slug: "lula", name: "Lula", party: "PT").request
        #expect(request == PortraitRequest(slug: "lula", party: "PT", isStill: false))
        let artwork = PortraitArtwork { _ in nil }
        #expect(artwork.view(for: request) == nil)
    }

    @Test func partyMarkPhasesReturnToRest() {
        let phases = PartyMarkPhase.allCases
        #expect(phases.first == .rest)
        #expect(PartyMarkPhase.rest.sheenOpacity == 0)
        #expect(PartyMarkPhase.rest.ringOpacity == 0)
        #expect(PartyMarkPhase.ring.ringOpacity == 0)
        #expect(PartyMarkPhase.wave.sheenOpacity == 1)
    }

    private static func hex(_ color: Color) -> String {
        let resolved = color.resolve(in: EnvironmentValues())
        let channels = [resolved.red, resolved.green, resolved.blue].map {
            String(format: "%02X", Int((Double($0) * 255).rounded()))
        }
        return "#" + channels.joined()
    }
}
