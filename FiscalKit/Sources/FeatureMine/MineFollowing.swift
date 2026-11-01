import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct FollowingUpdatesSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            if mine.updatesPhase == .loading && mine.updates.isEmpty {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spaceL)
            } else if mine.hasNoUpdates && mine.missing.isEmpty {
                IconRow(
                    "Nothing new in the last 30 days",
                    detail: "Votes, spending and fact checks of who you follow show up here.",
                    symbol: "clock.arrow.circlepath", color: .retroTeal)
            } else {
                ForEach(mine.updates) { FollowingUpdateRow(update: $0) }
            }
            if !mine.missing.isEmpty {
                FollowingMissingRow()
            }
        } header: {
            Text("Updates").sectionTitle()
        } footer: {
            Text("From the official sources, newest first. Nobody is ranked.")
        }
    }
}

struct FollowingUpdateRow: View {
    @Environment(MineModel.self) private var mine
    let update: FollowingUpdate

    var body: some View {
        Group {
            if let route = mine.route(for: update) {
                RouteLink(route) { label }
            } else if case .check(let check) = update.kind {
                Link(destination: check.url) { label }
                    .foregroundStyle(.primary)
            }
        }
        .followActions(update.person)
    }

    private var label: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            PersonPortrait(
                slug: update.person.slug, name: update.person.name, party: update.person.party)
            VStack(alignment: .leading, spacing: .space2XS) {
                HStack(spacing: .spaceXS) {
                    Text(verbatim: update.person.name)
                        .font(.rowTitle)
                    if mine.isNew(update) {
                        Text("New")
                            .font(.chipLabel)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, .spaceXS)
                            .background(.tint.opacity(.opacityTint), in: .capsule)
                    }
                }
                Text(verbatim: mine.title(for: update))
                    .font(.subheadline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: mine.detail(for: update))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, .spaceXS)
        .accessibilityElement(children: .combine)
    }
}

private struct FollowingMissingRow: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Button {
            Task { await mine.loadUpdates() }
        } label: {
            HStack(spacing: .spaceM) {
                SymbolBadge("arrow.clockwise", color: .retroOrange)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text("No data right now").font(.rowTitle)
                    Text(verbatim: mine.missingText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Try again"))
    }
}

struct FollowingPeopleSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            ForEach(mine.followedCards) { card in
                HStack(spacing: .spaceS) {
                    MineRosterRow(card: card, showsPlace: true)
                    FollowButton(card)
                }
            }
        } header: {
            Text("Who You Follow").sectionTitle()
        } footer: {
            Text("In alphabetical order. Who you follow stays in your iCloud when sync is on.")
        }
    }
}

struct FollowingSuggestionsSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        if !mine.suggestions.isEmpty {
            Section {
                ForEach(mine.suggestions) { card in
                    HStack(spacing: .spaceS) {
                        MineRosterRow(card: card, showsPlace: true)
                        FollowButton(card)
                    }
                }
            } header: {
                Text(mine.isEmpty ? "Follow Who Represents You" : "Suggestions").sectionTitle()
            } footer: {
                Text(
                    "Who represents your place and who you support. Tap the person icon to follow.")
            }
        }
    }
}

struct FollowingRegionHeader: View {
    var body: some View {
        Section {
        } header: {
            Text("Your Region").sectionTitle()
        }
    }
}
