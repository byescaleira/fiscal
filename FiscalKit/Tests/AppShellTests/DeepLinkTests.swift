import Foundation
import Testing

@testable import AppShell

struct DeepLinkTests {
    @Test(arguments: [
        ("fiscal://races", DeepLink.route(.races, in: .today)),
        ("fiscal://settings", DeepLink.section(.settings)),
        ("fiscal://items/new", DeepLink.section(.today)),
        ("fiscal://unknown", DeepLink.section(.today)),
    ])
    func opensTheRightPlace(link: String, expected: DeepLink) throws {
        let url = try #require(URL(string: link))
        #expect(DeepLink.handles(url))
        #expect(DeepLink(url: url) == expected)
    }

    @Test func ignoresOtherSchemes() throws {
        #expect(!DeepLink.handles(try #require(URL(string: "https://example.com"))))
    }
}
