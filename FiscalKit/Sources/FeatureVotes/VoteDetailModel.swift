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

    public static let homeUFKey = "FiscalHomeUF"

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

    public var lensStance: PoliticalStance? {
        guard let lens, !lens.themes.isEmpty, themes.contains(where: lens.contains) else {
            return nil
        }
        return lens.stance ?? .preferNotToSay
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
