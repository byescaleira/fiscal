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
}
