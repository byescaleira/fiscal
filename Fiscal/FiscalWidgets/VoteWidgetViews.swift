import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct ScoreSide: View {
    enum Side { case yes, no }

    let board: VoteBoard
    let side: Side
    var font: Font = .scoreboardHero

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(verbatim: value)
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(number ?? 0)))
                .foregroundStyle(WidgetStyle.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(1)
        }
    }

    private var alignment: HorizontalAlignment { side == .yes ? .leading : .trailing }
    private var value: String { side == .yes ? board.yesText : board.noText }
    private var number: Int? { side == .yes ? board.tally.yes : board.tally.no }
    private var title: LocalizedStringKey { side == .yes ? "YES" : "NO" }
    private var symbol: String { side == .yes ? "checkmark" : "xmark" }
}

struct OutcomeLabel: View {
    let board: VoteBoard
    var isCompact = false

    var body: some View {
        Label {
            Text(verbatim: board.outcomeTitle.uppercased(with: .app))
        } icon: {
            Image(systemName: board.outcomeSymbol)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(WidgetStyle.primary)
        .lineLimit(1)
        .padding(.horizontal, isCompact ? 0 : .spaceS)
        .padding(.vertical, isCompact ? 0 : .space2XS)
        .background(isCompact ? Color.clear : WidgetStyle.track, in: .capsule)
    }
}

struct VoteSmall: View {
    let board: VoteBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(verbatim: board.proposition)
                .font(.caption.weight(.bold))
                .foregroundStyle(WidgetStyle.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: board.eyebrow)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline) {
                ScoreSide(board: board, side: .yes, font: .scoreboardNumber)
                Spacer(minLength: .spaceXS)
                ScoreSide(board: board, side: .no, font: .scoreboardNumber)
            }
            TallyStrip(board: board)
            OutcomeLabel(board: board, isCompact: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct VoteBoardHeader: View {
    let board: VoteBoard

    var body: some View {
        VStack(spacing: .spaceS) {
            HStack(alignment: .center, spacing: .spaceS) {
                ScoreSide(board: board, side: .yes)
                Spacer(minLength: 0)
                VStack(spacing: .space2XS) {
                    Text(verbatim: board.eyebrow)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(WidgetStyle.secondary)
                    Text(verbatim: board.proposition)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WidgetStyle.primary)
                        .multilineTextAlignment(.center)
                    OutcomeLabel(board: board)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                Spacer(minLength: 0)
                ScoreSide(board: board, side: .no)
            }
            TallyStrip(board: board)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct VoteMedium: View {
    let board: VoteBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            VoteBoardHeader(board: board)
            Spacer(minLength: 0)
            LastPlayLine(title: board.summary, source: board.sourceText, lines: 1)
        }
    }
}

struct VoteLarge: View {
    let deck: VoteDeck

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VoteBoardHeader(board: deck.headline)
            LastPlayLine(title: deck.headline.summary, source: deck.headline.sourceText)
            if !deck.earlier.isEmpty {
                Text("EARLIER")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(WidgetStyle.secondary)
                VStack(spacing: .spaceS) {
                    ForEach(deck.earlier) { board in
                        if let url = board.url {
                            Link(destination: url) { EarlierRow(board: board) }
                        } else {
                            EarlierRow(board: board)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct EarlierRow: View {
    let board: VoteBoard

    var body: some View {
        HStack(spacing: .spaceS) {
            Image(systemName: board.outcomeSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetStyle.primary)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(board.proposition) · \(board.houseShort), \(board.dayText)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetStyle.primary)
                Text(verbatim: board.summary)
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: .spaceXS)
            Text(verbatim: board.scoreText)
                .font(.scoreboardCompact)
                .monospacedDigit()
                .foregroundStyle(WidgetStyle.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct VoteRectangular: View {
    let board: VoteBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(board.proposition) · \(board.houseShort)")
                .font(.caption.weight(.bold))
                .widgetAccentable()
            HStack(spacing: .space2XS) {
                Image(systemName: "checkmark")
                Text(verbatim: board.yesText)
                Text(verbatim: "×")
                Text(verbatim: board.noText)
                Image(systemName: "xmark")
            }
            .font(.scoreboardCompact)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Label {
                Text(verbatim: board.outcomeTitle)
            } icon: {
                Image(systemName: board.outcomeSymbol)
            }
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct VoteInline: View {
    let board: VoteBoard

    var body: some View {
        Label {
            Text(verbatim: "\(board.proposition) · \(board.scoreText)")
        } icon: {
            Image(systemName: board.outcomeSymbol)
        }
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}

struct VoteCircular: View {
    let board: VoteBoard

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: board.outcomeSymbol)
                    .font(.caption2.weight(.bold))
                    .widgetAccentable()
                Text(verbatim: board.yesText)
                    .font(.headline.width(.condensed))
                Text(verbatim: board.noText)
                    .font(.caption2.weight(.semibold).width(.condensed))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.space2XS)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}
