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
                AdaptiveList {
                    LiveResultsNotice()
                    if let president = results.president {
                        RaceSection(race: president)
                    }
                    ForEach(results.governors) { RaceSection(race: $0) }
                }
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Live Results")
        .refreshable { await results.refresh() }
        .task { await results.run() }
        .errorAlert($results.error)
        .onChange(of: results.announcement) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
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
        .background(.groupedBackground)
    }
}

private struct LiveResultsNotice: View {
    @Environment(LiveResultsModel.self) private var results

    var body: some View {
        if let notice = results.notice {
            Section {
                Label {
                    Text(verbatim: notice.text).font(.subheadline)
                } icon: {
                    Image(systemName: notice.symbol)
                }
            }
        }
    }
}
