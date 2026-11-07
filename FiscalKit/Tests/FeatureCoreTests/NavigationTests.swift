import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
struct NavigationTests {
    @Test func pushesInCompactWidth() {
        let navigation = FiscalNavigation()
        navigation.open(.settings, in: .feed, beside: false)
        #expect(navigation.paths[.feed] == [.settings])
        navigation.close(in: .feed, inspecting: false)
        #expect(navigation.paths[.feed]?.isEmpty == true)
    }

    @Test func opensBesideInRegularWidthAndStacksInside() {
        let navigation = FiscalNavigation()
        navigation.open(.person(slug: "a"), in: .feed, beside: true)
        #expect(navigation.inspector?.route == .person(slug: "a"))
        navigation.open(.person(slug: "b"), in: .feed, beside: true)
        #expect(navigation.inspectorPath == [.person(slug: "b")])
        navigation.close(in: .feed, inspecting: true)
        navigation.close(in: .feed, inspecting: true)
        #expect(navigation.inspector == nil)
    }

    @Test func switchingTabsClosesTheInspectorOfAnotherTab() {
        let navigation = FiscalNavigation()
        navigation.open(.races, in: .feed, beside: true)
        navigation.selectedSection = .votes
        navigation.closeInspectorOutsideSelection()
        #expect(navigation.inspector == nil)
    }

    @Test func eachLikedItemOpensItsOwnScreen() throws {
        let day = try #require(CalendarDay(year: 2026, month: 10, day: 14))
        let likedAt = Date(timeIntervalSince1970: 1)
        let url = try #require(URL(string: "https://projetocomprova.com.br/1"))
        func make(
            _ kind: LikedItem.Kind, voteID: String? = nil, slug: String? = nil, year: Int? = nil,
            highlightID: String? = nil, url: URL? = nil
        ) -> LikedItem {
            LikedItem(
                id: "x", kind: kind, title: "T", day: day, likedAt: likedAt, voteID: voteID,
                expensesSlug: slug, expensesYear: year, highlightID: highlightID, url: url)
        }
        #expect(Route.destination(for: make(.vote, voteID: "v")) == .vote(id: "v"))
        #expect(
            Route.destination(for: make(.expenses, slug: "a", year: 2026))
                == .expenses(slug: "a", year: 2026))
        #expect(Route.destination(for: make(.highlight, highlightID: "h")) == .highlight(id: "h"))
        #expect(
            Route.destination(for: make(.highlight, voteID: "v", highlightID: "h"))
                == .vote(id: "v"))
        #expect(Route.destination(for: make(.check, url: url)) == nil)
        #expect(Route.destination(for: make(.proposal)) == nil)
    }
}
