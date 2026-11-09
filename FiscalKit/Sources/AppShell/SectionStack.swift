import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct SectionStack: View {
    @Environment(FiscalNavigation.self) private var navigation
    let section: AppSection

    var body: some View {
        Group {
            if navigation.layout.isFolded {
                SectionFold(section: section)
            } else {
                SectionPath(section: section)
            }
        }
        .environment(\.navigationSection, section)
    }
}

struct SectionPath: View {
    @Environment(FiscalNavigation.self) private var navigation
    let section: AppSection

    var body: some View {
        NavigationStack(path: navigation.path(for: section)) {
            SectionScreen(section: section)
                .offlineNotice()
                .navigationDestination(for: Route.self) { route in
                    RouteScreen(route: route)
                        .offlineNotice()
                        .environment(
                            \.close,
                            CloseAction { navigation.close(in: section, inspecting: false) })
                }
        }
    }
}

private struct SectionFold: View {
    @Environment(FiscalNavigation.self) private var navigation
    let section: AppSection

    var body: some View {
        FoldAwareArrangement(.split) {
            if navigation.layout.routeComesFirst { route } else { root }
        } secondary: {
            if navigation.layout.routeComesFirst { root } else { route }
        }
    }

    private var root: some View {
        SectionPath(section: section)
    }

    private var route: some View {
        RoutePane(section: section)
    }
}
