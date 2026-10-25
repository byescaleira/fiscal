import Testing

@testable import FeatureCore

@MainActor
struct NavigationTests {
    @Test func pushesInCompactWidth() {
        let navigation = FiscalNavigation()
        navigation.open(.settings, in: .today, beside: false)
        #expect(navigation.paths[.today] == [.settings])
        navigation.close(in: .today, inspecting: false)
        #expect(navigation.paths[.today]?.isEmpty == true)
    }

    @Test func opensBesideInRegularWidthAndStacksInside() {
        let navigation = FiscalNavigation()
        navigation.open(.person(slug: "a"), in: .today, beside: true)
        #expect(navigation.inspector?.route == .person(slug: "a"))
        navigation.open(.person(slug: "b"), in: .today, beside: true)
        #expect(navigation.inspectorPath == [.person(slug: "b")])
        navigation.close(in: .today, inspecting: true)
        navigation.close(in: .today, inspecting: true)
        #expect(navigation.inspector == nil)
    }

    @Test func switchingTabsClosesTheInspectorOfAnotherTab() {
        let navigation = FiscalNavigation()
        navigation.open(.races, in: .today, beside: true)
        navigation.selectedSection = .votes
        navigation.closeInspectorOutsideSelection()
        #expect(navigation.inspector == nil)
    }
}
