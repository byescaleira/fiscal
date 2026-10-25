import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct HomeScreen: View {
    @Environment(HomeModel.self) private var home
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var home = home
        Group {
            if home.isEmpty {
                HomeEmptyState()
            } else {
                AdaptiveList {
                    HomeHeroSection()
                    HomeItemsSection()
                }
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Home")
        .toolbar { HomeToolbar() }
        .task(id: session.generation) { await home.load() }
        .errorAlert($home.error)
    }
}

private struct HomeToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Item", systemImage: "plus") { open(.item(id: nil), in: section) }
                .tint(Color.primary)
        }
    }
}

private struct HomeEmptyState: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        EmptyStateView(
            title: "No items yet",
            description: "Add the first item and it shows up here, newest first.",
            actionTitle: "Add Item", action: { open(.item(id: nil), in: section) }
        ) {
            HomeExample()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}

private struct HomeExample: View {
    var body: some View {
        IconRow("First idea", detail: "Today", symbol: "lightbulb", color: .retroMustard)
        IconRow("Weekend plan", detail: "Yesterday", symbol: "calendar", color: .retroTeal)
    }
}
