import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct LensScreen: View {
    @Environment(LensModel.self) private var lens

    public init() {}

    public var body: some View {
        Group {
            if lens.isEmpty {
                LensEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Lens")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await lens.load() }
    }
}

private struct LensEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No lens yet",
            description:
                "Choose 3 to 5 topics and Fiscal puts them first. The numbers stay the same for everyone, and your lens never leaves this device."
        ) {
            IconRow("Health", symbol: "cross.case", color: .retroTeal)
            IconRow("Public security", symbol: "shield", color: .retroDenim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
