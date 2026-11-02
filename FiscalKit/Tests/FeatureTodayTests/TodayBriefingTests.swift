import FiscalDomain
import Testing

@testable import FeatureToday

struct TodayBriefingTests {
    private func event(_ kind: TodayDigest.Event.Kind, _ title: String) -> TodayDigest.Event {
        TodayDigest.Event(kind: kind, title: title, summary: "", themes: [], ref: nil)
    }

    @Test func theOrderIsTheDataOrder() {
        let events = [event(.session, "a"), event(.race, "b"), event(.vote, "c"), event(.law, "d")]
        #expect(TodayBriefing.events(events, hidesRaces: false) == events)
    }

    @Test func aLiveBoardOnlyTakesTheRaceOut() {
        let events = [event(.session, "a"), event(.race, "b"), event(.vote, "c")]
        #expect(
            TodayBriefing.events(events, hidesRaces: true) == [
                event(.session, "a"), event(.vote, "c"),
            ])
    }
}
