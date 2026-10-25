import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct HomeHeroSection: View {
    @Environment(HomeModel.self) private var home

    var body: some View {
        Section {
            FigureHeader(title: "Your Items", value: home.countText, numeric: Double(home.count)) {
                Text(home.latestText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .animation(.smooth, value: home.count)
        }
    }
}

struct HomeItemsSection: View {
    @Environment(HomeModel.self) private var home

    var body: some View {
        Section {
            ForEach(home.items) { HomeItemRow(item: $0) }
        } header: {
            Text("Latest").sectionTitle()
        } footer: {
            Text("Tap an item to edit or delete it.")
        }
    }
}

private struct HomeItemRow: View {
    @Environment(HomeModel.self) private var home
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.appTint) private var appTint
    let item: Item

    var body: some View {
        Button {
            open(.item(id: item.id), in: section)
        } label: {
            IconRow(
                verbatim: item.title, detail: home.detail(for: item), symbol: "square.stack",
                color: appTint)
        }
        .buttonStyle(.plain)
    }
}
