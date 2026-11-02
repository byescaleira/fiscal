import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct FollowingPeopleSection: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        Section {
            ForEach(region.followedCards) { card in
                HStack(spacing: .spaceS) {
                    RegionRosterRow(card: card, showsPlace: true)
                    FollowButton(card)
                }
            }
            if region.showsFollowingInvite {
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
    @Environment(RegionModel.self) private var region
    @Environment(\.appTint) private var tint
    @ReducesMotion private var reduceMotion

    var body: some View {
        HStack(spacing: .spaceS) {
            RouteLink(region.followingInviteRoute) {
                IconRow(
                    "Share who you follow",
                    detail: "A card with up to six people you follow, with name, party and office.",
                    symbol: "square.and.arrow.up", color: tint)
            }
            Button("Not Now", systemImage: "xmark") {
                withAnimation(reduceMotion ? nil : .smooth) { region.dismissFollowingInvite() }
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
    @Environment(RegionModel.self) private var region

    var body: some View {
        if !region.suggestions.isEmpty {
            Section {
                ForEach(region.suggestions) { card in
                    HStack(spacing: .spaceS) {
                        RegionRosterRow(card: card, showsPlace: true)
                        FollowButton(card)
                    }
                }
            } header: {
                Text(region.isEmpty ? "Follow Who Represents You" : "Suggestions").sectionTitle()
            } footer: {
                Text("Who represents your place. Tap Follow next to the name.")
            }
        }
    }
}
