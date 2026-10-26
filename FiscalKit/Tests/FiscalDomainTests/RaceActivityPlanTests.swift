import Foundation
import Testing

@testable import FiscalDomain

struct RaceActivityPlanTests {
    private let now = Date(timeIntervalSince1970: 1_792_962_000)

    @Test func keepsWhenNothingChanged() {
        let race = RaceScenario.close.races()[0]
        let current = RaceActivityState(race: race, now: now)
        #expect(RaceActivityPlan.next(current: current, race: race, now: now) == .keep)
    }

    @Test func updatesWhileCounting() {
        let before = RaceActivityState(race: RaceScenario.progressing.races(step: 2)[0], now: now)
        let race = RaceScenario.progressing.races(step: 3)[0]
        #expect(
            RaceActivityPlan.next(current: before, race: race, now: now)
                == .update(RaceActivityState(race: race, now: now)))
    }

    @Test func endsWhenTheRaceIsFinal() {
        let before = RaceActivityState(race: RaceScenario.close.races()[0], now: now)
        let race = RaceScenario.finished.races()[0]
        #expect(
            RaceActivityPlan.next(current: before, race: race, now: now)
                == .end(RaceActivityState(race: race, now: now), dismissAfter: 14_400))
    }

    @Test func neverGoesBackToOlderNumbers() {
        let race = RaceScenario.close.races()[0]
        let newer = RaceActivityState(
            sectionsPercent: 99, candidates: [], final: false,
            updatedAt: (race.generatedAt ?? now).timeIntervalSince1970 + 60)
        #expect(RaceActivityPlan.next(current: newer, race: race, now: now) == .keep)
    }

    @Test func givesThePresidentMoreRelevance() {
        #expect(
            RaceActivityPlan.relevance(for: .president) > RaceActivityPlan.relevance(for: .governor)
        )
    }
}
