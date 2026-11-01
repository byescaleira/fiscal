import FiscalDesignSystem
import SwiftUI
import Testing

@testable import FeatureCore

extension LayoutContext {
    static func flat(width: CGFloat, accessibility: Bool = false) -> LayoutContext {
        LayoutContext(
            size: CGSize(width: width, height: 951), isHorizontallyCompact: width < 500,
            isAccessibilitySize: accessibility)
    }

    static func folded(_ axis: Axis, accessibility: Bool = false) -> LayoutContext {
        let division =
            axis == .horizontal
            ? CGRect(x: 330, y: 0, width: 9, height: 951)
            : CGRect(x: 0, y: 470, width: 669, height: 9)
        return LayoutContext(
            size: CGSize(width: 669, height: 951), isHorizontallyCompact: false,
            isAccessibilitySize: accessibility, divisions: [division])
    }
}

@MainActor
struct FoldNavigationTests {
    @Test func flatWidthKeepsTheStackAndTheInspector() {
        let navigation = FiscalNavigation()
        navigation.fit(.flat(width: 669))
        #expect(navigation.layout == .stack)
        navigation.fit(.flat(width: 1024))
        #expect(navigation.layout == .beside)
        navigation.open(.vote(id: "v1"), in: .votes)
        #expect(navigation.inspector?.route == .vote(id: "v1"))
    }

    @Test func foldedSideBySideOpensBesideInEverySection() {
        let navigation = FiscalNavigation()
        navigation.fit(.folded(.horizontal))
        #expect(navigation.layout == .folded(.horizontal))
        #expect(!navigation.layout.routeComesFirst)
        for section in AppSection.allCases {
            navigation.open(.person(slug: section.rawValue), in: section)
            #expect(navigation.panes[section] == [.person(slug: section.rawValue)])
            #expect(navigation.paths[section, default: []].isEmpty)
            #expect(navigation.selectedSection == section)
        }
        #expect(navigation.inspector == nil)
    }

    @Test func foldedStackedPutsTheRouteOnTop() {
        let navigation = FiscalNavigation()
        navigation.fit(.folded(.vertical))
        #expect(navigation.layout == .folded(.vertical))
        #expect(navigation.layout.routeComesFirst)
        navigation.open(.person(slug: "a"), in: .today)
        #expect(navigation.panes[.today] == [.person(slug: "a")])
    }

    @Test func foldingMovesStacksToTheRoutePaneAndBack() {
        let navigation = FiscalNavigation()
        navigation.fit(.flat(width: 669))
        navigation.open(.vote(id: "v1"), in: .votes)
        navigation.open(.person(slug: "a"), in: .votes)
        navigation.fit(.folded(.horizontal))
        #expect(navigation.panes[.votes] == [.vote(id: "v1"), .person(slug: "a")])
        #expect(navigation.paths[.votes, default: []].isEmpty)
        navigation.fit(.folded(.vertical))
        #expect(navigation.panes[.votes] == [.vote(id: "v1"), .person(slug: "a")])
        navigation.fit(.flat(width: 669))
        #expect(navigation.paths[.votes] == [.vote(id: "v1"), .person(slug: "a")])
        #expect(navigation.panes.isEmpty)
    }

    @Test func foldingTakesTheInspectorRoute() {
        let navigation = FiscalNavigation()
        navigation.fit(.flat(width: 1024))
        navigation.open(.person(slug: "a"), in: .search)
        navigation.open(.vote(id: "v1"), in: .search)
        navigation.fit(.folded(.horizontal))
        #expect(navigation.inspector == nil)
        #expect(navigation.inspectorPath.isEmpty)
        #expect(navigation.panes[.search] == [.person(slug: "a"), .vote(id: "v1")])
    }

    @Test func accessibilitySizeNeverFolds() {
        let navigation = FiscalNavigation()
        navigation.fit(.folded(.horizontal, accessibility: true))
        #expect(navigation.layout == .stack)
        navigation.open(.person(slug: "a"), in: .mine)
        #expect(navigation.paths[.mine] == [.person(slug: "a")])
        navigation.fit(.flat(width: 1024, accessibility: true))
        #expect(navigation.layout == .stack)
    }

    @Test func closingThePaneStepsBackOrClearsIt() {
        let navigation = FiscalNavigation()
        navigation.fit(.folded(.horizontal))
        navigation.open(.vote(id: "v1"), in: .votes)
        navigation.open(.person(slug: "a"), in: .votes)
        navigation.closePane(in: .votes, all: false)
        #expect(navigation.panes[.votes] == [.vote(id: "v1")])
        navigation.open(.person(slug: "b"), in: .votes)
        navigation.closePane(in: .votes, all: true)
        #expect(navigation.panes[.votes, default: []].isEmpty)
    }

    @Test func openRoutesListsStacksPanesAndTheInspector() {
        let navigation = FiscalNavigation()
        navigation.fit(.folded(.horizontal))
        navigation.open(.person(slug: "a"), in: .today)
        navigation.fit(.flat(width: 1024))
        navigation.open(.vote(id: "v1"), in: .votes)
        #expect(Set(navigation.openRoutes) == [.person(slug: "a"), .vote(id: "v1")])
        navigation.reset()
        #expect(navigation.openRoutes.isEmpty)
    }
}
