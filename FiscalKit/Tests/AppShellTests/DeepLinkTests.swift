import FeatureCore
import Foundation
import Testing

@testable import AppShell

struct DeepLinkTests {
    @Test(arguments: [
        ("fiscal://today", DeepLink.section(.today)),
        ("fiscal://mine", DeepLink.section(.mine)),
        ("fiscal://votes", DeepLink.section(.votes)),
        ("fiscal://money", DeepLink.section(.money)),
        ("fiscal://search", DeepLink.section(.search)),
        (
            "fiscal://person/nikolas-ferreira",
            DeepLink.route(.person(slug: "nikolas-ferreira"), in: .mine)
        ),
        (
            "fiscal://vote/camara-2026-1234",
            DeepLink.route(.vote(id: "camara-2026-1234"), in: .votes)
        ),
        (
            "fiscal://compare?slugs=tabata-amaral,kim-kataguiri",
            DeepLink.route(.compare(slugs: ["tabata-amaral", "kim-kataguiri"]), in: .search)
        ),
        ("fiscal://compare", DeepLink.route(.compare(slugs: []), in: .search)),
        ("fiscal://races", DeepLink.route(.races, in: .search)),
        ("fiscal://race/br-presidente", DeepLink.route(.race(id: "br-presidente"), in: .search)),
        ("fiscal://awaiting", DeepLink.route(.awaiting, in: .search)),
        ("fiscal://race", DeepLink.section(.today)),
        ("fiscal://lens", DeepLink.route(.lens, in: .today)),
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
        ("fiscal://person/nikolas-ferreira", .person),
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
}
