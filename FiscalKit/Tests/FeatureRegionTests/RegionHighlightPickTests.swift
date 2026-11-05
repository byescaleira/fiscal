import FiscalDomain
import Foundation
import Testing

@testable import FeatureRegion

struct RegionHighlightPickTests {
    private func highlight(_ id: String, person slug: String?) -> Highlight {
        Highlight(
            id: id, kind: .action, title: "Destaque \(id)", subtitle: "", weight: 80,
            repercussion: nil, impact: 60, route: "pessoa",
            person: slug.map {
                PersonCard(
                    slug: $0, name: $0, office: .senator, uf: "ms", party: "PL", photo: nil,
                    status: .inOffice)
            },
            proposition: nil, date: CalendarDay(.now), url: nil, signals: .none)
    }

    @Test func onePersonShowsOnceEvenWithTwoHighlights() {
        let items = [
            highlight("h1", person: "soraya"), highlight("h2", person: "soraya"),
            highlight("h3", person: "nelsinho"),
        ]
        let picked = RegionActivityLoader.pick(
            items, region: ["soraya", "nelsinho"], voteIDs: [])
        #expect(picked.highlights.map(\.id) == ["h1", "h3"])
        #expect(!picked.isNational)
    }

    @Test func withoutSomeoneFromTheRegionOneNationalHighlightStays() {
        let items = [highlight("h1", person: "marinho"), highlight("h2", person: nil)]
        let picked = RegionActivityLoader.pick(items, region: ["soraya"], voteIDs: [])
        #expect(picked.highlights.map(\.id) == ["h1"])
        #expect(picked.isNational)
    }
}
