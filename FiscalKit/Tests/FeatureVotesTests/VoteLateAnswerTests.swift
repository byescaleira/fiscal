import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

private actor Turns {
    private var taken = 0
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]

    func take() async -> Int {
        let turn = taken
        taken += 1
        await withCheckedContinuation { waiting[turn] = $0 }
        return turn
    }

    func release(_ turn: Int) {
        waiting.removeValue(forKey: turn)?.resume()
    }

    func waitForTurn(_ turn: Int) async {
        let deadline = ContinuousClock.now + .seconds(5)
        while waiting[turn] == nil, ContinuousClock.now < deadline { await Task.yield() }
    }
}

private struct TurnByTurnVotes: PublicDataService {
    let turns: Turns
    let details: [VoteDetail]

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
    func people() async throws -> [PersonCard] { [] }
    func places() async throws -> [Place] { [] }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        throw PublicDataError.notFound
    }
    func profile(slug: String) async throws -> Profile { throw PublicDataError.notFound }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        throw PublicDataError.notFound
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        throw PublicDataError.notFound
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        throw PublicDataError.notFound
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        throw PublicDataError.notFound
    }
    func checks(slug: String) async throws -> FactCheckList? { nil }
    func recentVotes() async throws -> [VoteSummary] {
        [details[await turns.take()].vote]
    }
    func vote(id: String) async throws -> VoteDetail { details[await turns.take()] }
    func agenda() async throws -> Agenda { throw PublicDataError.notFound }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
}

@MainActor
struct VoteLateAnswerTests {
    private let base = ShowcasePublicData(
        scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720))

    private func details() async throws -> [VoteDetail] {
        [
            try await base.vote(id: "senado-22902026"),
            try await base.vote(id: "camara-18732026"),
        ]
    }

    @Test func aLateDetailFromAnOlderLoadKeepsTheNewerOne() async throws {
        let details = try await details()
        let turns = Turns()
        let model = VoteDetailModel(
            id: "camara-18732026", service: TurnByTurnVotes(turns: turns, details: details))
        let older = Task { await model.load() }
        await turns.waitForTurn(0)
        let newer = Task { await model.load() }
        await turns.waitForTurn(1)
        await turns.release(1)
        await newer.value
        await turns.release(0)
        await older.value
        #expect(model.detail == details[1])
        #expect(model.phase == .loaded)
    }

    @Test func aLateListFromAnOlderLoadKeepsTheNewerVotes() async throws {
        let details = try await details()
        let turns = Turns()
        let model = VotesModel(service: TurnByTurnVotes(turns: turns, details: details))
        let older = Task { await model.load() }
        await turns.waitForTurn(0)
        let newer = Task { await model.load() }
        await turns.waitForTurn(1)
        await turns.release(1)
        await newer.value
        await turns.release(0)
        await older.value
        #expect(model.votes == [details[1].vote])
        #expect(model.phase == .loaded)
    }
}
