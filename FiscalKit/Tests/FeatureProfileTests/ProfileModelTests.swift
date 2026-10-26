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
        _ slug: String, lens: (any LensRepository)? = nil,
        follows: (any FollowRepository)? = nil
    ) -> ProfileModel {
        ProfileModel(
            slug: slug, service: showcase, follows: follows, lens: lens, now: { Self.instant })
    }

    @Test func loadsTheProfileWithItsNumbersAndActivity() async {
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
        #expect(model.facts.allSatisfy { !$0.isMissing && $0.source != nil })
        #expect(model.facts.first?.fraction != nil)
        #expect(model.mandateText?.contains("2023") == true)
        #expect(!model.recentVotes.isEmpty)
        #expect(model.recentVotes == model.recentVotes.sorted { $0.date > $1.date })
        #expect(model.lastVoteText != nil)
        #expect(model.recentProposals.count == 3)
        #expect(model.recentSpeeches.count == 2)
        #expect(model.hasExpenses)
        let share = model.categoryLines.map(\.fraction).reduce(0, +)
        #expect(abs(share - 1) < 0.0001)
        #expect(model.monthBars.map(\.month) == model.monthBars.map(\.month).sorted())
        #expect(model.expenseHeadline != nil)
        #expect(model.shareRoute == .share(.person(slug: "tabata-amaral")))
        #expect(model.sourceText(for: ["votes"])?.contains("Câmara dos Deputados") == true)
        #expect(model.sourceText(for: ["assets"])?.contains("Tribunal Superior Eleitoral") == true)
        #expect(!model.showsFactChecks)
    }

    @Test func aStateDeputyWithoutAssemblyDataShowsDashesAndSaysWhy() async {
        let model = makeModel("eduardo-suplicy")
        await model.load()
        let tiles = Dictionary(uniqueKeysWithValues: model.facts.map { ($0.id, $0) })
        #expect(tiles["attendance"]?.value == "—")
        #expect(tiles["attendance"]?.caption != nil)
        #expect(tiles["quota"]?.value == "—")
        #expect(tiles["assets"]?.isMissing == false)
        #expect(model.votes == nil)
        #expect(model.recentVotes.isEmpty)
        #expect(!model.hasExpenses)
        #expect(model.coverageLines.contains { $0.status == .notPublished })
        #expect(!model.assetDeclarations.isEmpty)
        #expect(model.aboutLines.contains { $0.id == "birth" })
        #expect(!model.aboutLines.contains { $0.id == "salary" })
    }

    @Test func theLensPutsItsThemesFirstAndMarksThem() async throws {
        let lens = try FiscalDatabase.open(inMemory: true).repositories.lens
        let probe = makeModel("tabata-amaral")
        await probe.load()
        let dataOrder = probe.themeLines.map(\.theme)
        let last = try #require(dataOrder.last)
        try await lens.save(Lens(themes: [last, .taxes, .economy], supported: ["lula"]))
        let model = makeModel("tabata-amaral", lens: lens)
        await model.load()
        #expect(model.showsLensBadge)
        #expect(model.isLensAdapted)
        #expect(model.themeLines.first?.theme == last)
        #expect(model.themeLines.first?.isLensTheme == true)
        #expect(Set(model.themeLines.map(\.theme)) == Set(dataOrder))
        #expect(model.lensBallots.map(\.count).reduce(0, +) == model.lensVotes.count)
        let themes = model.lensThemes
        #expect(model.lensVotes.allSatisfy { vote in vote.themes.contains { themes.contains($0) } })
    }

    @Test func theImpartialLensKeepsTheDataOrder() async throws {
        let lens = try FiscalDatabase.open(inMemory: true).repositories.lens
        try await lens.save(Lens(prefersNotToSay: true))
        let model = makeModel("kim-kataguiri", lens: lens)
        await model.load()
        let probe = makeModel("kim-kataguiri")
        await probe.load()
        #expect(!model.showsLensBadge)
        #expect(!model.isLensAdapted)
        #expect(model.themeLines.map(\.theme) == probe.themeLines.map(\.theme))
        #expect(model.lensBallots.isEmpty)
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

    @Test func formatsTheSupplierDocument() {
        #expect(ProfileModel.formattedDocument("12345678000190") == "12.345.678/0001-90")
        #expect(ProfileModel.formattedDocument("123") == "123")
    }

    @Test func followsAndUnfollowsOnTheDevice() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = makeModel("kim-kataguiri", follows: follows)
        #expect(!model.canFollow)
        await model.load()
        #expect(model.canFollow)
        #expect(!model.isFollowing)
        await model.toggleFollow()
        #expect(model.isFollowing)
        #expect(try await follows.followed().map(\.card.name) == ["Kim Kataguiri"])
        await model.toggleFollow()
        #expect(!model.isFollowing)
        #expect(try await follows.followed().isEmpty)
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
