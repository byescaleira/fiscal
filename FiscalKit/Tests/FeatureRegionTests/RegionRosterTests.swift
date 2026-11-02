import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureRegion

@MainActor
struct RegionRosterTests {
    @Test func theRosterCountsWhoIsShownAndNamesTheParty() {
        let people = ["Ana", "Bia", "Caio"].enumerated().map { index, name in
            PersonCard(
                slug: name.lowercased(), name: name, office: .federalDeputy, uf: "ba",
                party: index == 0 ? "PT" : "PSD", photo: nil, status: .inOffice)
        }
        let roster = RegionRoster(title: "Bahia", people: people)
        #expect(roster.header(shown: 3) == String(appLocalized: "\(3) people"))
        #expect(roster.header(shown: 1) == String(appLocalized: "\(1) of \(3) people"))
        #expect(roster.scopeTitle(party: nil) == String(appLocalized: "All Parties"))
        #expect(roster.scopeTitle(party: "PT") == "PT")
        #expect(roster.filtered(query: "", party: "PSD").map(\.name) == ["Bia", "Caio"])
    }

    @Test func theTableSortsByEachColumnWithTheNameAsTieBreak() {
        let people = [
            PersonCard(
                slug: "caio", name: "Caio", office: .senator, uf: "ba", party: "PT", photo: nil,
                status: .inOffice),
            PersonCard(
                slug: "alvaro", name: "Álvaro", office: .federalDeputy, uf: "ba", party: "PSD",
                photo: nil, status: .inOffice),
            PersonCard(
                slug: "bia", name: "Bia", office: .federalDeputy, uf: "ba", party: "PT",
                photo: nil, status: .inOffice),
        ]
        let roster = RegionRoster(title: "Bahia", people: people)
        #expect(
            roster.sorted(query: "", party: nil, by: RegionRoster.order).map(\.slug)
                == ["alvaro", "bia", "caio"])
        let byParty = [KeyPathComparator(\PersonCard.party, order: .reverse)]
        #expect(
            roster.sorted(query: "", party: nil, by: byParty).map(\.slug)
                == ["bia", "caio", "alvaro"])
        let byRole = [KeyPathComparator(\PersonCard.officeTitle, comparator: .localizedStandard)]
        let roles = roster.sorted(query: "", party: nil, by: byRole).map(\.officeTitle)
        #expect(
            zip(roles, roles.dropFirst()).allSatisfy {
                $0.localizedStandardCompare($1) != .orderedDescending
            })
        #expect(
            roster.sorted(query: "", party: "PT", by: RegionRoster.order).map(\.slug)
                == ["bia", "caio"])
        #expect(roster.sorted(query: "alv", party: nil, by: byParty).map(\.slug) == ["alvaro"])
    }

    @Test func theStateShowsInCapitalsAndTheCountryAsADash() {
        let roster = RegionRoster(title: "Brasil", people: [])
        let local = PersonCard(
            slug: "ana", name: "Ana", office: .federalDeputy, uf: "ba", party: "PT", photo: nil,
            status: .inOffice)
        let national = PersonCard(
            slug: "bia", name: "Bia", office: .federalDeputy, uf: "br", party: "PT", photo: nil,
            status: .inOffice)
        #expect(roster.stateText(local) == "BA")
        #expect(roster.stateText(national) == PublicFormat.missing)
    }

    @Test func aDoubleClickOpensOnlyOneKnownProfile() {
        let people = ["Ana", "Bia"].map { name in
            PersonCard(
                slug: name.lowercased(), name: name, office: .federalDeputy, uf: "ba",
                party: "PT", photo: nil, status: .inOffice)
        }
        let roster = RegionRoster(title: "Bahia", people: people)
        #expect(roster.profileRoute(for: ["ana"]) == .person(slug: "ana"))
        #expect(roster.profileRoute(for: ["ana", "bia"]) == nil)
        #expect(roster.profileRoute(for: ["caio"]) == nil)
        #expect(roster.profileRoute(for: []) == nil)
        #expect(roster.card(for: ["ana"])?.slug == "ana")
        #expect(roster.card(for: ["ana", "bia"]) == nil)
    }

    @Test func choosingAPlaceCanStartWithTheSearch() throws {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let model = RegionModel(
            service: ShowcasePublicData(scenario: .normal, now: .now), follows: nil,
            memory: RegionPlaceMemory(defaults: defaults))
        model.choosePlace(searching: true)
        #expect(model.isChoosingPlace)
        #expect(model.startsSearching)
        model.choosePlace(searching: false)
        #expect(!model.startsSearching)
    }
}
