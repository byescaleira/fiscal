import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMine

private struct FollowingService: PublicDataService {
    let base: ShowcasePublicData
    var votes: [String: [Int: [PersonVote]]] = [:]
    var failures: [String: PublicDataError] = [:]

    func meta() async throws -> PublicMeta { try await base.meta() }
    func people() async throws -> [PersonCard] { try await base.people() }
    func places() async throws -> [Place] { try await base.places() }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        try await base.representatives(uf: uf)
    }
    func profile(slug: String) async throws -> Profile { try await base.profile(slug: slug) }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        if let failure = failures[slug] { throw failure }
        let items = votes[slug]?[year] ?? []
        guard !items.isEmpty else { throw PublicDataError.notFound }
        return PublicList(items: items, total: items.count)
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        try await base.proposals(slug: slug, year: year)
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        try await base.speeches(slug: slug, year: year)
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        if let failure = failures[slug] { throw failure }
        throw PublicDataError.notFound
    }
    func checks(slug: String) async throws -> FactCheckList? {
        if let failure = failures[slug] { throw failure }
        throw PublicDataError.notFound
    }
    func recentVotes() async throws -> [VoteSummary] { try await base.recentVotes() }
    func vote(id: String) async throws -> VoteDetail { try await base.vote(id: id) }
    func agenda() async throws -> Agenda { try await base.agenda() }
    func money() async throws -> MoneyOverview { try await base.money() }
    func today() async throws -> TodayDigest { try await base.today() }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MineFollowingTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        code: String? = nil, follows: (any FollowRepository)?, suite: String,
        service: (any PublicDataService)? = nil, today: Date? = nil
    ) throws -> MineModel {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = MinePlaceMemory(defaults: defaults)
        memory.code = code
        let clock = today ?? now
        return MineModel(
            service: service ?? ShowcasePublicData(scenario: .normal, now: now), follows: follows,
            memory: memory, seen: FollowingSeenStore(suiteName: suite), now: { clock },
            publishesSnapshot: false)
    }

    private static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    private static func vote(_ id: String, on day: CalendarDay) -> PersonVote {
        PersonVote(
            voteId: id, date: day, proposition: "PL 1/2026", summary: "Resumo", vote: "Sim",
            partyGuidance: nil, approved: true, themes: [])
    }

    @Test func suggestsRepresentativesAndSupportedNotFollowed() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(code: "sp", follows: follows, suite: suite)
        await model.load()
        let first = try #require(model.suggestions.first)
        #expect(model.suggestions.count <= MineModel.suggestionLimit)
        let ranks = model.suggestions.map { MineModel.rank($0.office) }
        #expect(ranks == ranks.sorted())
        try await follows.follow(first, at: now)
        await model.load()
        #expect(!model.suggestions.map(\.slug).contains(first.slug))
        #expect(Set(model.suggestions.map(\.slug)).count == model.suggestions.count)
    }

    @Test func buildsUpdatesAndClearsTheBadgeWhenSeen() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        for card in people.prefix(3) {
            try await follows.follow(card, at: .distantPast)
        }
        let model = try makeModel(follows: follows, suite: suite)
        await model.load()
        #expect(model.updatesPhase == .loaded)
        #expect(!model.updates.isEmpty)
        #expect(model.updates.count <= FollowingFeed.limit)
        #expect(model.updates.map(\.day) == model.updates.map(\.day).sorted(by: >))
        #expect(model.newCount == model.updates.count)
        model.markSeen()
        #expect(model.newCount == 0)
        #expect(model.updates.allSatisfy { !model.isNew($0) })
    }

    @Test func emptiesTheFeedWhenNobodyIsFollowed() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(follows: follows, suite: suite)
        await model.load()
        #expect(model.updates.isEmpty)
        #expect(model.updatesPhase == .idle)
        #expect(model.newCount == 0)
    }

    @Test func aMissingFileIsEmptyAndOnlyFailuresAreMissing() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = [Self.card("a", "Ana"), Self.card("b", "Bia"), Self.card("c", "Caio")]
        for card in people { try await follows.follow(card, at: .distantPast) }
        let today = CalendarDay(now)
        let service = FollowingService(
            base: ShowcasePublicData(scenario: .normal, now: now),
            votes: ["c": [today.year: [Self.vote("v1", on: today)]]],
            failures: ["a": .notFound, "b": .offline])
        let model = try makeModel(follows: follows, suite: suite, service: service)
        await model.load()
        #expect(model.updatesPhase == .loaded)
        #expect(model.missing.map(\.slug) == ["b"])
        let update = try #require(model.updates.first)
        #expect(model.updates.map(\.person.slug) == ["c"])
        #expect(model.detail(for: update).contains("Chamber"))
        #expect(MineModel.houseName(.senator) == "Senate")
        #expect(MineModel.houseName(.governor) == nil)
    }

    @Test func inJanuaryTheWindowAlsoReadsThePreviousYear() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(Self.card("c", "Caio"), at: .distantPast)
        let today = try #require(CalendarDay(year: 2_027, month: 1, day: 5))
        let december = try #require(CalendarDay(year: 2_026, month: 12, day: 20))
        let service = FollowingService(
            base: ShowcasePublicData(scenario: .normal, now: now),
            votes: ["c": [2_026: [Self.vote("v2", on: december)]]])
        let model = try makeModel(
            follows: follows, suite: suite, service: service, today: today.date())
        await model.load()
        #expect(model.updatesPhase == .loaded)
        #expect(model.missing.isEmpty)
        #expect(model.updates.map(\.day) == [december])
    }
}
