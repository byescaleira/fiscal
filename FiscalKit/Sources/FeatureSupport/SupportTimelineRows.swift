import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SupportFilterRail: View {
    @Environment(SupportModel.self) private var model

    var body: some View {
        EdgeToEdgeRail(.padded(.spaceInset), snaps: false) {
            SupportFilterChip(filter: .all)
            ForEach(model.cards) { card in
                SupportFilterChip(filter: .person(card.slug), card: card)
            }
            ForEach(model.causes) { cause in
                SupportFilterChip(filter: .cause(cause), symbol: cause.symbol)
            }
        }
    }
}

private struct SupportFilterChip: View {
    @Environment(SupportModel.self) private var model
    @Environment(\.appTint) private var tint
    let filter: SupportFilter
    var card: PersonCard?
    var symbol: String?

    var body: some View {
        let isSelected = model.filter == filter
        Button {
            model.filter = filter
        } label: {
            HStack(spacing: .spaceXS) {
                if let card {
                    PersonPortrait(
                        slug: card.slug, name: card.name, party: card.party, size: .badgeS
                    )
                    .accessibilityHidden(true)
                } else if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(verbatim: model.title(for: filter))
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, .spaceM)
            .frame(minHeight: .badgeL)
            .background(
                isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.plainRow), in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SupportEventRow: View {
    @Environment(SupportModel.self) private var model
    let event: SupportEvent

    var body: some View {
        Group {
            if let route = Route.destination(for: event) {
                RouteLink(route) { content }
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: model.accessibility(event)))
    }

    private var content: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            SupportDayColumn(day: event.date)
            VStack(alignment: .leading, spacing: .spaceS) {
                Text(verbatim: model.kicker(event))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(event.ballots) { SupportBallotLine(ballot: $0) }
                ForEach(event.people) { SupportPersonLine(card: $0) }
                if let causes = model.causesLine(event) {
                    Text(verbatim: causes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, .space2XS)
    }
}

private struct SupportDayColumn: View {
    let day: CalendarDay

    var body: some View {
        VStack(spacing: .spaceHairline) {
            Text(verbatim: day.date().formatted(.dateTime.weekday(.abbreviated).locale(.app)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .fixedSize()
            Text(verbatim: day.date().formatted(.dateTime.day().locale(.app)))
                .font(.emphasis(.title3, weight: .bold))
                .monospacedDigit()
        }
        .frame(minWidth: .badgeL)
    }
}

private struct SupportBallotLine: View {
    @Environment(SupportModel.self) private var model
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
            Text(verbatim: model.ballotText(ballot))
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

private struct SupportPersonLine: View {
    let card: PersonCard

    var body: some View {
        HStack(spacing: .spaceS) {
            PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeS)
            Text(verbatim: card.name)
                .font(.footnote)
                .lineLimit(1)
        }
    }
}
