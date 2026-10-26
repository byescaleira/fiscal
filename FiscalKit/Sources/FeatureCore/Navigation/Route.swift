import Foundation

public enum Route: Hashable, Sendable {
    case person(slug: String)
    case vote(id: String)
    case expenses(slug: String, year: Int)
    case compare(slugs: [String])
    case races
    case memory
    case pastElection(year: Int)
    case pastRace(id: String)
    case period(id: String)
    case studyGuide(id: String)
    case lens
    case artists
    case settings
    case share(ShareSubject)
}
