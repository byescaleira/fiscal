import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

private actor YearGates {
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]

    func pass(_ year: Int) async {
        await withCheckedContinuation { waiting[year] = $0 }
    }

    func open(_ year: Int) {
        waiting.removeValue(forKey: year)?.resume()
    }

    func isWaiting(_ year: Int) -> Bool { waiting[year] != nil }

    func waitForRequest(_ year: Int) async {
        let deadline = ContinuousClock.now + .seconds(5)
        while !isWaiting(year), ContinuousClock.now < deadline { await Task.yield() }
    }
}

private struct GatedExpenses: PublicDataService {
    let base: ShowcasePublicData
    let gates: YearGates
    let lists: [Int: ExpenseList]

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
    func people() async throws -> [PersonCard] { [] }
    func places() async throws -> [Place] { [] }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        throw PublicDataError.notFound
    }
    func profile(slug: String) async throws -> Profile { try await base.profile(slug: slug) }
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
        await gates.pass(year)
        guard let list = lists[year] else { throw PublicDataError.notFound }
        return list
    }
    func checks(slug: String) async throws -> FactCheckList? { nil }
    func recentVotes() async throws -> [VoteSummary] { [] }
    func vote(id: String) async throws -> VoteDetail { throw PublicDataError.notFound }
    func agenda() async throws -> Agenda { throw PublicDataError.notFound }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
}

@MainActor
struct ExpensesLateAnswerTests {
    private let slug = "tabata-amaral"
    private let base = ShowcasePublicData(
        scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720))

    private func model(lists: [Int: ExpenseList], gates: YearGates) -> ExpensesModel {
        ExpensesModel(
            slug: slug, year: 2_025,
            service: GatedExpenses(base: base, gates: gates, lists: lists))
    }

    @Test func aLateAnswerForThePreviousYearKeepsTheChosenYear() async throws {
        let gates = YearGates()
        let chosen = try await base.expenses(slug: slug, year: 2_026)
        let expenses = model(lists: [2_025: .empty, 2_026: chosen], gates: gates)
        let older = Task { await expenses.load() }
        await gates.waitForRequest(2_025)
        let newer = Task { await expenses.select(year: 2_026) }
        await gates.waitForRequest(2_026)
        await gates.open(2_026)
        await newer.value
        await gates.open(2_025)
        await older.value
        #expect(expenses.year == 2_026)
        #expect(expenses.list == chosen)
        #expect(expenses.phase == .loaded)
        #expect(!expenses.isEmpty)
    }

    @Test func aLateFailureForThePreviousYearKeepsTheChosenYearLoaded() async throws {
        let gates = YearGates()
        let chosen = try await base.expenses(slug: slug, year: 2_026)
        let expenses = model(lists: [2_026: chosen], gates: gates)
        let older = Task { await expenses.load() }
        await gates.waitForRequest(2_025)
        let newer = Task { await expenses.select(year: 2_026) }
        await gates.waitForRequest(2_026)
        await gates.open(2_026)
        await newer.value
        await gates.open(2_025)
        await older.value
        #expect(expenses.list == chosen)
        #expect(expenses.phase == .loaded)
    }
}
