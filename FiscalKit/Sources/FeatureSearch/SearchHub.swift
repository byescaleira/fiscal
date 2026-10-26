import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SearchHub: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        InvestigatorSection()
        if let error = search.phase.error {
            LoadIssueSection(error: error)
        }
        SavedInvestigationsSection()
        InvestigationDoorsSection()
        if !search.recents.isEmpty {
            RecentSection()
        }
        ThemesSection()
    }
}

private struct RecentSection: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        Section {
            ForEach(search.recents, id: \.self) { text in
                Button {
                    search.search(text)
                } label: {
                    Label {
                        Text(verbatim: text).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Recent searches").sectionTitle()
                Spacer(minLength: .spaceS)
                Button("Clear") { search.clearRecents() }
                    .font(.buttonLabel)
                    .buttonStyle(.borderless)
            }
            .textCase(nil)
        } footer: {
            Text("Saved only on this device.")
        }
    }
}

private struct LoadIssueSection: View {
    @Environment(SearchModel.self) private var search
    let error: PublicDataError

    var body: some View {
        Section {
            IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
            Button("Try Again") { Task { await search.load() } }
                .font(.buttonLabel)
        } footer: {
            Text("Saved investigations and pinned pieces stay on this device.")
        }
    }
}
