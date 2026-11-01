import FeatureCore
import FiscalDomain
import Foundation

extension VoteDetailModel {
    public struct BallotRecord: Identifiable, Equatable, Sendable {
        public let id: String
        public let slug: String?
        public let name: String
        public let party: String
        public let uf: String
        public let vote: String
        public let choice: BallotChoice?
        public let voteRank: Int
    }

    public static var ballotOrder: [KeyPathComparator<BallotRecord>] {
        [KeyPathComparator(\.name, comparator: .localizedStandard)]
    }

    public func ballotRecords(sortedBy order: [KeyPathComparator<BallotRecord>])
        -> [BallotRecord]
    {
        ballots.map(Self.record).sorted(
            using: order + [
                KeyPathComparator(\.name, comparator: .localizedStandard),
                KeyPathComparator(\.id),
            ])
    }

    public func profileRoute(for ids: Set<BallotRecord.ID>) -> Route? {
        guard ids.count == 1, let id = ids.first,
            let slug = (detail?.people ?? []).first(where: { $0.id == id })?.slug
        else { return nil }
        return .person(slug: slug)
    }

    static func record(_ ballot: VoteDetail.Ballot) -> BallotRecord {
        let choice = BallotChoice(vote: ballot.vote)
        let rank = choice.flatMap { BallotChoice.allCases.firstIndex(of: $0) }
        return BallotRecord(
            id: ballot.id, slug: ballot.slug, name: ballot.name, party: ballot.party,
            uf: ballot.uf.uppercased(), vote: ballot.vote, choice: choice,
            voteRank: rank ?? BallotChoice.allCases.count)
    }
}
