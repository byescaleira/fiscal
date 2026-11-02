import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSupport

@MainActor
struct SupportEditorModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeEditor() async throws -> (
        SupportEditorModel, SupportContext, any FollowRepository
    ) {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let context = SupportContext(repository: repositories.support)
        await context.load()
        let editor = SupportEditorModel(
            context: context, service: ShowcasePublicData(scenario: .normal, now: now),
            follows: repositories.follows)
        await editor.load()
        return (editor, context, repositories.follows)
    }

    @Test func searchFindsPeopleWithoutAccentsAndHidesWhoIsChosen() async throws {
        let (editor, _, _) = try await makeEditor()
        let card = try #require(editor.people.first)
        editor.query = card.name
        #expect(editor.results.contains(card))
        editor.toggle(card)
        #expect(!editor.results.contains(card))
        #expect(editor.chosen == [card])
    }

    @Test func savingFollowsWhoWasAddedAndRemovingKeepsFollowing() async throws {
        let (editor, context, follows) = try await makeEditor()
        let card = try #require(editor.people.first)
        editor.toggle(card)
        editor.toggle(.health)
        await editor.save()
        #expect(editor.isFinished)
        #expect(context.choice.people == [card.slug])
        #expect(context.choice.causes == [.health])
        #expect(try await follows.isFollowing(slug: card.slug))

        editor.toggle(card)
        await editor.save()
        #expect(context.choice.people.isEmpty)
        #expect(try await follows.isFollowing(slug: card.slug))
    }

    @Test func theSixthCauseIsDisabled() async throws {
        let (editor, _, _) = try await makeEditor()
        let causes = Array(editor.causes.prefix(SupportChoice.causeLimit))
        for cause in causes { editor.toggle(cause) }
        let other = try #require(editor.causes.first { !causes.contains($0) })
        #expect(!editor.canToggle(other))
        #expect(editor.canToggle(causes[0]))
    }
}
