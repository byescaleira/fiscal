import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SearchResultsList: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        let results = search.results
        if results.isEmpty {
            Section {
                SearchNoResults()
            }
        } else {
            if !results.people.isEmpty {
                Section {
                    ForEach(results.people) { PersonResultRow(card: $0) }
                } header: {
                    Text("People").sectionTitle().textCase(nil)
                } footer: {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        if let note = search.placeNote { Text(verbatim: note) }
                        Text("In alphabetical order.")
                        SearchSourceFooter()
                    }
                }
            }
            if !results.parties.isEmpty {
                Section {
                    ForEach(results.parties) { PartyResultRow(party: $0) }
                } header: {
                    Text("Parties").sectionTitle().textCase(nil)
                }
            }
            if !results.places.isEmpty {
                Section {
                    ForEach(results.places) { PlaceResultRow(place: $0) }
                } header: {
                    Text("Places").sectionTitle().textCase(nil)
                } footer: {
                    Text("Tap a place to see who represents it.")
                }
            }
            if !results.votes.isEmpty {
                Section {
                    ForEach(results.votes) { VoteResultRow(vote: $0) }
                } header: {
                    Text("Recent votes").sectionTitle().textCase(nil)
                } footer: {
                    Text("The latest votes in the Chamber and the Senate, newest first.")
                }
            }
        }
    }
}

private struct PersonResultRow: View {
    @Environment(SearchModel.self) private var search
    let card: PersonCard

    var body: some View {
        RouteLink(.person(slug: card.slug)) {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: card.name).font(.rowTitle).foregroundStyle(Color.primary)
                    AdaptiveStack(spacing: .spaceS) {
                        PartyMark(card.party)
                        Text(verbatim: search.detail(for: card))
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                    if card.status != .inOffice {
                        Text(verbatim: card.status.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, .space2XS)
            .accessibilityElement(children: .combine)
        }
        .simultaneousGesture(TapGesture().onEnded { search.record() })
    }
}

private struct PartyResultRow: View {
    @Environment(SearchModel.self) private var search
    let party: PartySummary

    var body: some View {
        Button {
            search.apply(.party(party.party))
        } label: {
            HStack(spacing: .spaceM) {
                PartyMark(party.party)
                    .frame(minWidth: .badgeL + .spaceInset, alignment: .leading)
                Text(verbatim: search.detail(for: party))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: .spaceS)
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows the people of this party"))
    }
}

private struct PlaceResultRow: View {
    @Environment(SearchModel.self) private var search
    let place: Place

    var body: some View {
        Button {
            search.apply(.place(place))
        } label: {
            IconRow(
                verbatim: place.name, detail: search.detail(for: place),
                symbol: place.isState ? "map" : "mappin.and.ellipse",
                color: .retroTeal)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows who represents this place"))
    }
}

private struct VoteResultRow: View {
    let vote: VoteSummary

    var body: some View {
        RouteLink(.vote(id: vote.id)) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: "\(vote.proposition) · \(vote.house.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: vote.plainSummary ?? vote.summary)
                    .font(.rowTitle)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
            }
            .padding(.vertical, .space2XS)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct SearchNoResults: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        if let error = search.phase.error {
            VStack(alignment: .leading, spacing: .spaceM) {
                IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
                Button("Try Again") { Task { await search.load() } }
                    .font(.buttonLabel)
            }
        } else if search.phase.isLoading || search.phase == .idle {
            ProgressView("Loading")
                .frame(maxWidth: .infinity)
        } else if search.query.isEmpty {
            ContentUnavailableView(
                "Nothing here yet", systemImage: "magnifyingglass",
                description: Text("Fiscal has no data for this filter in the latest update."))
        } else {
            ContentUnavailableView.search(text: search.query)
        }
    }
}
