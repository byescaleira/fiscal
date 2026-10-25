import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

@MainActor
struct TodayModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    @Test func loadsTheDigestOfTheDay() async {
        let model = TodayModel(service: ShowcasePublicData(scenario: .normal, now: now))
        #expect(model.phase == .idle)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
        #expect(model.events.first?.kind == .vote)
        #expect(!model.sources.isEmpty)
    }

    @Test func theLensOrdersTheDayWithoutHidingAnything() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(Lens(themes: [.education, .politics, .health]))
        let model = TodayModel(
            service: ShowcasePublicData(scenario: .normal, now: now), lens: repositories.lens)
        await model.load()
        let kinds = model.events.map(\.kind)
        #expect(kinds == [.session, .race, .vote, .vote])
        #expect(model.lens?.themes.first == .education)
    }

    @Test func anEmptyDayIsHonest() async {
        let model = TodayModel(service: ShowcasePublicData(scenario: .empty, now: now))
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
    }

    @Test func reportsWhyTheDayDidNotLoad() async {
        let offline = TodayModel(service: ShowcasePublicData(scenario: .offline, now: now))
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        let missing = TodayModel(service: nil)
        await missing.load()
        #expect(missing.phase.error == .unavailable)
    }
}
