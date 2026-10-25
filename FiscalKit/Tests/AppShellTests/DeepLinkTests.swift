import Foundation
import Testing

@testable import AppShell

struct DeepLinkTests {
    @Test(arguments: [
        ("fiscal://items/new", DeepLink.route(.item(id: nil), in: .home)),
        ("fiscal://items/abc", DeepLink.route(.item(id: "abc"), in: .home)),
        ("fiscal://settings", DeepLink.section(.settings)),
        ("fiscal://unknown", DeepLink.section(.home)),
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
