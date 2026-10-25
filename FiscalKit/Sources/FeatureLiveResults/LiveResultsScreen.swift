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
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
}

private struct LiveResultsUnavailable: View {
    var body: some View {
        EmptyStateView(
            title: "Results unavailable",
            description: "Couldn't reach the results server. Pull to try again."
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
        if results.isOffline || results.isWaiting {
            Section {
                Label {
                    Text(
                        results.isOffline
                            ? "No connection. Showing the last numbers received."
                            : "The count starts at 5 PM Brasília time. Numbers come straight from the TSE, with no projections or polls."
                    )
                    .font(.subheadline)
                } icon: {
                    Image(systemName: results.isOffline ? "wifi.slash" : "clock")
                }
            }
        }
    }
}
