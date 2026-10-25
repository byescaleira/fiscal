import Testing

@testable import FeatureCore

@MainActor
struct NavigationTests {
    @Test func pushesInCompactWidth() {
        let navigation = FiscalNavigation()
        navigation.open(.item(id: nil), in: .home, beside: false)
        #expect(navigation.paths[.home] == [.item(id: nil)])
        navigation.close(in: .home, inspecting: false)
        #expect(navigation.paths[.home]?.isEmpty == true)
    }

    @Test func opensBesideInRegularWidthAndStacksInside() {
        let navigation = FiscalNavigation()
        navigation.open(.item(id: "a"), in: .home, beside: true)
        #expect(navigation.inspector?.route == .item(id: "a"))
        navigation.open(.item(id: "b"), in: .home, beside: true)
        #expect(navigation.inspectorPath == [.item(id: "b")])
        navigation.close(in: .home, inspecting: true)
        navigation.close(in: .home, inspecting: true)
        #expect(navigation.inspector == nil)
    }

    @Test func switchingTabsClosesTheInspectorOfAnotherTab() {
        let navigation = FiscalNavigation()
        navigation.open(.item(id: "a"), in: .home, beside: true)
        navigation.selectedSection = .settings
        navigation.closeInspectorOutsideSelection()
        #expect(navigation.inspector == nil)
    }
}
