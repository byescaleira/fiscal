import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct MineScreen: View {
    @Environment(MineModel.self) private var mine

    public init() {}

    public var body: some View {
        Group {
            if mine.isEmpty {
                MineEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Mine")
        .task { await mine.load() }
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
