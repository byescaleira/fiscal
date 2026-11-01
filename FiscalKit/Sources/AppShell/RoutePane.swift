import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct RoutePane: View {
    @Environment(FiscalNavigation.self) private var navigation
    let section: AppSection

    var body: some View {
        Group {
            if let first = navigation.panes[section]?.first {
                NavigationStack(path: rest(after: first)) {
                    RouteScreen(route: first)
                        .offlineNotice()
                        .toolbar {
                            RoutePaneCloseItem { navigation.closePane(in: section, all: true) }
                        }
                        .navigationDestination(for: Route.self) { route in
                            RouteScreen(route: route).offlineNotice()
                        }
                }
                .id(first)
            } else {
                RoutePlaceholder(section: section)
            }
        }
        .environment(\.close, CloseAction { navigation.closePane(in: section, all: false) })
        .onChange(of: navigation.panes[section]) {
            AccessibilityNotification.ScreenChanged(nil).post()
        }
    }

    private func rest(after first: Route) -> Binding<[Route]> {
        Binding(
            get: { Array(navigation.panes[section, default: []].dropFirst()) },
            set: { navigation.panes[section] = [first] + $0 })
    }
}

struct RoutePaneCloseItem: ToolbarContent {
    let close: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Close", systemImage: "xmark", action: close)
                .tint(Color.primary)
                .keyboardShortcut(.cancelAction)
        }
    }
}

private struct RoutePlaceholder: View {
    let section: AppSection

    var body: some View {
        EmptyStateView(
            title: section.routePlaceholderTitle, description: section.routePlaceholderMessage
        ) {
            FiscalAnimationView(section.routePlaceholderAnimation, loops: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}
