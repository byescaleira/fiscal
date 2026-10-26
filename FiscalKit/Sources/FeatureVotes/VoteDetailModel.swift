import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class VoteDetailModel {
    public enum BallotFilter: String, CaseIterable, Identifiable, Sendable {
        case all, yes, no, other, absent

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .all: String(appLocalized: "All")
            case .yes: BallotChoice.yes.title
            case .no: BallotChoice.no.title
            case .other: String(appLocalized: "Other")
            case .absent: BallotChoice.absent.title
            }
        }

        public var choice: BallotChoice? {
            switch self {
            case .all: nil
            case .yes: .yes
            case .no: .no
            case .other: .abstain
            case .absent: .absent
            }
        }

        func matches(_ choice: BallotChoice?) -> Bool {
            switch self {
            case .all: true
            case .yes: choice == .yes
            case .no: choice == .no
            case .other: choice == .abstain || choice == nil
            case .absent: choice == .absent
            }
        }
    }

    public struct PartyRow: Identifiable, Equatable, Sendable {
        public let party: String
        public let yes: Int
        public let no: Int
        public let abstain: Int
        public let absent: Int

        public var id: String { party }
        public var total: Int { yes + no + abstain + absent }

        public func count(_ choice: BallotChoice) -> Int {
            switch choice {
            case .yes: yes
            case .no: no
            case .abstain: abstain
            case .absent: absent
            }
        }
    }

    public struct GuidanceGroup: Identifiable, Equatable, Sendable {
        public let guidance: String
        public let choice: BallotChoice?
        public let parties: [String]

        public var id: String { guidance }
    }

    public static let homeUFKey = HomePlace.mineKey

    public let id: String
    public let homeUF: String?
    public private(set) var detail: VoteDetail?
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    public var searchText = ""
    public var ballotFilter: BallotFilter = .all
    public var party: String?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?

    public init(
        id: String, service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        homeUF: String? = nil
    ) {
        self.id = id
        self.service = service
        lensRepository = lens
        self.homeUF = homeUF.map { $0.lowercased() }.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isEmpty: Bool { detail == nil }

    public var vote: VoteSummary? { detail?.vote }

    public var outcome: VoteOutcome? { vote.map(VoteOutcome.init) }

    public var themes: [Theme] {
        guard let vote else { return [] }
        return lens?.ordered(vote.themes) ?? vote.themes
    }

    public var showsLensBadge: Bool {
        guard let lens, !lens.themes.isEmpty else { return false }
        return themes.contains(where: lens.contains)
    }

    public var supportedBallots: [VoteDetail.Ballot] {
        guard let lens, !lens.supported.isEmpty else { return [] }
        return (detail?.people ?? []).filter { lens.supports($0.slug) }
            .sorted { lens.supportRank(of: $0.slug) < lens.supportRank(of: $1.slug) }
    }

    public var supportedHeadline: String? {
        let choices = supportedBallots.map { BallotChoice(vote: $0.vote) }
        guard choices.count > 1 else { return nil }
        if let first = choices[0], choices.allSatisfy({ $0 == first }) {
            return String(appLocalized: "All of them voted \(first.title)")
        }
        return String(appLocalized: "They did not all vote the same way")
    }

    public func isLensTheme(_ theme: Theme) -> Bool { lens?.contains(theme) ?? false }

    public var guidanceGroups: [GuidanceGroup] {
        let groups = Dictionary(grouping: detail?.guidance ?? [], by: \.guidance)
        return groups.map { guidance, items in
            GuidanceGroup(
                guidance: guidance, choice: BallotChoice(vote: guidance),
                parties: items.map(\.party).sorted(by: Self.alphabetical))
        }
        .sorted { lhs, rhs in
            (Self.guidanceRank(lhs.choice), lhs.guidance) < (
                Self.guidanceRank(rhs.choice), rhs.guidance
            )
        }
    }

    public var partyRows: [PartyRow] {
        guard let detail else { return [] }
        let byParty = Dictionary(grouping: detail.people, by: \.party)
        let names = Set(detail.parties.map(\.party)).union(byParty.keys)
        let rows = names.map { name in
            if let ballots = byParty[name], !ballots.isEmpty {
                let choices = ballots.map { BallotChoice(vote: $0.vote) ?? .abstain }
                return PartyRow(
                    party: name, yes: choices.count { $0 == .yes },
                    no: choices.count { $0 == .no }, abstain: choices.count { $0 == .abstain },
                    absent: choices.count { $0 == .absent })
            }
            let tally = detail.parties.first { $0.party == name }
            return PartyRow(
                party: name, yes: tally?.yes ?? 0, no: tally?.no ?? 0,
                abstain: tally?.others ?? 0, absent: 0)
        }
        return rows.sorted { lhs, rhs in
            lhs.total != rhs.total ? lhs.total > rhs.total : Self.alphabetical(lhs.party, rhs.party)
        }
    }

    public var largestBench: Int { partyRows.map(\.total).max() ?? 0 }

    public var ballots: [VoteDetail.Ballot] {
        let query = Self.fold(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        return (detail?.people ?? [])
            .filter { ballot in
                ballotFilter.matches(BallotChoice(vote: ballot.vote))
                    && (party.map { $0 == ballot.party } ?? true)
                    && (query.isEmpty
                        || Self.fold("\(ballot.name) \(ballot.party) \(ballot.uf)").contains(query))
            }
            .sorted { Self.alphabetical($0.name, $1.name) }
    }

    public func count(_ filter: BallotFilter) -> Int {
        (detail?.people ?? []).count { filter.matches(BallotChoice(vote: $0.vote)) }
    }

    public var representatives: [VoteDetail.Ballot]? {
        guard let homeUF else { return nil }
        return (detail?.people ?? []).filter { $0.uf.lowercased() == homeUF }
            .sorted { Self.alphabetical($0.name, $1.name) }
    }

    public func select(party: String?) {
        self.party = self.party == party ? nil : party
    }

    public func clearBallotFilters() {
        searchText = ""
        ballotFilter = .all
        party = nil
    }

    public func load() async {
        if detail == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            lens = try? await lensRepository?.lens()
            guard let service else { throw PublicDataError.unavailable }
            detail = try await service.vote(id: id)
        }
    }

    static func alphabetical(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private static func guidanceRank(_ choice: BallotChoice?) -> Int {
        switch choice {
        case .yes?: 0
        case .no?: 1
        case .abstain?: 2
        case .absent?: 3
        case nil: 4
        }
    }
}
