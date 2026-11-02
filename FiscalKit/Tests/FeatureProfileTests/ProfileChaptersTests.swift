import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureProfile

private struct OnlyPastExpenses: PublicDataService {
    let base: ShowcasePublicData
    let years: [Profile.Year]
    let failing: Bool

    func meta() async throws -> PublicMeta { try await base.meta() }
    func people() async throws -> [PersonCard] { try await base.people() }
    func places() async throws -> [Place] { try await base.places() }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        try await base.representatives(uf: uf)
    }
    func profile(slug: String) async throws -> Profile {
        let profile = try await base.profile(slug: slug)
        let history = profile.history
        return Profile(
            card: profile.card, civilName: profile.civilName, mandate: profile.mandate,
            birthDate: profile.birthDate, birthPlace: profile.birthPlace,
            education: profile.education, contact: profile.contact, salary: profile.salary,
            numbers: profile.numbers,
            history: Profile.History(
                years: years, themes: history.themes, committees: history.committees,
                assets: history.assets, campaigns: history.campaigns, timeline: history.timeline,
                coverage: history.coverage),
            sources: profile.sources)
    }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        if failing { throw PublicDataError.offline }
        return try await base.votes(slug: slug, year: year)
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        try await base.proposals(slug: slug, year: year)
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        try await base.speeches(slug: slug, year: year)
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        try await base.expenses(slug: slug, year: year)
    }
    func checks(slug: String) async throws -> FactCheckList? { try await base.checks(slug: slug) }
    func recentVotes() async throws -> [VoteSummary] { try await base.recentVotes() }
    func vote(id: String) async throws -> VoteDetail { try await base.vote(id: id) }
    func agenda() async throws -> Agenda { try await base.agenda() }
    func money() async throws -> MoneyOverview { try await base.money() }
    func today() async throws -> TodayDigest { try await base.today() }
}

@MainActor
struct ProfileChaptersTests {
    nonisolated private static let instant = Date(timeIntervalSince1970: 1_792_917_720)
    private let showcase = ShowcasePublicData(scenario: .normal, now: instant)

    private func loaded(_ slug: String) async -> ProfileModel {
        let model = ProfileModel(slug: slug, service: showcase, now: { Self.instant })
        await model.load()
        return model
    }

    private static func year(_ year: Int, quota: Int?) -> Profile.Year {
        Profile.Year(
            year: year, present: nil, eligible: nil, proposals: nil, laws: nil, speeches: nil,
            votes: nil, quotaCents: quota)
    }

    @Test func aFederalDeputyReadsEveryChapterInTheFixedOrder() async {
        let model = await loaded("tabata-amaral")
        #expect(model.chapters.first == .votes)
        #expect(
            model.chapters
                == ProfileChapter.allCases.filter { model.chapters.contains($0) })
        #expect(
            Set(model.chapters).isSuperset(of: [.votes, .proposals, .money, .origin, .about]))
        #expect(model.facts.allSatisfy { $0.value != PublicFormat.missing })
    }

    @Test func aGovernorHasNoCongressChaptersAndNoContextChapter() async {
        let model = await loaded("tarcisio-de-freitas")
        #expect(model.chapters.first == .origin)
        #expect(model.chapters.contains(.about))
        #expect(ProfileChapter.order(for: .governor) == [.origin, .checks, .about])
        for chapter in [ProfileChapter.votes, .proposals, .money] {
            #expect(!model.chapters.contains(chapter))
        }
        #expect(!model.gaps.isEmpty)
    }

    @Test func theOrderDependsOnTheOfficeNotOnTheValues() async {
        let first = await loaded("tabata-amaral")
        let second = await loaded("kim-kataguiri")
        for model in [first, second] {
            #expect(
                model.chapters
                    == ProfileChapter.order(for: .federalDeputy).filter(model.chapters.contains))
        }
        #expect(ProfileChapter.order(for: .governor) == ProfileChapter.order(for: .mayor))
        #expect(
            ProfileChapter.order(for: .senator) == ProfileChapter.order(for: .cityCouncilor))
    }

    @Test func aChapterWithoutDataDoesNotExist() async {
        let model = await loaded("eduardo-suplicy")
        #expect(!model.chapters.contains(.votes))
        #expect(!model.chapters.contains(.money))
        #expect(model.chapters.contains(.origin))
    }

    @Test func theSummaryShowsAtMostFourPublishedFactsWithTheirChapter() async {
        let deputy = await loaded("tabata-amaral")
        #expect(deputy.summary.count == ProfileModel.summaryLimit)
        #expect(deputy.summary.map(\.id) == ["attendance", "proposals", "quota", "election"])
        #expect(deputy.summary.map(\.chapter) == [.votes, .proposals, .money, .origin])
        #expect(deputy.summary.allSatisfy { $0.source != nil })
        let governor = await loaded("tarcisio-de-freitas")
        #expect(governor.summary.allSatisfy { $0.chapter == .origin })
        #expect(governor.summary.count <= ProfileModel.summaryLimit)
    }

    @Test func withoutTheProfileThereIsNothingToShow() {
        let model = ProfileModel(slug: "tabata-amaral", service: showcase, now: { Self.instant })
        #expect(model.chapters.isEmpty)
        #expect(model.summary.isEmpty)
        #expect(model.gaps.isEmpty)
    }

    @Test func aFailedSourceKeepsTheRestAndOffersAnotherTry() async {
        let service = OnlyPastExpenses(
            base: showcase, years: [Self.year(2026, quota: 100)], failing: true)
        let model = ProfileModel(slug: "tabata-amaral", service: service, now: { Self.instant })
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.hasFailedSource)
        #expect(model.recentVotes.isEmpty)
        #expect(model.chapters.contains(.money))
    }

    @Test func theSpendingStartsAtTheLatestYearWithExpensesAndCanChange() async {
        let service = OnlyPastExpenses(
            base: showcase, years: [Self.year(2025, quota: 200), Self.year(2026, quota: nil)],
            failing: false)
        let model = ProfileModel(slug: "tabata-amaral", service: service, now: { Self.instant })
        await model.load()
        #expect(model.expenseYear == 2025)
        #expect(model.expenseYears == [2025])
        #expect(model.yearText == "2025")
        #expect(!model.hasFailedSource)
        await model.selectExpenseYear(2024)
        #expect(model.expenseYear == 2024)
        #expect(model.expenses?.items.allSatisfy { $0.year == 2024 } == true)
    }

    @Test func everyExpenseOpensTheFullListOfTheSelectedYear() async {
        let service = OnlyPastExpenses(
            base: showcase, years: [Self.year(2025, quota: 200)], failing: false)
        let model = ProfileModel(slug: "tabata-amaral", service: service, now: { Self.instant })
        await model.load()
        #expect(model.expensesRoute == .expenses(slug: "tabata-amaral", year: 2025))
        await model.selectExpenseYear(2024)
        #expect(model.expensesRoute == .expenses(slug: "tabata-amaral", year: 2024))
    }

    @Test func checksComeByDateWithoutCountOrVerdictOrderAndOnlyWhenThereAreAny() async {
        let model = await loaded("lula")
        let dates = model.checkItems.map(\.date)
        #expect(!dates.isEmpty)
        #expect(dates == dates.sorted(by: >))
        #expect(model.chapters.contains(.checks))
        #expect(model.title(of: .checks).contains("Lula"))
        #expect(model.checksSourceText != nil)
        let credit = model.checkItems.first.map(model.checkCredit)
        #expect(credit == "Projeto Comprova · CC BY-ND 4.0")
        let none = await loaded("eduardo-suplicy")
        #expect(none.checkItems.isEmpty)
        #expect(!none.chapters.contains(.checks))
    }
}

struct ProfilePortraitChoreographyTests {
    @Test func everyChapterHasOneFixedGesture() {
        let gestures = ProfileChapter.allCases.map(ProfilePortraitChoreography.gesture)
        #expect(
            gestures == [.tilt, .browRaise, .lookAround, .settle, .doubleBlink, .tilt])
    }

    @Test func neighbourChaptersPlayDifferentGestures() {
        let gestures = ProfileChapter.allCases.map(ProfilePortraitChoreography.gesture)
        for (left, right) in zip(gestures, gestures.dropFirst()) {
            #expect(left != right)
        }
        let executive = ProfileChapter.order(for: .governor).map(
            ProfilePortraitChoreography.gesture)
        for (left, right) in zip(executive, executive.dropFirst()) {
            #expect(left != right)
        }
    }
}
