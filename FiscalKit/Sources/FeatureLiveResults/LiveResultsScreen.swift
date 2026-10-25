import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LiveResultsScreen: View {
    @Environment(LiveResultsModel.self) private var results

    public init() {}

    public var body: some View {
        @Bindable var results = results
        Group {
            if !results.hasLoaded {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.races.isEmpty {
                LiveResultsUnavailable()
            } else {
                LiveResultsBoard()
            }
        }
        .background(.groupedBackground)
        .fontDesign(.rounded)
        .navigationTitle("Live Results")
        .toolbar { LiveResultsToolbar() }
        .refreshable { await results.refresh() }
        .task { await results.run() }
        .errorAlert($results.error)
        .onChange(of: results.announcement) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
    }
}

private struct LiveResultsBoard: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceXL) {
                LiveResultsNotice()
                if let featured = results.featured {
                    RaceHeroCard(race: featured, opensDetail: true)
                }
                if results.groups.isEmpty, results.hasFilter {
                    LiveResultsNoMatch()
                }
                ForEach(results.groups) { group in
                    RaceGroupSection(group: group)
                }
                LiveResultsFooter()
            }
            .padding(.horizontal, .spaceL)
            .padding(.bottom, .space2XL)
            .frame(maxWidth: .readableColumn * 2)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .smooth, value: results.groups.map(\.id))
        }
    }
}

private struct RaceGroupSection: View {
    @Environment(LiveResultsModel.self) private var results
    let group: RaceGroup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Label {
                Text(verbatim: results.groupHeader(group))
            } icon: {
                Image(systemName: group.region?.symbol ?? "map")
                    .foregroundStyle(.secondary)
            }
            .font(.titleMedium)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: .cardColumn), spacing: .spaceL, alignment: .top)
                ],
                alignment: .leading, spacing: .spaceL
            ) {
                ForEach(group.races) { RaceCompactCard(race: $0) }
            }
        }
        .transition(.opacity)
    }
}

private struct LiveResultsFooter: View {
    @Environment(LiveResultsModel.self) private var results

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            if !results.isWaiting {
                Label(
                    "Numbers straight from the TSE, with no projections or polls.",
                    systemImage: "building.columns")
            }
            if let off = results.activitiesOffText {
                Text(verbatim: off)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, .spaceXS)
    }
}

private struct LiveResultsNoMatch: View {
    @Environment(LiveResultsModel.self) private var results

    var body: some View {
        VStack(spacing: .spaceM) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.icon(.l))
                .foregroundStyle(.secondary)
            Text("No race matches these filters")
                .font(.headline)
            Button("Clear Filters") { results.clearFilters() }
                .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity)
        .padding(.spaceXL)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
    }
}

private struct LiveResultsUnavailable: View {
    @Environment(LiveResultsModel.self) private var results

    var body: some View {
        EmptyStateView(
            title: "Results unavailable",
            description: "Couldn't reach the results server. It tries again on its own.",
            actionTitle: "Try Again", action: { Task { await results.refresh() } }
        ) {
            IconRow(
                "President · Brazil", detail: "TSE", symbol: "checkmark.seal", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LiveResultsNotice: View {
    @Environment(LiveResultsModel.self) private var results

    var body: some View {
        if let notice = results.notice {
            Label {
                Text(verbatim: notice.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: notice.symbol)
                    .foregroundStyle(.secondary)
            }
            .padding(.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
        }
    }
}

private struct LiveResultsToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            LiveResultsFilterMenu()
        }
    }
}

private struct LiveResultsFilterMenu: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.appTint) private var tint

    var body: some View {
        @Bindable var results = results
        Menu {
            Picker("Status", selection: $results.status) {
                ForEach(RaceStatusFilter.allCases) { status in
                    Label(status.title, systemImage: status.symbol).tag(status)
                }
            }
            .pickerStyle(.inline)
            Picker(selection: $results.region) {
                Label("All Regions", systemImage: "map").tag(RaceRegion?.none)
                ForEach(results.regionChoices) { region in
                    Label(region.title, systemImage: region.symbol).tag(RaceRegion?.some(region))
                }
            } label: {
                Label("Region", systemImage: "map")
            }
            .pickerStyle(.menu)
            if results.hasFilter {
                Divider()
                Button("Clear Filters", systemImage: "eraser.line.dashed") {
                    results.clearFilters()
                }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .foregroundStyle(results.hasFilter ? tint : Color.primary)
                .symbolEffect(.bounce, value: results.hasFilter)
                .accessibilityValue(Text(verbatim: results.filterSummary))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .badge(results.activeFilterCount)
        .disabled(results.others.isEmpty)
    }
}
