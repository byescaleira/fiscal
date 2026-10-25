import Testing

@testable import FeatureCore

@MainActor
struct NavigationTests {
    @Test func pushesInCompactWidth() {
        let navigation = FiscalNavigation()
        navigation.open(.races, in: .today, beside: false)
        #expect(navigation.paths[.today] == [.races])
        navigation.close(in: .today, inspecting: false)
        #expect(navigation.paths[.today]?.isEmpty == true)
    }

    @Test func opensBesideInRegularWidthAndStacksInside() {
        let navigation = FiscalNavigation()
        navigation.open(.races, in: .today, beside: true)
        #expect(navigation.inspector?.route == .races)
        navigation.open(.races, in: .today, beside: true)
        #expect(navigation.inspectorPath == [.races])
        navigation.close(in: .today, inspecting: true)
        navigation.close(in: .today, inspecting: true)
        #expect(navigation.inspector == nil)
    }

    @Test func switchingTabsClosesTheInspectorOfAnotherTab() {
        let navigation = FiscalNavigation()
        navigation.open(.races, in: .today, beside: true)
        navigation.selectedSection = .settings
        navigation.closeInspectorOutsideSelection()
        #expect(navigation.inspector == nil)
    }
}
