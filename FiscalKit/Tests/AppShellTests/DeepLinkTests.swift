import FeatureCore
import Foundation
import Testing

@testable import AppShell

struct DeepLinkTests {
    @Test(arguments: [
        ("fiscal://feed", DeepLink.section(.feed)),
        ("fiscal://today", DeepLink.section(.feed)),
        ("fiscal://region", DeepLink.section(.region)),
        ("fiscal://mine", DeepLink.section(.region)),
        ("fiscal://following", DeepLink.section(.region)),
        ("fiscal://votes", DeepLink.section(.votes)),
        ("fiscal://money", DeepLink.section(.money)),
        ("fiscal://search", DeepLink.section(.search)),
        (
            "fiscal://person/nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .region)
        ),
        (
            "fiscal://vote/camara-2026-1234",
            DeepLink.route(.vote(id: "camara-2026-1234"), in: .votes)
        ),
        ("fiscal://highlight/action-1", DeepLink.route(.highlight(id: "action-1"), in: .feed)),
        (
            "fiscal://compare?slugs=tabata-amaral,kim-kataguiri",
            DeepLink.route(.compare(slugs: ["tabata-amaral", "kim-kataguiri"]), in: .search)
        ),
        ("fiscal://compare", DeepLink.route(.compare(slugs: []), in: .search)),
        ("fiscal://races", DeepLink.route(.races, in: .search)),
        ("fiscal://race/br-presidente", DeepLink.route(.race(id: "br-presidente"), in: .search)),
        ("fiscal://awaiting", DeepLink.route(.awaiting, in: .search)),
        ("fiscal://race", DeepLink.section(.feed)),
        ("fiscal://lens", DeepLink.route(.support, in: .feed)),
        ("fiscal://support", DeepLink.route(.support, in: .feed)),
        ("fiscal://artists", DeepLink.route(.artists, in: .feed)),
        ("fiscal://settings", DeepLink.route(.settings, in: .feed)),
        ("fiscal://person", DeepLink.section(.feed)),
        ("fiscal://items/new", DeepLink.section(.feed)),
        ("fiscal://unknown", DeepLink.section(.feed)),
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
        ("fiscal://support", .support),
        ("fiscal://lens", .support),
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
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .region),
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
            DeepLink.route(.share(.representatives(uf: "sp")), in: .region), .place
        ),
        (
            "https://fiscal.byescaleira.com/?race=br-presidente",
            DeepLink.route(.race(id: "br-presidente"), in: .search), .race
        ),
        (
            "https://fiscal.byescaleira.com/?highlight=camara-2026-1234",
            DeepLink.route(.share(.highlight(id: "camara-2026-1234")), in: .feed), .highlight
        ),
        (
            "https://fiscal.byescaleira.com?person=nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .region), .person
        ),
        ("https://fiscal.byescaleira.com/?locale=pt-BR", DeepLink.section(.feed), .unknown),
        ("https://fiscal.byescaleira.com/?person=", DeepLink.section(.feed), .unknown),
        ("https://fiscal.byescaleira.com/privacy?person=x", DeepLink.section(.feed), .unknown),
        ("https://fiscal.byescaleira.com/link?s=abc&k=def", DeepLink.section(.feed), .unknown),
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
        #expect(DeepLink(url: url) == .section(.feed))
        #expect(DeepLink.kind(of: url) == .unknown)
    }

    @Test func siteLinksWithAPathInTheValueOpenToday() throws {
        for query in ["person=../../x", "vote=a%2Fb", "race=..", "place=a%5Cb"] {
            let url = try #require(URL(string: "https://fiscal.byescaleira.com/?\(query)"))
            #expect(DeepLink(url: url) == .section(.feed), "\(query)")
        }
    }
}
