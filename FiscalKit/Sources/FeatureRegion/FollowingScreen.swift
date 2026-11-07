import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct FollowingScreen: View {
    @Environment(FollowingModel.self) private var following
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var following = following
        AdaptiveList {
            if !following.isEmpty {
                FollowingPeopleSection()
            } else if following.hasLoaded {
                FollowingNobodySection()
            }
            if following.hasPlace {
                FollowingSuggestionsSection()
            } else if following.hasLoaded {
                FollowingPlaceInvite()
            }
        }
        .emphasisTitle("Who You Follow")
        .refreshable { await following.load() }
        .task(id: session.generation) { await following.load() }
        .errorAlert($following.error)
    }
}

private struct FollowingPeopleSection: View {
    @Environment(FollowingModel.self) private var following

    var body: some View {
        Section {
            ForEach(following.cards) { card in
                HStack(spacing: .spaceS) {
                    RegionRosterRow(card: card, showsPlace: true)
                    FollowButton(card)
                }
            }
            if following.showsInvite {
                FollowingShareInviteRow()
            }
        } footer: {
            Text("In alphabetical order. Who you follow stays in your iCloud when sync is on.")
        }
    }
}

private struct FollowingNobodySection: View {
    var body: some View {
        Section {
            Text("You don't follow anyone yet. Who you follow shows up in the Feed, by date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FollowingShareInviteRow: View {
    @Environment(FollowingModel.self) private var following
    @Environment(\.appTint) private var tint
    @ReducesMotion private var reduceMotion

    var body: some View {
        HStack(spacing: .spaceS) {
            RouteLink(following.inviteRoute) {
                IconRow(
                    "Share who you follow",
                    detail: "A card with up to six people you follow, with name, party and office.",
                    symbol: "square.and.arrow.up", color: tint)
            }
            Button("Not Now", systemImage: "xmark") {
                withAnimation(reduceMotion ? nil : .smooth) { following.dismissInvite() }
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

private struct FollowingSuggestionsSection: View {
    @Environment(FollowingModel.self) private var following

    var body: some View {
        if !following.suggestions.isEmpty {
            Section {
                ForEach(following.suggestions) { card in
                    HStack(spacing: .spaceS) {
                        RegionRosterRow(card: card, showsPlace: true)
                        FollowButton(card)
                    }
                }
            } header: {
                Text(following.isEmpty ? "Follow Who Represents You" : "Suggestions")
                    .sectionTitle()
            } footer: {
                Text("Who represents your place. Tap Follow next to the name.")
            }
        }
    }
}

private struct FollowingPlaceInvite: View {
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?
    @Environment(\.appTint) private var tint

    var body: some View {
        Section {
            Button {
                navigation?.selectedSection = .region
            } label: {
                HStack(spacing: .spaceM) {
                    IconRow(
                        "Choose your place",
                        detail: "Suggestions come from who represents your state or city.",
                        symbol: "mappin.and.ellipse", color: tint
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RouteChevron()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
