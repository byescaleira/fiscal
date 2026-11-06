import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct FeedScreen<RaceHero: View>: View {
    @Environment(FeedModel.self) private var feed
    @Environment(SessionModel.self) private var session
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?
    @Environment(FollowingBadge.self) private var badge: FollowingBadge?
    @Environment(FollowController.self) private var follow: FollowController?
    @Environment(LikeController.self) private var like: LikeController?
    @Environment(\.scenePhase) private var scenePhase
    @ReducesMotion private var reduceMotion
    private let raceHero: (Race) -> RaceHero

    public init(@ViewBuilder raceHero: @escaping (Race) -> RaceHero) {
        self.raceHero = raceHero
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spaceL, pinnedViews: .sectionHeaders) {
                if let board = feed.liveBoard {
                    FeedRaceHero(board: board) { raceHero(board.race) }
                        .transition(reduceMotion ? .identity : .opacity)
                        .zIndex(1)
                }
                if let lead = feed.highlightLead {
                    FeedHighlightHero(highlight: lead)
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
        .toolbar { FeedToolbar() }
        .refreshable { await feed.load() }
        .task(id: session.generation) {
            await feed.load()
            await feed.watchRaces()
        }
        .onChange(of: feed.newCount, initial: true) { _, count in badge?.count = count }
        .onChange(of: feed.items, initial: true) { _, items in
            like?.showing(
                Dictionary(
                    items.compactMap { item in Route.destination(for: item).map { (item.id, $0) } },
                    uniquingKeysWith: { first, _ in first }))
        }
        .onChange(of: follow?.followed) { _, slugs in
            guard let slugs else { return }
            Task { await feed.followsChanged(to: slugs) }
        }
        .onChange(of: navigation?.selectedSection) { previous, section in
            if previous == .feed, section != .feed { feed.markSeen() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { feed.markSeen() }
        }
    }
}

private struct FeedToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("My Support", systemImage: "heart") { open(.support, in: section) }
                Button("Liked Items", systemImage: "heart.text.square") {
                    open(.liked, in: section)
                }
            } label: {
                Label("My Support and Liked Items", systemImage: "heart")
            }
            .tint(Color.primary)
        }
        FixedToolbarSpacer(placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            #if os(macOS)
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            #else
                Button("Settings", systemImage: "gearshape") { open(.settings, in: section) }
                    .tint(Color.primary)
            #endif
        }
    }
}

private struct FeedFilterBar: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            FeedFilterChips()
            ScrollView(.horizontal) {
                FeedFilterChips()
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .padding(.vertical, .spaceS)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(.plainBackground)
                .padding(.top, -.medallion)
        }
    }
}

private struct FeedFilterChips: View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            if let notice = feed.notice {
                FeedMessage(symbol: notice.symbol, text: notice.text)
            }
            if feed.followsNobody { FeedFollowInvite() }
            if feed.filter == .following, !feed.followed.isEmpty { FeedFollowingRow() }
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

private struct FeedFollowingRow: View {
    @Environment(FeedModel.self) private var feed

    var body: some View {
        RouteLink(.following) {
            HStack(spacing: .spaceS) {
                Label("Who You Follow", systemImage: "person.2")
                    .font(.rowTitle)
                Spacer(minLength: .spaceS)
                Text(verbatim: PublicFormat.number(feed.followed.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
    }
}

private struct FeedFollowInvite: View {
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
            RouteLink(.following, showsChevron: false) {
                Label("See Who Represents You", systemImage: "person.2")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
    }
}
