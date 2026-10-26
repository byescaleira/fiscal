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

    @Test func theModeFollowsTheLens() {
        #expect(TodayBriefing.mode(for: nil) == .plain)
        #expect(TodayBriefing.mode(for: Lens(supported: ["lula"])) == .plain)
        #expect(
            TodayBriefing.mode(for: Lens(themes: [.health], supported: ["lula"]))
                == .themes([.health]))
        #expect(
            TodayBriefing.mode(for: Lens(themes: [.health], prefersNotToSay: true))
                == .themes([.health]))
    }
}
