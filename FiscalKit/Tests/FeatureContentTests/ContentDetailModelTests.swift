import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureContent

@MainActor
struct ContentDetailModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private var service: ShowcasePublicData { ShowcasePublicData(scenario: .normal, now: now) }

    private let person = PersonCard(
        slug: "a", name: "Ana", office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
        status: .inOffice)

    private var action: Highlight {
        Highlight(
            id: "action-1", kind: .action, title: "Fato", subtitle: "PL 1/2026", weight: 60,
            repercussion: nil, impact: 60, route: "a", person: person, proposition: "PL 1/2026",
            date: CalendarDay(Date(timeIntervalSince1970: 1_792_917_720)), url: nil, signals: .none)
    }

    private func firstHighlight() async throws -> (Highlight, HighlightList) {
        let list = try #require(try await service.highlights())
        return (try #require(list.items.first), list)
    }

    @Test func showsOnlyTheFactsThatExist() {
        let model = ContentDetailModel(
            content: ContentDetail(id: "1", kind: .proposal, title: "Fato", reference: "PL 1/2026"))
        #expect(model.facts.map(\.value) == ["PL 1/2026"])
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
    }

    @Test func factsPairUpAndALeftoverTakesTheWholeRow() {
        let model = ContentDetailModel(
            content: ContentDetail(
                id: "1", kind: .proposal, title: "Fato", reference: "PL 1/2026", stage: "Etapa",
                date: CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))))
        #expect(model.factRows.map(\.count) == [2, 1])
    }

    @Test func aDayEntersTheFacts() {
        let day = CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))
        let model = ContentDetailModel(
            content: ContentDetail(id: "1", kind: .proposal, title: "Fato", date: day))
        #expect(model.kicker == ContentDetail.Kind.proposal.title.uppercased(with: .app))
        #expect(model.facts.map(\.value) == [SourceFootnote.day(day)])
    }

    @Test func withoutAPersonOrShareThereIsNoButton() {
        let model = ContentDetailModel(
            content: ContentDetail(id: "1", kind: .speech, title: "Fato"))
        #expect(model.authorRoute == nil)
        #expect(model.shareRoute == nil)
    }

    @Test func aHighlightOpensItsAuthorAndItsShare() {
        let model = ContentDetailModel(
            content: ContentDetail(
                highlight: action, method: nil, sourceLine: nil, shareHighlightID: action.id))
        #expect(model.authorRoute == .person(slug: "a"))
        #expect(model.shareRoute == .share(.highlight(id: "action-1")))
    }

    @Test func aWidgetLinkFindsTheHighlight() async throws {
        let (item, list) = try await firstHighlight()
        let model = ContentDetailModel(highlightID: item.id, service: service)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.content?.title == item.title)
        #expect(model.content?.method == list.method)
        #expect(model.shareRoute == .share(.highlight(id: item.id)))
    }

    @Test func aHighlightThatLeftTheListIsEmptyNotAnError() async {
        let model = ContentDetailModel(highlightID: "action-gone", service: service)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
    }

    @Test func noHighlightsAtAllIsEmptyToo() async {
        let empty = ShowcasePublicData(scenario: .empty, now: now)
        let model = ContentDetailModel(highlightID: "action-1", service: empty)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
    }

    @Test func aFailureIsKeptForTheRetry() async {
        let down = ShowcasePublicData(scenario: .unavailable, now: now)
        let model = ContentDetailModel(highlightID: "action-1", service: down)
        await model.load()
        guard case .failed = model.phase else {
            Issue.record("The failure must reach the screen")
            return
        }
        #expect(model.isEmpty)
    }

    @Test func routesSendVotesToTheVoteAndEverythingElseToTheContent() async throws {
        guard case .content(let content) = Route.destination(for: action, method: nil) else {
            Issue.record("An action must open the content")
            return
        }
        #expect(content.id == action.id)
        #expect(content.shareHighlightID == nil)
        guard
            case .content(let shareable) = Route.destination(
                for: action, method: nil, isShareable: true)
        else {
            Issue.record("An action must open the content")
            return
        }
        #expect(shareable.shareHighlightID == action.id)
        let (vote, _) = try await firstHighlight()
        #expect(Route.destination(for: vote, method: nil) == .vote(id: vote.route))
    }
}
