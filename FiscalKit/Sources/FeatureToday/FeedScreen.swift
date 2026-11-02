import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct FeedScreen<RaceHero: View>: View {
    @Environment(FeedModel.self) private var feed
    @Environment(TodayModel.self) private var today
    @Environment(SessionModel.self) private var session
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?
    @Environment(FollowingBadge.self) private var badge: FollowingBadge?
    @Environment(\.scenePhase) private var scenePhase
    private let raceHero: (Race) -> RaceHero

    public init(@ViewBuilder raceHero: @escaping (Race) -> RaceHero) {
        self.raceHero = raceHero
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spaceL, pinnedViews: .sectionHeaders) {
                if let board = today.liveBoard {
                    TodayRaceHero(board: board) { raceHero(board.race) }
                        .transition(.opacity)
                        .zIndex(1)
                }
                if let lead = today.highlightLead {
                    TodayHighlightHero(highlight: lead)
                        .zIndex(1)
                }
                Section {
                    FeedList()
                } header: {
                    FeedFilterBar()
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.bottom, .space2XL)
            .frame(maxWidth: .readableColumn)
            .frame(maxWidth: .infinity)
        }
        .background(.plainBackground)
        .emphasisTitle("Feed")
        .toolbar { TodayToolbar() }
        .refreshable {
            await today.load()
            await feed.load()
        }
        .task {
            await today.watchRaces()
        }
        .task(id: session.generation) {
            async let top: Void = today.load()
            await feed.load()
            await top
        }
        .onChange(of: feed.newCount, initial: true) { _, count in badge?.count = count }
        .onChange(of: navigation?.selectedSection) { previous, section in
            if previous == .feed, section != .feed { feed.markSeen() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { feed.markSeen() }
        }
    }
}

private struct FeedFilterBar: View {
    @Environment(FeedModel.self) private var feed
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceS) {
            ForEach(FeedFilter.allCases) { filter in
                let isSelected = feed.filter == filter
                Button {
                    feed.filter = filter
                } label: {
                    Text(verbatim: filter.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(
                            isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
                        )
                        .padding(.horizontal, .spaceM)
                        .frame(minHeight: .badgeL)
                        .background(
                            isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.plainRow),
                            in: .capsule
                        )
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, .spaceS)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(.plainBackground)
                .padding(.top, -.medallion)
        }
    }
}

private struct FeedList: View {
    @Environment(FeedModel.self) private var feed

    var body: some View {
        if !feed.hasLoaded, let error = feed.phase.error {
            FeedMessage(symbol: error.symbol, text: error.message)
            Button("Try Again") { Task { await feed.load() } }
        } else if !feed.hasLoaded {
            ProgressView("Loading")
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spaceXL)
        } else {
            if feed.followsNobody { FeedFollowInvite() }
            if !feed.missing.isEmpty {
                FeedMessage(symbol: "wifi.slash", text: feed.missingText)
            }
            let items = feed.visible
            if items.isEmpty {
                FeedMessage(symbol: "tray", text: feed.emptyMessage)
            }
            ForEach(items) { item in
                FeedCard(item: item)
                    .onAppear {
                        if item.id == items.last?.id {
                            Task { await feed.loadMore() }
                        }
                    }
            }
            FeedEnd()
        }
    }
}

private struct FeedEnd: View {
    @Environment(FeedModel.self) private var feed

    var body: some View {
        if feed.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spaceL)
        } else if feed.isAtEnd, !feed.visible.isEmpty {
            FeedMessage(symbol: "checkmark.circle", text: feed.endMessage)
        }
    }
}

private struct FeedMessage: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, .spaceS)
    }
}

private struct FeedFollowInvite: View {
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?
    @Environment(\.appTint) private var tint

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text("Follow the people who represent you")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Their votes, proposals and spending show up here, by date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("See Who Represents You", systemImage: "map") {
                navigation?.selectedSection = .region
            }
            .font(.subheadline.weight(.semibold))
            .tint(tint)
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
    }
}
