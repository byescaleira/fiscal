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
                RouteLink(route, showsChevron: false) { card }
                    .accessibilityAddTraits(.isButton)
            } else if let url = item.url {
                ExternalLink(destination: url) { card }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isLink)
            } else {
                card
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: feed.accessibility(item)))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            FeedCardHeader(item: item)
            if let expenses = item.expenses {
                FeedExpensesBody(item: item, expenses: expenses)
            } else {
                FeedFactBody(item: item)
            }
            if item.ballots.count == 1, let ballot = item.ballots.first {
                FeedSoleBallot(ballot: ballot)
            } else if !item.ballots.isEmpty {
                VStack(spacing: .spaceS) {
                    ForEach(item.ballots) { FeedBallotRow(ballot: $0) }
                }
            }
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
        .contentShape(.rect(cornerRadius: .radiusGroup))
    }
}

private struct FeedCardHeader: View {
    @Environment(FeedModel.self) private var feed
    @Environment(\.appTint) private var tint
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: FeedItem

    private var person: PersonCard? {
        item.ballots.count <= 1 ? item.involved.first : nil
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spaceXS) {
                badge
                if let person { name(person) }
                reason
                day
            }
        } else {
            HStack(spacing: .spaceS) {
                badge
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    if let person { name(person) }
                    reason
                }
                Spacer(minLength: .spaceS)
                day
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
    let ballot: SupportBallot

    var body: some View {
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
    }
}
