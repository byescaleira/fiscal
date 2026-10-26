import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SearchHub: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        SearchDoorsSection()
        if search.comparesFirst {
            SuggestionsSection()
        }
        if !search.recents.isEmpty {
            RecentSection()
        }
        ElectionsSection()
        ThemesSection()
        if !search.comparesFirst {
            SuggestionsSection()
        }
        if let error = search.phase.error {
            LoadIssueSection(error: error)
        }
    }
}

private struct SearchDoorsSection: View {
    @Environment(SearchModel.self) private var search
    @Environment(\.appTint) private var tint
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        Section {
            AdaptiveRow(spacing: .spaceM) {
                Button {
                    open(.compare(slugs: []), in: section)
                } label: {
                    DoorTile(
                        chip: "2 TO 3 PEOPLE", title: "Compare",
                        detail: "Same numbers, side by side", symbol: "rectangle.split.3x1",
                        colors: [tint, tint.mix(with: .black, by: .opacitySoft)])
                }
                Button {
                    open(.races, in: section)
                } label: {
                    DoorTile(
                        chip: liveChip, title: "Live results",
                        detail: "President and governors, from the TSE",
                        symbol: "checkmark.seal", colors: [.scoreboardAccent, .scoreboard])
                }
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var liveChip: LocalizedStringKey {
        search.elections.contains { $0.liveRound != nil } ? "LIVE TODAY" : "TSE"
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

private struct SuggestionsSection: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        if !search.suggestions.isEmpty {
            Section {
                ForEach(search.suggestions) { suggestion in
                    RouteLink(.compare(slugs: suggestion.slugs)) {
                        SuggestionRow(suggestion: suggestion)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: .spaceXS) {
                    Text("Side by side").sectionTitle()
                    if search.showsLensBadge, search.comparesFirst {
                        LensBadge()
                    }
                }
                .textCase(nil)
            } footer: {
                Text("Same office and same state, in alphabetical order. No score, no ranking.")
            }
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: CompareSuggestion

    var body: some View {
        HStack(spacing: .spaceM) {
            HStack(spacing: -.spaceM) {
                ForEach(suggestion.people) { person in
                    PersonPortrait(
                        slug: person.slug, name: person.name, party: person.party, size: .badgeL
                    )
                    .overlay { Circle().stroke(.groupedRow, lineWidth: .spaceHairline) }
                }
            }
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: suggestion.title).font(.rowTitle)
                Text(verbatim: suggestion.names)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .combine)
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
            Text("The election calendar below still works.")
        }
    }
}
