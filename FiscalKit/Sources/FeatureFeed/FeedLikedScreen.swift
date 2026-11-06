import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct FeedLikedScreen: View {
    @Environment(LikeController.self) private var like
    @State private var isConfirmingErase = false

    public init() {}

    public var body: some View {
        Group {
            if like.items.isEmpty {
                EmptyStateView(
                    title: "Nothing Liked",
                    description: "Tap the heart on a Feed item to keep it here."
                ) {
                    IconRow("Only on this device", symbol: "lock", color: .retroDenim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(like.items) { item in
                            FeedLikedRow(item: item, route: like.destination(for: item))
                                .swipeActions {
                                    Button("Unlike", systemImage: "heart.slash", role: .destructive)
                                    {
                                        Task { await like.remove(id: item.id) }
                                    }
                                }
                        }
                    } footer: {
                        Text(
                            "Your liked items stay only on this device, outside iCloud and backups."
                        )
                    }
                }
            }
        }
        .emphasisTitle("Liked Items")
        .toolbar {
            if !like.items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete Liked Items", systemImage: "trash") {
                        isConfirmingErase = true
                    }
                    .tint(Color.primary)
                }
            }
        }
        .confirmationDialog(
            "Delete Liked Items", isPresented: $isConfirmingErase, titleVisibility: .visible
        ) {
            Button("Delete Liked Items", role: .destructive) {
                Task { await like.erase() }
            }
        } message: {
            Text("Every heart in the Feed goes back to empty. This can't be undone.")
        }
    }
}

private struct FeedLikedRow: View {
    let item: LikedItem
    let route: Route?

    var body: some View {
        if let route {
            RouteLink(route) { label }
        } else if let url = item.url {
            ExternalLink(destination: url) { label }
                .foregroundStyle(.primary)
        } else {
            VStack(alignment: .leading, spacing: .spaceXS) {
                label
                Text("This item left the Feed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var label: some View {
        HStack(spacing: .spaceS) {
            SymbolBadge(FeedLikedText.symbol(item.kind), color: .secondary, size: .badgeM)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(verbatim: FeedLikedText.day(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum FeedLikedText {
    static func symbol(_ kind: LikedItem.Kind) -> String {
        switch kind {
        case .vote: "checkmark.square"
        case .proposal: "doc.text"
        case .speech: "text.bubble"
        case .expenses: "brazilianrealsign"
        case .check: "checkmark.shield"
        case .event: "building.columns"
        case .highlight: "star"
        }
    }

    static func day(_ item: LikedItem) -> String {
        let style = Date.FormatStyle(locale: .app)
        let date = item.day.date()
        if item.kind == .expenses {
            return date.formatted(style.month(.abbreviated).year())
        }
        return date.formatted(style.day().month(.abbreviated).year())
    }
}
