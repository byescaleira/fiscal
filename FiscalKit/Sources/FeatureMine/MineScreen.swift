import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MineScreen: View {
    @Environment(MineModel.self) private var mine
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var mine = mine
        Group {
            if mine.isEmpty {
                MineEmptyState()
            } else {
                AdaptiveList { MineFollowingSection() }
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Mine")
        .task(id: session.generation) { await mine.load() }
        .errorAlert($mine.error)
    }
}

private struct MineFollowingSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            ForEach(mine.followed) { person in
                RouteLink(.person(slug: person.card.slug)) {
                    IconRow(
                        verbatim: person.card.name, detail: mine.detail(for: person),
                        symbol: "person", color: .retroTeal)
                }
            }
        } header: {
            Text("Following").sectionTitle()
        }
    }
}

private struct MineEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No representatives yet",
            description:
                "Pick your state and Fiscal shows who represents you, from the president to the state assembly."
        ) {
            IconRow("President", symbol: "building.columns", color: .retroDenim)
            IconRow("Senators", symbol: "person.2", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
