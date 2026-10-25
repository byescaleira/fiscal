import Foundation

public enum Route: Hashable, Sendable {
    case person(slug: String)
    case vote(id: String)
    case compare(slugs: [String])
    case races
    case lens
    case artists
    case settings
    case share(ShareSubject)
}
