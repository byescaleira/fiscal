import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

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
