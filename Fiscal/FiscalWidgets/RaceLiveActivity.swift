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
                        CandidateScore(row: board.score(first), alignment: .leading, size: .island)
                            .padding(.leading, .space2XS)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let second = board.second {
                        CandidateScore(
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
                        ShareBar(first: board.first?.percent, second: board.second?.percent)
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
    static let background = Color(red: 0.06, green: 0.09, blue: 0.09)
    static let accent = Color(red: 0.38, green: 0.67, blue: 0.64)
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
            HStack(alignment: .top, spacing: .spaceL) {
                if let first = board.first {
                    CandidateScore(row: board.score(first), alignment: .leading, size: .lockScreen)
                }
                Spacer(minLength: 0)
                if let second = board.second {
                    CandidateScore(
                        row: board.score(second), alignment: .trailing, size: .lockScreen)
                }
            }
            ShareBar(first: board.first?.percent, second: board.second?.percent)
            BoardFooter(board: board)
        }
        .padding(.spaceL)
        .fontDesign(.rounded)
        .opacity(board.isStale ? 0.75 : 1)
    }
}

private struct CandidateScore: View {
    enum Size { case lockScreen, island }

    let row: CandidateScoreText
    let alignment: HorizontalAlignment
    let size: Size

    var body: some View {
        VStack(alignment: alignment, spacing: .space2XS) {
            HStack(spacing: .space2XS) {
                if row.elected, alignment == .trailing { seal }
                Text(verbatim: row.name)
                    .font(
                        size == .lockScreen
                            ? .subheadline.weight(.semibold) : .caption.weight(.semibold)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if row.elected, alignment == .leading { seal }
            }
            .foregroundStyle(RaceStyle.primary)
            Text(verbatim: row.percent)
                .font(.system(size: size == .lockScreen ? 36 : 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: row.value))
                .foregroundStyle(RaceStyle.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if size == .lockScreen {
                Text(verbatim: row.detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        .opacity(row.dimmed ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: row.accessibility))
    }

    private var seal: some View {
        Image(systemName: "checkmark.seal.fill").foregroundStyle(RaceStyle.accent)
    }
}

private struct ShareBar: View {
    let first: Double?
    let second: Double?

    var body: some View {
        GeometryReader { proxy in
            let total = (first ?? 0) + (second ?? 0)
            let share = total > 0 ? (first ?? 0) / total : 0
            ZStack(alignment: .leading) {
                Capsule().fill(RaceStyle.track)
                if total > 0 {
                    Capsule()
                        .fill(RaceStyle.primary)
                        .frame(width: max(proxy.size.height, proxy.size.width * share))
                }
                Rectangle()
                    .fill(RaceStyle.background)
                    .frame(width: 2)
                    .offset(x: proxy.size.width / 2 - 1)
            }
        }
        .frame(height: 8)
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
            CompactStanding(number: first.number, percent: board.score(first).shortPercent)
                .accessibilityLabel(Text(verbatim: board.score(first).accessibility))
        }
    }
}

private struct CompactTrailing: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    let board: RaceBoard

    var body: some View {
        if !limited, let second = board.second {
            CompactStanding(number: second.number, percent: board.score(second).shortPercent)
                .accessibilityLabel(Text(verbatim: board.score(second).accessibility))
        }
    }
}

private struct CompactStanding: View {
    let number: String
    let percent: String

    var body: some View {
        HStack(spacing: .space2XS) {
            Text(verbatim: number)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(RaceStyle.accent)
            Text(verbatim: percent)
                .font(.caption.weight(.bold))
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
