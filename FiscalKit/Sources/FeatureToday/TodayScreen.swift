import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct TodayScreen: View {
    @Environment(TodayModel.self) private var today

    public init() {}

    public var body: some View {
        AdaptiveList {
            TodayEventsSection()
            TodayRacesSection()
        }
        .fontDesign(.rounded)
        .navigationTitle("Today")
        .toolbar { TodayToolbar() }
        .refreshable { await today.load() }
        .task { await today.load() }
    }
}

private struct TodayEventsSection: View {
    @Environment(TodayModel.self) private var today

    var body: some View {
        Section {
            if !today.isEmpty {
                ForEach(Array(today.events.enumerated()), id: \.offset) { _, event in
                    IconRow(
                        verbatim: event.title, detail: event.summary, symbol: event.symbol,
                        color: .retroDenim)
                }
            } else if let error = today.phase.error {
                IconRow(
                    "Couldn't load the data", detail: nil, symbol: error.symbol, color: .retroRust
                )
                .accessibilityHint(Text(verbatim: error.message))
            } else if today.phase.isLoading {
                ProgressView("Loading")
            } else {
                IconRow(
                    "Nothing new yet",
                    detail: "Votes, sessions and new laws show up here as they happen.",
                    symbol: "newspaper", color: .retroDenim)
            }
        } header: {
            Text("What Happened").sectionTitle()
        }
    }
}

private struct TodayRacesSection: View {
    var body: some View {
        Section {
            RouteLink(.races) {
                IconRow(
                    "Live Results", detail: "The official count, straight from the TSE.",
                    symbol: "checkmark.seal", color: .retroTeal)
            }
        } header: {
            Text("Elections").sectionTitle()
        }
    }
}

private struct TodayToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            #if os(macOS)
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            #else
                Button("Settings", systemImage: "gearshape") { open(.settings, in: section) }
                    .tint(Color.primary)
            #endif
        }
    }
}
