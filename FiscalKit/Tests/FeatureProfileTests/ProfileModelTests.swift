import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureProfile

@MainActor
struct ProfileModelTests {
    nonisolated private static let instant = Date(timeIntervalSince1970: 1_792_917_720)
    private let showcase = ShowcasePublicData(scenario: .normal, now: instant)

    private func makeModel(
        _ slug: String, follows: (any FollowRepository)? = nil
    ) -> ProfileModel {
        ProfileModel(slug: slug, service: showcase, follows: follows, now: { Self.instant })
    }

    @Test func aProposalOpensItsContentWithoutRepeatingTheAuthor() async throws {
        let model = makeModel("tabata-amaral")
        await model.load()
        let proposal = try #require(model.recentProposals.first)
        guard case .content(let content) = model.proposalRoute(proposal) else {
            Issue.record("A proposal must open the content")
            return
        }
        #expect(content.id == proposal.id)
        #expect(content.officialSummary != nil || proposal.plainSummary == nil)
        #expect(content.effect == model.proposalStatus(proposal))
        #expect(content.stage == nil)
        #expect(content.person == nil)
    }

    @Test func anActionOpensTheVoteOrTheContent() async throws {
        let model = makeModel("tabata-amaral")
        let vote = Self.action(kind: .vote, ref: "camara-1")
        #expect(model.actionRoute(vote) == .vote(id: "camara-1"))
        for item in [
            Self.action(kind: .proposal, ref: nil), Self.action(kind: .speech, ref: nil),
            Self.action(kind: .vote, ref: nil),
        ] {
            guard case .content(let content) = model.actionRoute(item) else {
                Issue.record("Without a vote to open, the action must open the content")
                continue
            }
            #expect(content.id == item.id)
            #expect(content.person == nil)
        }
    }

    private static func action(kind: ActionItem.Kind, ref: String?) -> ActionItem {
        ActionItem(
            id: "1", kind: kind, title: "Fato", proposition: "PL 1/2026",
            date: CalendarDay(instant),
            url: nil, ref: ref, ballot: nil, stage: nil, themes: [], weight: 50, repercussion: nil,
            impact: 50, signals: .none)
    }

    @Test func loadsTheProfileWithItsNumbersAndActivity() async throws {
        let model = makeModel("tabata-amaral")
        #expect(model.isEmpty)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.title == "Tabata Amaral")
        #expect(model.officeLine.hasSuffix("· SP"))
        #expect(model.subtitle?.contains("PSB") == true)
        #expect(
            model.facts.map(\.id) == [
                "attendance", "proposals", "laws", "speeches", "votes", "quota", "assets",
                "campaign", "election",
            ])
        #expect(model.facts.allSatisfy { $0.value != PublicFormat.missing && $0.source != nil })
        #expect(model.facts.first?.fraction != nil)
        #expect(model.mandateText?.contains("2023") == true)
        #expect(!model.recentVotes.isEmpty)
        #expect(model.recentVotes == model.recentVotes.sorted { $0.date > $1.date })
        #expect(model.recentProposals.count == 3)
        #expect(model.recentSpeeches.count == 2)
        #expect(model.hasExpenses)
        let share = model.categoryLines.map(\.fraction).reduce(0, +)
        #expect(abs(share - 1) < 0.0001)
        #expect(model.monthBars.map(\.month) == Array(1...12))
        #expect(model.expenseHeadline != nil)
        let peak = try #require(model.monthBars.first { $0.month == model.highlightedMonth })
        #expect(model.monthBars.allSatisfy { $0.cents <= peak.cents })
        let average = try #require(model.monthAverageReais)
        #expect(average > 0 && average <= peak.reais)
        #expect(model.expensesSectionTitle.contains(model.yearText))
        #expect(model.shareRoute == .share(.person(slug: "tabata-amaral")))
        #expect(model.sourceText(for: ["votes"])?.contains("Câmara dos Deputados") == true)
        #expect(model.sourceText(for: ["assets"])?.contains("Tribunal Superior Eleitoral") == true)
    }

    @Test func aStateDeputyWithoutAssemblyDataShowsNoDashAndSaysWhy() async {
        let model = makeModel("eduardo-suplicy")
        await model.load()
        let tiles = Dictionary(uniqueKeysWithValues: model.facts.map { ($0.id, $0) })
        #expect(tiles["attendance"] == nil)
        #expect(tiles["quota"] == nil)
        #expect(tiles["assets"] != nil)
        #expect(model.votes == nil)
        #expect(model.recentVotes.isEmpty)
        #expect(!model.hasExpenses)
        #expect(model.gaps.count == 1)
        #expect(!model.assetDeclarations.isEmpty)
        #expect(model.aboutLines.contains { $0.id == "birth" })
        #expect(!model.aboutLines.contains { $0.id == "salary" })
    }

    @Test func theThemesComeByHowManyActionsTheyHave() async throws {
        let model = makeModel("tabata-amaral")
        await model.load()
        let profile = try #require(model.profile)
        let actions = model.themeLines.map(\.actions)
        #expect(!actions.isEmpty)
        #expect(actions == actions.sorted(by: >))
        #expect(Set(model.themeLines.map(\.theme)) == Set(profile.themes.map(\.key)))
    }

    @Test func readsEveryBallot() {
        #expect(ProfileBallot("Sim") == .yes)
        #expect(ProfileBallot(" NÃO ") == .no)
        #expect(ProfileBallot("Abstenção") == .abstention)
        #expect(ProfileBallot("Ausente") == .absent)
        #expect(ProfileBallot("Obstrução") == .other("Obstrução"))
        #expect(
            ProfileBallot.tallied.map(\.symbol) == ["checkmark", "xmark", "minus", "circle.dashed"])
    }

    @Test func followsThroughTheWindowController() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = makeModel("kim-kataguiri", follows: follows)
        #expect(!model.canFollow)
        #expect(model.followCard == nil)
        await model.load()
        #expect(model.canFollow)
        let card = try #require(model.followCard)
        let follow = FollowController(follows: follows, widget: { _ in })
        model.followChanged(to: await follow.toggle(card))
        #expect(model.hasJustFollowed)
        #expect(try await follows.followed().map(\.card.name) == ["Kim Kataguiri"])
        model.followChanged(to: await follow.toggle(card))
        #expect(!model.hasJustFollowed)
        #expect(try await follows.followed().isEmpty)
    }

    @Test func cannotFollowWithoutTheDatabase() async {
        let model = makeModel("kim-kataguiri")
        await model.load()
        #expect(!model.canFollow)
        #expect(model.followCard == nil)
    }

    @Test func aMissingProfileSaysSo() async {
        let model = makeModel("nobody")
        await model.load()
        #expect(model.phase == .failed(.notFound))
        #expect(model.isEmpty)
        #expect(model.facts.isEmpty)
        #expect(model.shareRoute == nil)
    }

    @Test func offlineFailsWithTheReason() async {
        let model = ProfileModel(
            slug: "tabata-amaral",
            service: ShowcasePublicData(scenario: .offline, now: Self.instant))
        await model.load()
        #expect(model.phase == .failed(.offline))
    }
}
