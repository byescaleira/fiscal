import Foundation
import Testing

@testable import FeatureCore

@MainActor
struct RevealPageStateTests {
    @Test func theCurrentChapterIsTheLastOnePastTheLine() {
        let order: [AnyHashable] = ["votes", "proposals", "money"]
        #expect(RevealPageState.chapter(in: order, tops: [:], line: 100) == nil)
        #expect(RevealPageState.chapter(in: order, tops: ["votes": 150], line: 100) == nil)
        #expect(
            RevealPageState.chapter(
                in: order, tops: ["votes": 40, "proposals": 100, "money": 400], line: 100)
                == AnyHashable("proposals"))
    }

    @Test func theBarAppearsOnlyAfterTheHeroLeavesAndKnowsWhereAChapterIs() {
        let state = RevealPageState()
        state.order = ["votes"]
        state.headerHeight = 100
        state.move(pageTop: 50)
        state.move(heroBottom: 400)
        #expect(!state.showsBar)
        state.move(heroBottom: 140)
        #expect(state.showsBar)
        state.move(heroBottom: 400)
        #expect(!state.showsBar)
        state.offset = 200
        #expect(state.target(of: "votes") == nil)
        state.move(chapter: "votes", top: 600)
        let line = 50 + 100 + CGFloat.spaceL
        #expect(state.target(of: "votes") == 200 + 600 - line)
        #expect(state.current == nil)
        state.move(chapter: "votes", top: line)
        #expect(state.current == AnyHashable("votes"))
    }
}
