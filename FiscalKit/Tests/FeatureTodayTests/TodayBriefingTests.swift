import FiscalDomain
import Testing

@testable import FeatureToday

struct TodayBriefingTests {
    private let topics: [[Theme]] = [
        [.taxes], [.environment], [.education], [.security], [.social], [.tributes],
    ]

    @Test func withoutALensTheOrderIsTheDataOrder() {
        let ordered = TodayBriefing.order(topics, mode: .plain, themes: { $0 })
        #expect(ordered.map(\.offset) == [0, 1, 2, 3, 4, 5])
        #expect(ordered.allSatisfy { !$0.isLensPick })
    }

    @Test func chosenTopicsComeFirstAndOnlyPromotedItemsAreMarked() {
        let ordered = TodayBriefing.order(
            topics, mode: .themes([.education, .taxes]), themes: { $0 })
        #expect(ordered.map(\.offset) == [2, 0, 1, 3, 4, 5])
        #expect(ordered.map(\.isLensPick) == [true, false, false, false, false, false])
        #expect(ordered.count == topics.count)
    }

    @Test func impartialTakesTurnsBetweenBothSides() {
        let ordered = TodayBriefing.order(topics, mode: .alternating, themes: { $0 })
        #expect(ordered.map(\.offset) == [0, 4, 3, 1, 2, 5])
        #expect(ordered.map(\.isLensPick) == [false, true, true, false, false, false])
        #expect(Set(ordered.map(\.offset)) == Set(topics.indices))
    }

    @Test func impartialKeepsGoingWhenOneSideRunsOut() {
        let lopsided: [[Theme]] = [[.tributes], [.taxes], [.security], [.health]]
        let ordered = TodayBriefing.order(lopsided, mode: .alternating, themes: { $0 })
        #expect(ordered.map(\.offset) == [1, 3, 2, 0])
    }

    @Test func theModeFollowsTheLens() {
        #expect(TodayBriefing.mode(for: nil) == .plain)
        #expect(TodayBriefing.mode(for: Lens(stance: .left)) == .plain)
        #expect(
            TodayBriefing.mode(for: Lens(themes: [.health], stance: .right))
                == .themes([.health]))
        #expect(
            TodayBriefing.mode(for: Lens(themes: [.health], stance: .impartial)) == .alternating)
        #expect(TodayBriefing.mode(for: Lens(stance: .preferNotToSay)) == .alternating)
    }

    @Test func bothSidesGetTheSameNumberOfTopics() {
        #expect(TodayBriefing.audiences.count == 2)
        #expect(TodayBriefing.audiences[0].count == TodayBriefing.audiences[1].count)
        #expect(Set(TodayBriefing.audiences[0]).isDisjoint(with: TodayBriefing.audiences[1]))
    }
}
