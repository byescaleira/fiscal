import FeatureCore
import Foundation
import Testing

@testable import AppShell

struct DeepLinkTests {
    @Test(arguments: [
        ("fiscal://today", DeepLink.section(.today)),
        ("fiscal://mine", DeepLink.section(.following)),
        ("fiscal://following", DeepLink.section(.following)),
        ("fiscal://votes", DeepLink.section(.votes)),
        ("fiscal://money", DeepLink.section(.money)),
        ("fiscal://search", DeepLink.section(.search)),
        (
            "fiscal://person/nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .following)
        ),
        (
            "fiscal://vote/camara-2026-1234",
            DeepLink.route(.vote(id: "camara-2026-1234"), in: .votes)
        ),
        ("fiscal://highlight/action-1", DeepLink.route(.highlight(id: "action-1"), in: .today)),
        (
            "fiscal://compare?slugs=tabata-amaral,kim-kataguiri",
            DeepLink.route(.compare(slugs: ["tabata-amaral", "kim-kataguiri"]), in: .search)
        ),
        ("fiscal://compare", DeepLink.route(.compare(slugs: []), in: .search)),
        ("fiscal://races", DeepLink.route(.races, in: .search)),
        ("fiscal://race/br-presidente", DeepLink.route(.race(id: "br-presidente"), in: .search)),
        ("fiscal://awaiting", DeepLink.route(.awaiting, in: .search)),
        ("fiscal://race", DeepLink.section(.today)),
        ("fiscal://lens", DeepLink.route(.support, in: .today)),
        ("fiscal://support", DeepLink.route(.support, in: .today)),
        ("fiscal://artists", DeepLink.route(.artists, in: .today)),
        ("fiscal://settings", DeepLink.route(.settings, in: .today)),
        ("fiscal://person", DeepLink.section(.today)),
        ("fiscal://items/new", DeepLink.section(.today)),
        ("fiscal://unknown", DeepLink.section(.today)),
    ])
    func opensTheRightPlace(link: String, expected: DeepLink) throws {
        let url = try #require(URL(string: link))
        #expect(DeepLink.handles(url))
        #expect(DeepLink(url: url) == expected)
    }

    @Test(arguments: [
        ("fiscal://votes", FiscalEvents.DeepLinkKind.section),
        ("fiscal://mine", .section),
        ("fiscal://person/nikolas-ferreira", .person),
        ("fiscal://highlight/action-1", .highlight),
        ("fiscal://expenses/tabata-amaral?year=2025", .expenses),
        ("fiscal://compare?slugs=tabata-amaral,kim-kataguiri", .compare),
        ("fiscal://race", .unknown),
        ("fiscal://items/new", .unknown),
        ("https://example.com/person/nikolas-ferreira", .unknown),
    ])
    func logsOnlyTheRouteKind(link: String, kind: FiscalEvents.DeepLinkKind) throws {
        let url = try #require(URL(string: link))
        #expect(DeepLink.kind(of: url) == kind)
        let message = FiscalEvents.deepLink(DeepLink.kind(of: url)).message.text
        #expect(!message.contains("nikolas"))
        #expect(!message.contains("tabata"))
        #expect(!message.contains("2025"))
    }

    @Test func ignoresOtherSchemes() throws {
        #expect(!DeepLink.handles(try #require(URL(string: "https://example.com"))))
    }

    @Test(arguments: [
        (
            "https://fiscal.byescaleira.com/?person=nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .following),
            FiscalEvents.DeepLinkKind.person
        ),
        (
            "https://fiscal.byescaleira.com/?vote=camara-2026-1234",
            DeepLink.route(.vote(id: "camara-2026-1234"), in: .votes), .vote
        ),
        (
            "https://fiscal.byescaleira.com/?expenses=tabata-amaral-2025",
            DeepLink.route(.expenses(slug: "tabata-amaral", year: 2025), in: .money), .expenses
        ),
        (
            "https://fiscal.byescaleira.com/?compare=tabata-amaral,kim-kataguiri",
            DeepLink.route(.compare(slugs: ["tabata-amaral", "kim-kataguiri"]), in: .search),
            .compare
        ),
        (
            "https://fiscal.byescaleira.com/?place=SP",
            DeepLink.route(.share(.representatives(uf: "sp")), in: .following), .place
        ),
        (
            "https://fiscal.byescaleira.com/?race=br-presidente",
            DeepLink.route(.race(id: "br-presidente"), in: .search), .race
        ),
        (
            "https://fiscal.byescaleira.com/?highlight=camara-2026-1234",
            DeepLink.route(.share(.highlight(id: "camara-2026-1234")), in: .today), .highlight
        ),
        (
            "https://fiscal.byescaleira.com?person=nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .following), .person
        ),
        ("https://fiscal.byescaleira.com/?locale=pt-BR", DeepLink.section(.today), .unknown),
        ("https://fiscal.byescaleira.com/?person=", DeepLink.section(.today), .unknown),
        ("https://fiscal.byescaleira.com/privacy?person=x", DeepLink.section(.today), .unknown),
        ("https://fiscal.byescaleira.com/link?s=abc&k=def", DeepLink.section(.today), .unknown),
    ])
    func siteLinksOpenTheContent(
        link: String, expected: DeepLink, kind: FiscalEvents.DeepLinkKind
    ) throws {
        let url = try #require(URL(string: link))
        #expect(DeepLink.handles(url))
        #expect(DeepLink(url: url) == expected)
        #expect(DeepLink.kind(of: url) == kind)
    }

    @Test(arguments: [
        "https://example.com/?person=nikolas-ferreira",
        "http://fiscal.byescaleira.com/?person=nikolas-ferreira",
        "https://fiscal.byescaleira.com.example.com/?person=nikolas-ferreira",
    ])
    func siteLinksFromAnotherHostFallBack(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(!DeepLink.handles(url))
        #expect(DeepLink(url: url) == .section(.today))
        #expect(DeepLink.kind(of: url) == .unknown)
    }

    @Test func siteLinksWithAPathInTheValueOpenToday() throws {
        for query in ["person=../../x", "vote=a%2Fb", "race=..", "place=a%5Cb"] {
            let url = try #require(URL(string: "https://fiscal.byescaleira.com/?\(query)"))
            #expect(DeepLink(url: url) == .section(.today), "\(query)")
        }
    }
}
