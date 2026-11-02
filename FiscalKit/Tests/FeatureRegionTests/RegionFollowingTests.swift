import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureRegion

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RegionFollowingTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        code: String? = nil, follows: (any FollowRepository)?,
        service: (any PublicDataService)? = nil
    ) throws -> RegionModel {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = RegionPlaceMemory(defaults: defaults)
        memory.code = code
        return RegionModel(
            service: service ?? ShowcasePublicData(scenario: .normal, now: now), follows: follows,
            memory: memory)
    }

    private static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    @Test func aRegionalHighlightOpensItsContentWithoutShare() throws {
        let model = try makeModel(follows: nil)
        let highlight = Highlight(
            id: "action-1", kind: .action, title: "Fato", subtitle: "", weight: 60,
            repercussion: nil, impact: 60, route: "a", person: Self.card("a", "Ana"),
            proposition: nil, date: CalendarDay(Date(timeIntervalSince1970: 1_792_917_720)),
            url: nil, signals: .none)
        guard case .content(let content) = model.route(for: highlight) else {
            Issue.record("A regional highlight must open the content")
            return
        }
        #expect(content.person?.slug == "a")
        #expect(content.shareHighlightID == nil)
    }

    @Test func aSeatWithoutViceOrElectedStandsAlone() {
        let holder = Self.card("a", "Ana")
        let vice = Self.card("b", "Bia")
        #expect(
            RegionSeat(level: .city, place: "SP", holder: holder, vice: nil, elected: [])
                .standsAlone)
        #expect(
            !RegionSeat(level: .city, place: "SP", holder: holder, vice: vice, elected: [])
                .standsAlone)
        #expect(
            !RegionSeat(level: .country, place: "BR", holder: holder, vice: nil, elected: [vice])
                .standsAlone)
    }

    @Test func suggestsRepresentativesNotFollowed() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(code: "sp", follows: follows)
        await model.load()
        let first = try #require(model.suggestions.first)
        #expect(model.suggestions.count <= RegionModel.suggestionLimit)
        let ranks = model.suggestions.map { RegionModel.rank($0.office) }
        #expect(ranks == ranks.sorted())
        try await follows.follow(first, at: now)
        await model.load()
        #expect(!model.suggestions.map(\.slug).contains(first.slug))
        #expect(Set(model.suggestions.map(\.slug)).count == model.suggestions.count)
    }

    @Test func invitesToShareOnlyAfterTheFirstFollowUntilDismissed() async throws {
        let invites = "invite-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: invites) }
        let inviteDefaults = try #require(UserDefaults(suiteName: invites))
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let memory = RegionPlaceMemory(
            defaults: try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)")))
        let make = {
            RegionModel(
                service: ShowcasePublicData(scenario: .normal, now: self.now), follows: follows,
                memory: memory, inviteDefaults: inviteDefaults)
        }
        let model = make()
        await model.load()
        #expect(!model.showsFollowingInvite)
        try await follows.follow(Self.card("c", "Caio"), at: now)
        await model.load()
        #expect(model.showsFollowingInvite)
        #expect(model.followingInviteRoute == .share(.following))
        model.dismissFollowingInvite()
        #expect(!model.showsFollowingInvite)
        #expect(inviteDefaults.bool(forKey: RegionModel.followingInviteKey))
        let reopened = make()
        await reopened.load()
        #expect(!reopened.followed.isEmpty)
        #expect(!reopened.showsFollowingInvite)
    }
}
