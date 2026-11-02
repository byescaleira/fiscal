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
    @Environment(\.appTint) private var tint
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let update: FollowingUpdate

    var body: some View {
        Group {
            if let route = mine.route(for: update) {
                RouteLink(route) { label }
            } else if case .check(let check) = update.kind {
                ExternalLink(destination: check.url) { label }
                    .foregroundStyle(.primary)
            }
        }
        .followActions(update.person)
    }

    private var label: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            PersonPortrait(
                slug: update.person.slug, name: update.person.name, party: update.person.party
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .space2XS) {
                AdaptiveStack(spacing: .spaceXS) {
                    Text(verbatim: update.person.name)
                        .font(.rowTitle)
                    if mine.isNew(update) {
                        Chip("New", color: tint, shape: .capsule)
                    }
                }
                Text(verbatim: mine.title(for: update))
                    .font(.subheadline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
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
            if mine.showsFollowingInvite {
                FollowingShareInviteRow()
            }
        } header: {
            Text("Who You Follow").sectionTitle()
        } footer: {
            Text("In alphabetical order. Who you follow stays in your iCloud when sync is on.")
        }
    }
}

private struct FollowingShareInviteRow: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.appTint) private var tint
    @ReducesMotion private var reduceMotion

    var body: some View {
        HStack(spacing: .spaceS) {
            RouteLink(mine.followingInviteRoute) {
                IconRow(
                    "Share who you follow",
                    detail: "A card with up to six people you follow, with name, party and office.",
                    symbol: "square.and.arrow.up", color: tint)
            }
            Button("Not Now", systemImage: "xmark") {
                withAnimation(reduceMotion ? nil : .smooth) { mine.dismissFollowingInvite() }
            }
            .labelStyle(.iconOnly)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: .rowHeight, minHeight: .rowHeight)
            .contentShape(.rect)
            .buttonStyle(.plain)
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
                Text("Who represents your place. Tap Follow next to the name.")
            }
        }
    }
}
