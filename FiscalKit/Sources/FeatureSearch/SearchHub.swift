import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SearchHub: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        InvestigatorSection()
        MemoryDoorSection()
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

private struct MemoryDoorSection: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        Section {
            Button {
                open(.memory, in: section)
            } label: {
                DoorTile(
                    chip: "SINCE 1889", title: "Memory",
                    detail: "Past elections, the phases of Brazilian politics and study guides",
                    symbol: "books.vertical",
                    colors: [.retroPlum, .retroPlum.mix(with: .black, by: .opacitySoft)])
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

private struct DoorTile: View {
    let chip: LocalizedStringKey
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(chip)
                .font(.chipLabel)
                .padding(.horizontal, .spaceS)
                .padding(.vertical, .space2XS)
                .background(.white.opacity(.opacityTint), in: .capsule)
            Spacer(minLength: .spaceL)
            Text(title)
                .font(.titleMedium)
                .lineLimit(2)
            Text(detail)
                .font(.footnote)
                .opacity(.opacityStrong)
                .lineLimit(3)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: .medallion + .spaceXL, alignment: .leading)
        .padding(.spaceL)
        .background(alignment: .topTrailing) {
            Image(systemName: symbol)
                .font(.icon(.xl, weight: .bold))
                .foregroundStyle(.white.opacity(.opacitySoft))
                .padding(.spaceL)
                .accessibilityHidden(true)
        }
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: .radiusL)
        )
        .accessibilityElement(children: .combine)
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
            Text("Your investigations stay saved, even without a connection.")
        }
    }
}
