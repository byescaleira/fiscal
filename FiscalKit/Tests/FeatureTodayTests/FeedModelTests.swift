import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

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
struct FeedModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)
    private let afterTheResult = Date(timeIntervalSince1970: 1_792_963_200)

    private func makeModel(
        following slugs: [String] = [], scenario: PublicDataScenario = .normal
    ) async throws -> FeedModel {
        let service = ShowcasePublicData(scenario: scenario, now: now)
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        for slug in slugs {
            let card = try #require(people.first { $0.slug == slug })
            try await repository.follow(card, at: now)
        }
        return FeedModel(
            service: service, follows: repository,
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { now }, publishesSnapshot: false)
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

    @Test func withoutFollowingThereAreRelevantLinesAndTheEnd() async throws {
        let model = try await makeModel()
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.items.isEmpty)
        #expect(model.followsNobody)
        #expect(model.items.allSatisfy { !$0.isFollowing })
        #expect(model.reachedEnd)
        #expect(model.endMessage.isEmpty == false)
    }

    @Test func followingBringsTheirFactsWithTheReason() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        #expect(model.items.contains { $0.isFollowing })
        model.filter = .following
        #expect(model.visible.allSatisfy { $0.isFollowing })
        model.filter = .relevant
        #expect(model.visible.allSatisfy { !$0.isFollowing })
    }

    @Test func theListIsSortedByDate() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let dates = model.items.map(\.date)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func loadingMoreAddsOlderYearsWithoutRepeatingAndEnds() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let first = model.items.map(\.id)
        #expect(!model.reachedEnd)
        var turns = 0
        while !model.reachedEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.reachedEnd)
        let ids = model.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(first).isSubset(of: Set(ids)))
    }

    @Test func theListShowsOnePageAtATime() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        try #require(model.items.count > FeedModel.pageSize)
        #expect(model.visible.map(\.id) == model.items.prefix(FeedModel.pageSize).map(\.id))
        let total = model.items.count
        await model.loadMore()
        #expect(model.items.count == total)
        #expect(model.visible.count == min(total, FeedModel.pageSize * 2))
        #expect(!model.isAtEnd)
        model.filter = .following
        model.filter = .all
        #expect(model.visible.count == FeedModel.pageSize)
    }

    @Test func theEndOnlyShowsWhenNothingIsHidden() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        var turns = 0
        while !model.isAtEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.isAtEnd)
        #expect(model.reachedEnd)
        #expect(model.visible.count == model.items.count)
    }

    @Test func theRelevantFilterReadsNoOlderYear() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let total = model.items.count
        model.filter = .relevant
        var turns = 0
        while !model.isAtEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.isAtEnd)
        #expect(!model.reachedEnd)
        #expect(model.items.count == total)
        #expect(model.endMessage.isEmpty == false)
    }

    @Test func aMissingFileIsEmptyAndOnlyFailuresAreMissing() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        for card in [Self.card("a", "Ana"), Self.card("b", "Bia"), Self.card("c", "Caio")] {
            try await repository.follow(card, at: .distantPast)
        }
        let today = CalendarDay(now)
        let service = FollowingService(
            base: ShowcasePublicData(scenario: .normal, now: now),
            votes: ["c": [today.year: [Self.vote("v1", on: today)]]],
            failures: ["a": .notFound, "b": .offline])
        let model = FeedModel(
            service: service, follows: repository,
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { now }, publishesSnapshot: false)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.missing.map(\.slug) == ["b"])
        #expect(model.updates.map(\.person.slug) == ["c"])
        #expect(model.endMessage == model.missingText)
    }

    @Test func inJanuaryTheFirstLoadAlsoReadsThePreviousYear() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await repository.follow(Self.card("c", "Caio"), at: .distantPast)
        let today = try #require(CalendarDay(year: 2_027, month: 1, day: 5))
        let december = try #require(CalendarDay(year: 2_026, month: 12, day: 20))
        let service = FollowingService(
            base: ShowcasePublicData(scenario: .normal, now: now),
            votes: ["c": [2_026: [Self.vote("v2", on: december)]]])
        let clock = today.date()
        let model = FeedModel(
            service: service, follows: repository,
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { clock }, publishesSnapshot: false)
        await model.load()
        #expect(model.missing.isEmpty)
        #expect(model.updates.map(\.day) == [december])
    }

    @Test func followingElsewhereReloadsOnlyWhenTheSetChanged() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        let card = try #require(people.first { $0.slug == "tabata-amaral" })
        let model = FeedModel(
            service: ShowcasePublicData(scenario: .normal, now: now), follows: repository,
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { now }, publishesSnapshot: false)
        await model.load()
        #expect(model.followed.isEmpty)
        await model.followsChanged(to: [])
        #expect(model.followed.isEmpty)
        try await repository.follow(card, at: now)
        await model.followsChanged(to: ["tabata-amaral"])
        #expect(model.followed.map(\.slug) == ["tabata-amaral"])
        #expect(model.items.contains { $0.isFollowing })
    }

    private func raceModel(_ races: RaceScenario? = nil, clock: Date? = nil) -> FeedModel {
        let today = clock ?? now
        return FeedModel(
            service: ShowcasePublicData(scenario: .normal, now: now),
            races: races.map(ShowcaseLiveResults.init(scenario:)), follows: nil,
            raceInterval: .milliseconds(1),
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { today }, publishesSnapshot: false)
    }

    @Test func aLiveRaceTakesTheTop() async {
        let model = raceModel(.close)
        await model.load()
        #expect(model.liveBoard?.race.id == "presidente-br")
        #expect(model.liveBoard?.others == 6)
    }

    @Test func noElectionNoCard() async {
        let finished = raceModel(
            .finished, clock: afterTheResult.addingTimeInterval(FeedRaceBoard.winnerWindow))
        await finished.load()
        #expect(finished.liveBoard == nil)
        await finished.watchRaces()
        let quiet = raceModel()
        await quiet.load()
        #expect(quiet.liveBoard == nil)
    }

    @Test func theWinnerStaysForADayWithoutPolling() async {
        let finished = raceModel(.finished, clock: afterTheResult)
        await finished.load()
        #expect(finished.liveBoard?.race.final == true)
        await finished.watchRaces()
        #expect(finished.liveBoard?.race.final == true)
    }

    @Test func aLostConnectionKeepsTheLastNumbersMarkedAsStale() async {
        let model = raceModel(.offline)
        await model.load()
        #expect(model.liveBoard?.isStale == false)
        await model.refreshRaces()
        #expect(model.racesOffline)
        #expect(model.liveBoard?.isStale == true)
    }

    @Test func theLeadHighlightIsPinnedAndNotRepeated() async throws {
        let model = raceModel()
        await model.load()
        let lead = try #require(model.highlightLead)
        #expect(!model.items.contains { $0.id == "highlight-\(lead.id)" || $0.id == lead.id })
        #expect(model.highlightHeroOverline(lead) == model.highlightHeroOverline(lead).uppercased())
    }

    @Test func aFailureEverywhereReachesTheScreen() async throws {
        let model = try await makeModel(scenario: .unavailable)
        await model.load()
        guard case .failed = model.phase else {
            Issue.record("The failure must reach the screen")
            return
        }
        #expect(model.isEmpty)
    }

    @Test func seeingClearsTheBadge() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        model.markSeen()
        #expect(model.newCount == 0)
    }

    @Test func emptyFilterExplainsWhy() async throws {
        let model = try await makeModel()
        await model.load()
        model.filter = .following
        #expect(model.visible.isEmpty)
        #expect(model.emptyMessage.isEmpty == false)
    }
}
