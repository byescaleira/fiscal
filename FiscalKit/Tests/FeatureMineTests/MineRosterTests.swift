import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMine

@MainActor
struct MineRosterTests {
    @Test func theRosterCountsWhoIsShownAndNamesTheParty() {
        let people = ["Ana", "Bia", "Caio"].enumerated().map { index, name in
            PersonCard(
                slug: name.lowercased(), name: name, office: .federalDeputy, uf: "ba",
                party: index == 0 ? "PT" : "PSD", photo: nil, status: .inOffice)
        }
        let roster = MineRoster(title: "Bahia", people: people)
        #expect(roster.header(shown: 3) == String(appLocalized: "\(3) people"))
        #expect(roster.header(shown: 1) == String(appLocalized: "\(1) of \(3) people"))
        #expect(roster.scopeTitle(party: nil) == String(appLocalized: "All Parties"))
        #expect(roster.scopeTitle(party: "PT") == "PT")
        #expect(roster.filtered(query: "", party: "PSD").map(\.name) == ["Bia", "Caio"])
    }

    @Test func choosingAPlaceCanStartWithTheSearch() throws {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let model = MineModel(
            service: ShowcasePublicData(scenario: .normal, now: .now), follows: nil,
            memory: MinePlaceMemory(defaults: defaults))
        model.choosePlace(searching: true)
        #expect(model.isChoosingPlace)
        #expect(model.startsSearching)
        model.choosePlace(searching: false)
        #expect(!model.startsSearching)
    }
}
