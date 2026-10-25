import ActivityKit
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct RaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RaceActivityAttributes.self) { context in
            RaceLockScreen(context: context)
                .activityBackgroundTint(RaceStyle.background)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "fiscal://home"))
        } dynamicIsland: { context in
            let board = RaceBoard(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let first = board.first {
                        CandidateSide(row: board.score(first), alignment: .leading, size: .island)
                            .padding(.leading, .space2XS)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let second = board.second {
                        CandidateSide(
                            row: board.score(second), alignment: .trailing, size: .island
                        )
                        .padding(.trailing, .space2XS)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: board.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaceStyle.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: .spaceXS) {
                        ShareBar(board: board, height: 8)
                        BoardFooter(board: board)
                    }
                    .padding(.horizontal, .space2XS)
                }
            } compactLeading: {
                CompactLeading(board: board)
            } compactTrailing: {
                CompactTrailing(board: board)
            } minimal: {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(RaceStyle.accent)
                    .accessibilityLabel(Text(verbatim: board.countText))
            }
            .keylineTint(RaceStyle.accent)
            .widgetURL(URL(string: "fiscal://home"))
        }
    }
}

enum RaceStyle {
    static let background = Color.scoreboard
    static let accent = Color.scoreboardAccent
    static let primary = Color.white
    static let secondary = Color.white.opacity(.opacityStrong)
    static let track = Color.white.opacity(.opacityTint)
}

struct RaceBoard {
    let title: String
    let rows: [RaceActivityRow]
    let state: RaceActivityState
    let isStale: Bool

    init(context: ActivityViewContext<RaceActivityAttributes>) {
        title = RaceText.title(office: context.attributes.office, uf: context.attributes.uf)
        rows = context.state.rows(with: context.attributes.candidates)
        state = context.state
        isStale = context.isStale
    }

    var first: RaceActivityRow? { rows.first }
    var second: RaceActivityRow? { rows.dropFirst().first }
    var hasStarted: Bool { state.sectionsPercent > 0 }
    var firstPalette: PartyPalette { first.map(palette) ?? PartyPalette.of(party: "", fallback: 0) }
    var secondPalette: PartyPalette {
        second.map(palette) ?? PartyPalette.of(party: "", fallback: 1)
    }

    func palette(_ row: RaceActivityRow) -> PartyPalette {
        let index = rows.firstIndex { $0.number == row.number } ?? 0
        return PartyPalette.of(party: row.party, fallback: index)
    }

    var countText: String {
        state.final
            ? String(appLocalized: "Final result")
            : String(appLocalized: "\(RaceText.shortPercent(state.sectionsPercent)) counted")
    }

    var sourceText: String {
        let time = RaceText.time(state.updatedDate)
        return isStale
            ? String(appLocalized: "No update since \(time) · TSE")
            : String(appLocalized: "TSE file from \(time)")
    }

    func score(_ row: RaceActivityRow) -> CandidateScoreText {
        CandidateScoreText(
            number: row.number,
            palette: palette(row),
            name: row.name,
            detail: "\(row.party) · \(row.number)",
            percent: hasStarted ? RaceText.percent(row.percent) : "—",
            shortPercent: hasStarted ? RaceText.shortPercent(row.percent) : "—",
            value: row.percent,
            elected: row.elected,
            dimmed: state.final && !row.elected,
            accessibility: RaceWidgetText.row(row))
    }
}

struct CandidateScoreText {
    let number: String
    let palette: PartyPalette
    let name: String
    let detail: String
    let percent: String
    let shortPercent: String
    let value: Double
    let elected: Bool
    let dimmed: Bool
    let accessibility: String
}

private struct RaceLockScreen: View {
    let context: ActivityViewContext<RaceActivityAttributes>

    var body: some View {
        let board = RaceBoard(context: context)
        VStack(spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(verbatim: "Fiscal")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(RaceStyle.accent)
                Spacer(minLength: .spaceS)
                Text(verbatim: board.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .center, spacing: .spaceS) {
                if let first = board.first {
                    CandidateSide(row: board.score(first), alignment: .leading, size: .lockScreen)
                }
                Spacer(minLength: 0)
                if let second = board.second {
                    CandidateSide(row: board.score(second), alignment: .trailing, size: .lockScreen)
                }
            }
            ShareBar(board: board, height: 12)
            BoardFooter(board: board)
        }
        .padding(.spaceL)
        .fontDesign(.rounded)
        .opacity(board.isStale ? 0.75 : 1)
    }
}

private struct CandidateSide: View {
    enum Size { case lockScreen, island }

    let row: CandidateScoreText
    let alignment: HorizontalAlignment
    let size: Size

    var body: some View {
        HStack(spacing: size == .lockScreen ? .spaceM : .spaceS) {
            if alignment == .leading { badge }
            VStack(alignment: alignment, spacing: 0) {
                Text(verbatim: row.percent)
                    .font(
                        .system(
                            size: size == .lockScreen ? 40 : 26, weight: .heavy, design: .rounded)
                    )
                    .monospacedDigit()
                    .contentTransition(.numericText(value: row.value))
                    .foregroundStyle(RaceStyle.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(verbatim: row.name)
                    .font(
                        size == .lockScreen
                            ? .subheadline.weight(.semibold) : .caption2.weight(.semibold)
                    )
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if alignment == .trailing { badge }
        }
        .opacity(row.dimmed ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: row.accessibility))
    }

    private var badge: some View {
        NumberBadge(
            number: row.number, palette: row.palette, elected: row.elected,
            side: size == .lockScreen ? 48 : 34)
    }
}

private struct NumberBadge: View {
    let number: String
    let palette: PartyPalette
    let elected: Bool
    let side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
            .fill(palette.gradient)
            .frame(width: side, height: side)
            .overlay {
                Text(verbatim: number)
                    .font(.system(size: side * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }
            .overlay(alignment: .topTrailing) {
                if elected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: side * 0.36))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, RaceStyle.accent)
                        .offset(x: side * 0.16, y: -side * 0.16)
                }
            }
    }
}

private struct ShareBar: View {
    let board: RaceBoard
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let first = board.first?.percent ?? 0
            let second = board.second?.percent ?? 0
            let total = first + second
            let share = total > 0 ? first / total : 0.5
            HStack(spacing: .spaceHairline) {
                Capsule()
                    .fill(
                        total > 0
                            ? AnyShapeStyle(board.firstPalette.gradient)
                            : AnyShapeStyle(RaceStyle.track)
                    )
                    .frame(width: max(height, (proxy.size.width - .spaceHairline) * share))
                Capsule()
                    .fill(
                        total > 0
                            ? AnyShapeStyle(board.secondPalette.gradient)
                            : AnyShapeStyle(RaceStyle.track))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct BoardFooter: View {
    let board: RaceBoard

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: board.countText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaceStyle.primary)
                .monospacedDigit()
            Spacer(minLength: .spaceS)
            Text(verbatim: board.sourceText)
                .font(.caption2)
                .foregroundStyle(RaceStyle.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CompactLeading: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    let board: RaceBoard

    var body: some View {
        if limited {
            Image(systemName: "chart.bar.xaxis").foregroundStyle(RaceStyle.accent)
                .accessibilityLabel(Text(verbatim: board.countText))
        } else if let first = board.first {
            CompactStanding(score: board.score(first))
                .accessibilityLabel(Text(verbatim: board.score(first).accessibility))
        }
    }
}

private struct CompactTrailing: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    let board: RaceBoard

    var body: some View {
        if !limited, let second = board.second {
            CompactStanding(score: board.score(second))
                .accessibilityLabel(Text(verbatim: board.score(second).accessibility))
        }
    }
}

private struct CompactStanding: View {
    let score: CandidateScoreText

    var body: some View {
        HStack(spacing: .space2XS) {
            NumberBadge(number: score.number, palette: score.palette, elected: false, side: 20)
            Text(verbatim: score.shortPercent)
                .font(.caption.weight(.heavy))
                .foregroundStyle(RaceStyle.primary)
                .contentTransition(.numericText())
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

enum RaceWidgetText {
    static func row(_ row: RaceActivityRow) -> String {
        let votes = String(appLocalized: "\(RaceText.votes(row.votes)) votes")
        let base = "\(row.name), \(row.party), \(RaceText.percent(row.percent)), \(votes)"
        return row.elected ? "\(base), \(String(appLocalized: "Elected"))" : base
    }
}
