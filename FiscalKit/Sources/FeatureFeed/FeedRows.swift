import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct FeedCard: View {
    @Environment(FeedModel.self) private var feed
    let item: FeedItem

    var body: some View {
        Group {
            if let route = Route.destination(for: item) {
                RouteCard(
                    route, label: Text(verbatim: feed.accessibility(item)), padding: 0,
                    cornerRadius: .radiusGroup
                ) {
                    content
                }
            } else if let url = item.url {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        ExternalLink(destination: url, showsSymbol: false) {
                            Color.clear.contentShape(.rect(cornerRadius: .radiusGroup))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: feed.accessibility(item)))
                        .accessibilityHint(Text("Opens in the browser"))
                        .accessibilityAddTraits(.isLink)
                    }
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        Color.clear
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: feed.accessibility(item)))
                    }
            }
        }
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .spaceM)
        .overlay(alignment: .bottom) {
            Divider().offset(y: .spaceL / 2)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            FeedCardHeader(item: item)
            Group {
                if let expenses = item.expenses {
                    FeedExpensesBody(item: item, expenses: expenses)
                } else {
                    FeedFactBody(item: item)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            if item.kind == .check, let url = item.url {
                FeedCheckImage(page: url)
                    .allowsHitTesting(false)
            }
            if item.ballots.count == 1, let ballot = item.ballots.first {
                FeedSoleBallot(ballot: ballot)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else if !item.ballots.isEmpty {
                VStack(spacing: .spaceXS) {
                    ForEach(item.ballots) { FeedBallotRow(ballot: $0) }
                }
            }
            if Route.destination(for: item) == nil, item.url != nil {
                FeedSourceLink()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct FeedSourceLink: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceXS) {
            Text("See the Source")
            ExternalLinkSymbol()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(tint)
    }
}

private struct FeedCardHeader: View {
    @Environment(FeedModel.self) private var feed
    @Environment(\.appTint) private var tint
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let item: FeedItem

    private var person: PersonCard? {
        item.ballots.count <= 1 ? item.involved.first : nil
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spaceXS) {
                who
                HStack(spacing: .spaceS) {
                    day.allowsHitTesting(false).accessibilityHidden(true)
                    Spacer(minLength: .spaceS)
                    heart
                }
            }
        } else {
            HStack(spacing: .spaceS) {
                who
                Spacer(minLength: .spaceS)
                day.allowsHitTesting(false).accessibilityHidden(true)
                heart
            }
        }
    }

    @ViewBuilder private var who: some View {
        if let person {
            Button {
                open(.person(slug: person.slug), in: section)
            } label: {
                identity(person)
                    .frame(minHeight: .badgeL)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: person.name))
            .accessibilityHint(Text("Opens the profile"))
            .accessibilityAddTraits(.isButton)
        } else {
            identity(nil)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private func identity(_ person: PersonCard?) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spaceXS) {
                badge
                if let person { name(person) }
                reason
            }
        } else {
            HStack(spacing: .spaceS) {
                badge
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    if let person { name(person) }
                    reason
                }
            }
        }
    }

    @ViewBuilder private var badge: some View {
        if let person {
            PersonPortrait(
                slug: person.slug, name: person.name, party: person.party, size: .badgeM)
        } else {
            SymbolBadge(
                feed.symbol(item), color: item.isFollowing ? tint : .secondary, size: .badgeM)
        }
    }

    private func name(_ person: PersonCard) -> some View {
        Text(verbatim: person.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var reason: some View {
        Text(verbatim: feed.reasonText(item))
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.isFollowing ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var heart: some View {
        FeedLikeButton(id: item.id) {
            LikedItem(item: item, likedAt: .now)
        }
    }

    private var day: some View {
        Text(verbatim: feed.dayText(item))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }
}

private struct FeedFactBody: View {
    @Environment(FeedModel.self) private var feed
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Text(verbatim: feed.kicker(item))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: item.title)
                .font(.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = item.detail {
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FeedExpensesBody: View {
    @Environment(FeedModel.self) private var feed
    let item: FeedItem
    let expenses: FeedExpenses

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Text(verbatim: feed.expensesTitle(item))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: feed.amount(expenses))
                .font(.amountTitle)
                .monospacedDigit()
                .amountLine()
        }
    }
}

private struct FeedSoleBallot: View {
    @Environment(FeedModel.self) private var feed
    let ballot: SupportBallot

    var body: some View {
        Text(verbatim: feed.soleBallotText(ballot))
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceXS)
            .background(.plainBackground, in: .capsule)
    }
}

private struct FeedBallotRow: View {
    @Environment(FeedModel.self) private var feed
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let ballot: SupportBallot

    var body: some View {
        Button {
            open(.person(slug: ballot.person.slug), in: section)
        } label: {
            HStack(spacing: .spaceS) {
                PersonPortrait(
                    slug: ballot.person.slug, name: ballot.person.name, party: ballot.person.party,
                    size: .badgeS)
                Text(verbatim: ballot.person.name)
                    .font(.footnote)
                    .lineLimit(1)
                Spacer(minLength: .spaceS)
                Text(verbatim: feed.ballotText(ballot))
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minHeight: .badgeL)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(ballot.person.name): \(feed.ballotText(ballot))"))
        .accessibilityHint(Text("Opens the profile"))
        .accessibilityAddTraits(.isButton)
    }
}
