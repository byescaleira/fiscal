import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct CompareScreen: View {
    @Environment(CompareModel.self) private var compare
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    public init() {}

    public var body: some View {
        @Bindable var compare = compare
        PublicDataContent(
            phase: compare.phase, isEmpty: compare.isEmpty, retry: { await compare.load() }
        ) {
            CompareList()
        } empty: {
            CompareEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle("Compare")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Choose people", systemImage: "person.badge.plus") {
                    Task { await compare.pick() }
                }
                .tint(Color.primary)
            }
            if let share = compare.share {
                ToolbarItem(placement: .primaryAction) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        open(share, in: section)
                    }
                    .tint(Color.primary)
                }
            }
        }
        .sheet(isPresented: $compare.isPicking, onDismiss: { Task { await compare.load() } }) {
            ComparePicker()
                .environment(compare)
        }
        .task { await compare.load() }
    }
}

private struct CompareList: View {
    @Environment(CompareModel.self) private var compare

    var body: some View {
        let table = compare.table
        AdaptiveList(columnWidth: .readableColumn) {
            Section {
            } header: {
                CompareHero(columns: table.columns)
                    .textCase(nil)
                    .padding(.bottom, .spaceS)
            }
            ForEach(table.groups) { group in
                CompareGroupSection(group: group, columns: table.columns)
            }
        }
    }
}

private struct CompareGroupSection: View {
    @Environment(CompareModel.self) private var compare
    let group: CompareTable.Group
    let columns: [CompareTable.Column]

    var body: some View {
        Section {
            ForEach(group.metrics) { metric in
                CompareMetricRow(metric: metric, columns: columns)
            }
        } header: {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text(verbatim: group.title).sectionTitle()
                if group.isLensOrdered, compare.showsLensBadge {
                    LensBadge()
                }
            }
            .textCase(nil)
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if group.isLensOrdered {
                    Text("Your topics come first. The numbers are the same for everyone.")
                }
                if !group.missing.isEmpty {
                    Text(
                        "Not published for these offices: \(group.missing.formatted(.list(type: .and).locale(.app)))"
                    )
                }
                if let line = compare.sourceLine { Text(verbatim: line) }
            }
        }
    }
}

private struct CompareEmptyState: View {
    @Environment(CompareModel.self) private var compare

    var body: some View {
        EmptyStateView(
            title: "Pick two people",
            description:
                "Fiscal puts the same numbers side by side, in columns of the same width, with no score or ranking.",
            actionTitle: "Choose people", action: { Task { await compare.pick() } }
        ) {
            HStack(spacing: .spaceL) {
                ForEach(0..<CompareModel.range.lowerBound, id: \.self) { _ in
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.icon(.l))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
