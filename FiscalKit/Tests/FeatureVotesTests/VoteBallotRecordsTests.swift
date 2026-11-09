import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct VoteBallotRecordsTests {
    private func loaded() async -> VoteDetailModel {
        let model = VoteDetailModel(
            id: "camara-18732026",
            service: ShowcasePublicData(
                scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720)))
        await model.load()
        return model
    }

    @Test func recordsStartInAlphabeticalOrderWithTheStateInCapitals() async throws {
        let vote = await loaded()
        let records = vote.ballotRecords(sortedBy: VoteDetailModel.ballotOrder)
        #expect(records.count == vote.ballots.count)
        #expect(Set(records.map(\.id)) == Set(vote.ballots.map(\.id)))
        let names = records.map(\.name)
        #expect(
            zip(names, names.dropFirst()).allSatisfy {
                $0.localizedStandardCompare($1) != .orderedDescending
            })
        let first = try #require(records.first)
        #expect(first.uf == first.uf.uppercased())
    }

    @Test func sortingByBallotGroupsYesBeforeNoBeforeTheRest() async {
        let vote = await loaded()
        let records = vote.ballotRecords(sortedBy: [KeyPathComparator(\.voteRank)])
        #expect(records.map(\.voteRank) == records.map(\.voteRank).sorted())
        #expect(records.first?.choice == .yes)
        let noIndex = records.firstIndex { $0.choice == .no }
        let lastYes = records.lastIndex { $0.choice == .yes }
        #expect((lastYes ?? 0) < (noIndex ?? 0))
        let reversed = vote.ballotRecords(
            sortedBy: [KeyPathComparator(\.voteRank, order: .reverse)])
        #expect(reversed.first?.choice != .yes)
    }

    @Test func sortingByPartyKeepsNamesInOrderWithinEachParty() async {
        let vote = await loaded()
        let records = vote.ballotRecords(
            sortedBy: [KeyPathComparator(\.party, comparator: .localizedStandard)])
        let pairs = zip(records, records.dropFirst())
        #expect(
            pairs.allSatisfy { lhs, rhs in
                let party = lhs.party.localizedStandardCompare(rhs.party)
                return party == .orderedAscending
                    || (party == .orderedSame
                        && lhs.name.localizedStandardCompare(rhs.name) != .orderedDescending)
            })
    }

    @Test func recordsFollowTheSearchAndTheFilters() async {
        let vote = await loaded()
        vote.ballotFilter = .no
        let noes = vote.ballotRecords(sortedBy: VoteDetailModel.ballotOrder)
        #expect(noes.count == vote.count(.no))
        #expect(noes.allSatisfy { $0.choice == .no })
        vote.clearBallotFilters()
        vote.select(party: "PSOL")
        #expect(
            vote.ballotRecords(sortedBy: VoteDetailModel.ballotOrder)
                .allSatisfy { $0.party == "PSOL" })
    }

    @Test func onlyOnePersonWithAProfileOpens() async throws {
        let vote = await loaded()
        let records = vote.ballotRecords(sortedBy: VoteDetailModel.ballotOrder)
        let person = try #require(records.first { $0.slug != nil })
        let slug = try #require(person.slug)
        #expect(vote.profileRoute(for: [person.id]) == .person(slug: slug))
        let anonymous = try #require(records.first { $0.slug == nil })
        #expect(vote.profileRoute(for: [anonymous.id]) == nil)
        #expect(vote.profileRoute(for: [person.id, anonymous.id]) == nil)
        #expect(vote.profileRoute(for: []) == nil)
    }
}
