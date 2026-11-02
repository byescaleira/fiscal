import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureRegion

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RegionSeatTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        code: String? = nil, service: (any PublicDataService)? = nil
    ) throws -> RegionModel {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = RegionPlaceMemory(defaults: defaults)
        memory.code = code
        return RegionModel(
            service: service ?? ShowcasePublicData(scenario: .normal, now: now), memory: memory)
    }

    private static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    @Test func aRegionalHighlightOpensItsContentWithoutShare() throws {
        let model = try makeModel()
        let highlight = Highlight(
            id: "action-1", kind: .action, title: "Fato", subtitle: "", weight: 60,
            repercussion: nil, impact: 60, route: "a", person: Self.card("a", "Ana"),
            proposition: nil, date: CalendarDay(Date(timeIntervalSince1970: 1_792_917_720)),
            url: nil, signals: .none)
        guard case .content(let content) = model.route(for: highlight) else {
            Issue.record("A regional highlight must open the content")
            return
        }
        #expect(content.person?.slug == "a")
        #expect(content.shareHighlightID == nil)
    }

    @Test func aSeatWithoutViceOrElectedStandsAlone() {
        let holder = Self.card("a", "Ana")
        let vice = Self.card("b", "Bia")
        #expect(
            RegionSeat(level: .city, place: "SP", holder: holder, vice: nil, elected: [])
                .standsAlone)
        #expect(
            !RegionSeat(level: .city, place: "SP", holder: holder, vice: vice, elected: [])
                .standsAlone)
        #expect(
            !RegionSeat(level: .country, place: "BR", holder: holder, vice: nil, elected: [vice])
                .standsAlone)
    }
}
