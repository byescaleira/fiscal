import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSupport

@MainActor
struct SupportModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        _ choice: SupportChoice?, scenario: PublicDataScenario = .normal
    ) async -> (SupportModel, SupportContext) {
        let context = SupportContext(repository: ShowcaseSupportRepository(support: choice))
        let model = SupportModel(
            context: context, service: ShowcasePublicData(scenario: scenario, now: now),
            follows: nil, now: { now })
        await model.load()
        return (model, context)
    }

    @Test func withoutAChoiceThereIsNoTimeline() async {
        let (model, _) = await makeModel(nil)
        #expect(!model.hasChoice)
        #expect(model.events.isEmpty)
        #expect(model.phase == .loaded)
    }

    @Test func aPersonBringsDatedFactsNewestFirst() async {
        let (model, _) = await makeModel(SupportChoice(people: ["tabata-amaral"]))
        #expect(model.phase == .loaded)
        #expect(!model.events.isEmpty)
        #expect(model.events == model.events.sorted { $0.date >= $1.date || $0.date == $1.date })
        #expect(model.sections.flatMap(\.events) == model.visible)
    }

    @Test func aCauseBringsOnlyEventsWithThatTheme() async {
        let (model, _) = await makeModel(SupportChoice(causes: [.health]))
        #expect(model.events.allSatisfy { $0.themes.contains(.health) })
    }

    @Test func anEmptyFilterExplainsWhy() async {
        let (model, _) = await makeModel(SupportChoice(causes: [.tributes]))
        model.filter = .cause(.tributes)
        if model.visible.isEmpty {
            #expect(model.emptyMessage.contains(Theme.tributes.title))
        }
    }

    @Test func aFilterForSomeoneRemovedGoesBackToAll() async {
        let (model, context) = await makeModel(SupportChoice(people: ["tabata-amaral"]))
        model.filter = .person("tabata-amaral")
        await context.save(SupportChoice())
        await model.load()
        #expect(model.filter == .all)
        #expect(model.events.isEmpty)
    }

    @Test func anOfficeWithoutVotesSaysSo() async throws {
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        let governor = try #require(people.first { !$0.office.publishesVotes })
        let (model, _) = await makeModel(SupportChoice(people: [governor.slug]))
        model.filter = .person(governor.slug)
        #expect(model.phase == .loaded)
        #expect(model.votesNote?.contains(governor.officeTitle) == true)
        let deputy = try #require(people.first { $0.office.publishesVotes })
        let (other, _) = await makeModel(SupportChoice(people: [deputy.slug]))
        other.filter = .person(deputy.slug)
        #expect(other.votesNote == nil)
    }

    @Test func withoutTheSourcesTheFailureIsKept() async {
        let (model, _) = await makeModel(
            SupportChoice(people: ["tabata-amaral"]), scenario: .unavailable)
        if case .failed = model.phase {
            #expect(model.events.isEmpty)
        } else {
            Issue.record("The failure must reach the screen")
        }
    }

    @Test func erasingClearsTheChoice() async {
        let (model, context) = await makeModel(SupportChoice(causes: [.health]))
        model.isConfirmingErase = true
        await model.erase()
        #expect(!model.isConfirmingErase)
        #expect(context.choice.isEmpty)
        #expect(model.events.isEmpty)
    }

    @Test func aLineOfVoteOpensTheVoteAndTheRestTheContent() {
        let day = CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))
        let vote = SupportEvent(id: "vote-1", kind: .vote, date: day, title: "Fato", voteID: "1")
        #expect(Route.destination(for: vote) == .vote(id: "1"))
        let content = ContentDetail(id: "1", kind: .proposal, title: "Fato")
        let proposal = SupportEvent(
            id: "action-1", kind: .proposal, date: day, title: "Fato", content: content)
        #expect(Route.destination(for: proposal) == .content(content))
    }
}
