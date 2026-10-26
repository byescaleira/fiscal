import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

struct ShareCardBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }

    private let updated = Date(timeIntervalSince1970: 1_792_917_720)

    private func profile(office: Office, numbers: Profile.Numbers) -> Profile {
        Profile(
            card: PersonCard(
                slug: "ana-souza", name: "Ana Souza", office: office, uf: "sp", party: "PSD",
                photo: nil, status: .inOffice),
            civilName: nil, mandate: nil, birthDate: nil, birthPlace: nil, education: nil,
            contact: nil, salary: nil, numbers: numbers, history: Profile.History(),
            sources: [
                Source(id: "tse", name: "TSE", url: nil, updatedAt: updated),
                Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: updated),
            ])
    }

    private var empty: Profile.Numbers {
        Profile.Numbers(
            attendance: nil, proposals: nil, laws: nil, speeches: nil, votes: nil,
            quotaCents: nil, assetsCents: nil, campaignRevenueCents: nil, lastElectionVotes: nil)
    }

    @Test func missingNumbersShowADashNeverZero() {
        let content = ShareCardBuilder(calendar: calendar)
            .person(profile(office: .federalDeputy, numbers: empty))
        guard case .person(let metrics) = content.body else {
            Issue.record("Expected the person body")
            return
        }
        #expect(metrics.count == 4)
        #expect(metrics.allSatisfy { $0.value == PublicFormat.missing })
    }

    @Test func theSourceLineNamesTheHouseAndTheTime() {
        let content = ShareCardBuilder(calendar: calendar)
            .person(profile(office: .federalDeputy, numbers: empty))
        #expect(content.source.contains("Câmara dos Deputados"))
        #expect(content.source.contains("25/10, 05:42"))
        #expect(content.stamp.hasPrefix("CAMARA·PER·ANA-SOUZA·2026-10-25"))
        #expect(content.link.host() == ShareCardBuilder.host)
        #expect(content.link.query()?.contains("person=ana-souza") == true)
    }

    @Test func spendingKeepsEveryCategoryInTheTotal() {
        let list = ExpenseList(
            items: [], totalCents: 1_000,
            byMonth: [],
            byCategory: [
                .init(category: "A", cents: 100, count: 1),
                .init(category: "B", cents: 400, count: 1),
                .init(category: "C", cents: 200, count: 1),
                .init(category: "D", cents: 150, count: 1),
                .init(category: "E", cents: 150, count: 1),
            ])
        let spending = ShareCardBuilder(calendar: calendar).spending(list, year: 2026)
        #expect(spending.categories.map(\.name).prefix(3) == ["B", "C", "D"])
        #expect(spending.categories.count == 4)
        #expect(abs(spending.categories.map(\.share).reduce(0, +) - 1) < 0.0001)
    }

    @Test func peopleInAGroupAreAlphabetical() {
        let people = ["Zélia Lima", "Ana Souza", "Bruno Reis"].enumerated().map { index, name in
            PersonCard(
                slug: "p\(index)", name: name, office: .senator, uf: "sp", party: "PT",
                photo: nil, status: .inOffice)
        }
        let place = PlaceRepresentatives(
            uf: "sp", name: "São Paulo",
            groups: [
                RepresentativeGroup(
                    level: .state, office: .senator, title: "Senado", people: people)
            ],
            sources: [])
        let content = ShareCardBuilder(calendar: calendar).representatives(place)
        guard case .representatives(let groups) = content.body else {
            Issue.record("Expected the representatives body")
            return
        }
        #expect(groups.first?.names == ["Ana Souza", "Bruno Reis", "Zélia Lima"])
        #expect(groups.first?.count == "3")
    }

    @Test func theCodeOpensTheLink() {
        let url = ShareCardBuilder(calendar: calendar).link("vote", "camara-1")
        #expect(ShareCode.image(for: url) != nil)
    }
}
