import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct HighlightKicker: View {
    let board: HighlightBoard

    var body: some View {
        Label {
            Text(verbatim: board.kicker)
        } icon: {
            Image(systemName: board.kindSymbol)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(.widgetLabelShrink)
    }
}

struct HighlightWeightText: View {
    let board: HighlightBoard

    var body: some View {
        Text(verbatim: board.weightText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
    }
}

struct HighlightUncertainty: View {
    let board: HighlightBoard
    var isShort = false

    var body: some View {
        if let text = isShort ? board.uncertaintyShort : board.uncertainty {
            Text(verbatim: text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(isShort ? 1 : 2)
                .minimumScaleFactor(.widgetTextShrink)
        }
    }
}

struct HighlightWho: View {
    let board: HighlightBoard
    var showsPortrait = true

    var body: some View {
        HStack(spacing: .spaceS) {
            if showsPortrait, let name = board.personName, board.hasPerson {
                PersonPortrait(
                    slug: board.personSlug ?? "", name: name, party: board.party ?? "",
                    size: .badgeS
                )
                .widgetAccentable()
            }
            VStack(alignment: .leading, spacing: 0) {
                if let name = board.personName, board.hasPerson {
                    Text(verbatim: name)
                        .font(.caption.weight(.bold))
                }
                Text(verbatim: board.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(.widgetTextShrink)
            Spacer(minLength: .spaceXS)
            if let party = board.party, !party.isEmpty {
                PartyMark(party)
                    .widgetAccentable()
            }
        }
    }
}

struct HighlightSmall: View {
    let board: HighlightBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            HighlightKicker(board: board)
            Text(verbatim: board.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(5)
                .minimumScaleFactor(.widgetTextShrink)
            Spacer(minLength: 0)
            HStack(spacing: .space2XS) {
                if let party = board.party, !party.isEmpty {
                    PartyMark(party).widgetAccentable()
                }
                Text(verbatim: board.personName ?? board.subtitle)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(.widgetLabelShrink)
            }
            HighlightWeightText(board: board)
            HighlightUncertainty(board: board, isShort: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct HighlightMedium: View {
    let board: HighlightBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline) {
                HighlightKicker(board: board)
                Spacer(minLength: .spaceS)
                HighlightWeightText(board: board)
            }
            Text(verbatim: board.title)
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(.widgetTextShrink)
            HighlightUncertainty(board: board, isShort: true)
            Spacer(minLength: 0)
            HighlightWho(board: board)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct HighlightLarge: View {
    let deck: HighlightDeck

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .firstTextBaseline) {
                    HighlightKicker(board: deck.lead)
                    Spacer(minLength: .spaceS)
                    HighlightWeightText(board: deck.lead)
                }
                Text(verbatim: deck.lead.title)
                    .font(.headline)
                    .lineLimit(5)
                    .minimumScaleFactor(.widgetTextShrink)
                SegmentedBar(
                    count: Relevance.segments, value: deck.lead.relevance.filledSegments,
                    color: .retroTeal
                )
                .widgetAccentable()
                HighlightUncertainty(board: deck.lead)
                HighlightWho(board: deck.lead)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: deck.lead.accessibilityText))
            if !deck.others.isEmpty {
                Divider()
                Text("ALSO HIGHLIGHTED")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: .spaceS) {
                    ForEach(deck.others) { board in
                        if let url = board.url {
                            Link(destination: url) { HighlightRow(board: board) }
                        } else {
                            HighlightRow(board: board)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct HighlightRow: View {
    let board: HighlightBoard

    var body: some View {
        HStack(alignment: .top, spacing: .spaceS) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: board.kicker)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                Text(verbatim: board.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }
            .lineLimit(1)
            Spacer(minLength: .spaceXS)
            Text(verbatim: board.relevance.shortTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct HighlightRectangular: View {
    let board: HighlightBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: .space2XS) {
                Image(systemName: "scalemass")
                Text(verbatim: board.kicker)
                    .lineLimit(1)
                    .minimumScaleFactor(.widgetLabelShrink)
                Spacer(minLength: .space2XS)
                Text(verbatim: board.relevance.shortTitle)
            }
            .font(.caption2.weight(.bold))
            .widgetAccentable()
            Text(verbatim: board.title)
                .font(.caption)
                .lineLimit(board.uncertaintyShort == nil ? 2 : 1)
            HighlightUncertainty(board: board, isShort: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct HighlightInline: View {
    let board: HighlightBoard

    var body: some View {
        Label {
            Text(verbatim: "\(board.kindTitle): \(board.title)")
        } icon: {
            Image(systemName: "scalemass")
        }
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}
