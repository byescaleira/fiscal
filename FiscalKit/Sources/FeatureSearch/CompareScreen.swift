import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct CompareScreen: View {
    @Environment(CompareModel.self) private var compare

    public init() {}

    public var body: some View {
        Group {
            if compare.isEmpty {
                CompareEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Compare")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct CompareEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Pick two people",
            description:
                "Choose two politicians in Search and Fiscal puts their numbers side by side, with no score or ranking."
        ) {
            IconRow("Attendance", symbol: "calendar", color: .retroDenim)
            IconRow("Proposals", symbol: "doc.text", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
