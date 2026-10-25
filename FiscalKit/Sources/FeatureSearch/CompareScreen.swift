import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct CompareScreen: View {
    @Environment(CompareModel.self) private var compare

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: compare.phase, isEmpty: compare.isEmpty, retry: { await compare.load() }
        ) {
            AdaptiveList {
                ForEach(compare.rows) { CompareRowSection(row: $0) }
            }
        } empty: {
            CompareEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle("Compare")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await compare.load() }
    }
}

private struct CompareRowSection: View {
    let row: CompareModel.Row

    var body: some View {
        Section {
            ForEach(row.cells) { cell in
                LabeledContent {
                    Text(verbatim: cell.value).monospacedDigit()
                } label: {
                    Text(verbatim: cell.name)
                }
            }
        } header: {
            Text(verbatim: row.title).sectionTitle()
        }
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
