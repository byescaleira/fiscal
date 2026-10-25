import Foundation

public protocol PublicDataService: Sendable {
    func meta() async throws -> PublicMeta
    func people() async throws -> [PersonCard]
    func places() async throws -> [Place]
    func representatives(uf: String) async throws -> PlaceRepresentatives
    func cityRepresentatives(code: String) async throws -> PlaceRepresentatives?
    func profile(slug: String) async throws -> Profile
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote>
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal>
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech>
    func expenses(slug: String, year: Int) async throws -> ExpenseList
    func checks(slug: String) async throws -> FactCheckList?
    func recentVotes() async throws -> [VoteSummary]
    func vote(id: String) async throws -> VoteDetail
    func agenda() async throws -> Agenda
    func money() async throws -> MoneyOverview
    func today() async throws -> TodayDigest
    func actions(slug: String) async throws -> ActionList?
    func highlights() async throws -> HighlightList?
    func weightMethod() async throws -> WeightMethod?
}

extension PublicDataService {
    public func cityRepresentatives(code: String) async throws -> PlaceRepresentatives? { nil }

    public func actions(slug: String) async throws -> ActionList? { nil }

    public func highlights() async throws -> HighlightList? { nil }

    public func weightMethod() async throws -> WeightMethod? { nil }
}

public enum PublicDataError: LocalizedError, Equatable, Sendable {
    case notFound
    case rejected(Int)
    case offline
    case unavailable
    case invalidData

    public var message: String {
        switch self {
        case .notFound: String(appLocalized: "This data isn't published yet.")
        case .rejected, .unavailable:
            String(appLocalized: "Couldn't reach the public data server. Try again in a moment.")
        case .offline: String(appLocalized: "No connection. Check the internet and try again.")
        case .invalidData:
            String(appLocalized: "The public data came in a format Fiscal can't read.")
        }
    }

    public var errorDescription: String? { message }
}

public enum PublicDataPath {
    public static let meta = "meta.json"
    public static let people = "index/people.json"
    public static let places = "index/places.json"
    public static let recentVotes = "votes/recent.json"
    public static let agenda = "agenda/today.json"
    public static let money = "money/overview.json"
    public static let today = "today.json"
    public static let highlights = "highlights.json"
    public static let weightMethod = "method/weight.json"

    public static func representatives(uf: String) -> String { "places/\(uf.lowercased()).json" }

    public static func cityRepresentatives(code: String) -> String { "places/city/\(code).json" }

    public static func profile(slug: String) -> String { "people/\(slug).json" }

    public static func votes(slug: String, year: Int) -> String {
        "people/\(slug)/votes-\(year).json"
    }

    public static func proposals(slug: String, year: Int) -> String {
        "people/\(slug)/proposals-\(year).json"
    }

    public static func speeches(slug: String, year: Int) -> String {
        "people/\(slug)/speeches-\(year).json"
    }

    public static func expenses(slug: String, year: Int) -> String {
        "people/\(slug)/expenses-\(year).json"
    }

    public static func checks(slug: String) -> String { "people/\(slug)/checks.json" }

    public static func actions(slug: String) -> String { "people/\(slug)/actions.json" }

    public static func vote(id: String) -> String { "votes/\(id).json" }
}

public enum PublicDataCoding {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = try? Date(text, strategy: .iso8601) { return date }
            if text.count == 10, let day = CalendarDay(text) { return day.date() }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected an ISO 8601 date, found \(text)")
        }
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
