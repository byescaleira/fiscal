import FiscalDomain
import Foundation

extension ShareCardBuilder {
    public static let followingLimit = 6

    public func following(_ people: [FollowedPerson]) -> ShareCardContent {
        let shown = people.sorted {
            $0.card.name.localizedStandardCompare($1.card.name) == .orderedAscending
        }
        .prefix(Self.followingLimit)
        let faces = shown.map { face($0.card) }
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Who I follow")),
            headline: String(appLocalized: "Who I follow on Fiscal"), faces: faces,
            body: .following(faces),
            source: sourceLine(
                name: String(appLocalized: "Chamber, Senate and TSE"), updatedAt: nil),
            stamp: stamp(origin: "fiscal", "SEG", "lista", shown.map(\.followedAt).max()),
            link: home())
    }

    func home() -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/"
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
