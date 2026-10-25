import FiscalDomain
import Foundation

public struct RepresentativeBallots: Hashable, Sendable {
    public struct ChoiceCount: Hashable, Sendable {
        public let choice: String
        public let count: Int
    }

    public static let namedLimit = 3

    public let vote: VoteBoard
    public let uf: String
    public let ballots: [VoteDetail.Ballot]

    public init(detail: VoteDetail, uf: String) {
        let uf = uf.lowercased()
        vote = VoteBoard(detail.vote)
        self.uf = uf
        ballots = detail.people.filter { $0.uf.lowercased() == uf }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var counts: [ChoiceCount] {
        Dictionary(grouping: ballots, by: { Self.display($0.vote) })
            .map { ChoiceCount(choice: $0.key, count: $0.value.count) }
            .sorted { Self.order($0.choice, $1.choice) }
    }

    public var headline: String {
        "\(vote.proposition) · \(vote.houseShort), \(vote.dayText) · \(vote.outcomeTitle) (\(vote.scoreText))"
    }

    public var body: String {
        let place = uf.uppercased(with: .app)
        guard !ballots.isEmpty else {
            return String(
                appLocalized: "No representative from \(place) appears in this roll call.")
        }
        let list =
            ballots.count <= Self.namedLimit
            ? ballots.map { "\($0.name) (\($0.party)): \(Self.display($0.vote))" }
                .joined(separator: "; ")
            : counts.map { "\($0.choice) \(PublicFormat.number($0.count))" }
                .joined(separator: " · ")
        return String(appLocalized: "Representatives from \(place): \(list).")
    }

    public var dialog: String { "\(headline). \(body)" }

    static func display(_ vote: String) -> String {
        let trimmed = vote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? PublicFormat.missing : trimmed
    }

    static func order(_ lhs: String, _ rhs: String) -> Bool {
        let rank = { (value: String) -> Int in
            switch value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) {
            case "sim": 0
            case "nao": 1
            default: 2
            }
        }
        let left = rank(lhs)
        let right = rank(rhs)
        if left != right { return left < right }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}

public struct IntegrationActions: Sendable {
    public static let searchLimit = 25

    private let service: any PublicDataService

    public init(service: any PublicDataService) {
        self.service = service
    }

    public func latestVote(uf: String) async throws -> RepresentativeBallots? {
        let votes = try await service.recentVotes()
        guard let vote = VoteDeck.ordered(votes).first(where: \.nominal) else { return nil }
        let detail = try await service.vote(id: vote.id)
        return RepresentativeBallots(detail: detail, uf: uf)
    }

    public func people(matching text: String) async throws -> [PersonCard] {
        let query = Self.fold(text)
        let everyone = try await service.people()
        guard !query.isEmpty else { return [] }
        return Array(
            Self.alphabetical(everyone.filter { Self.fold($0.name).contains(query) })
                .prefix(Self.searchLimit))
    }

    public func people(slugs: [String]) async throws -> [PersonCard] {
        let everyone = try await service.people()
        let bySlug = Dictionary(
            everyone.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        return slugs.compactMap { bySlug[$0] }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func alphabetical(_ people: [PersonCard]) -> [PersonCard] {
        people.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
