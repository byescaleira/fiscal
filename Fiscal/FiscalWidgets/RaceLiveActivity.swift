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

private struct RaceLockScreen: View {
    let context: ActivityViewContext<RaceActivityAttributes>

    var body: some View {
        let board = RaceBoard(context: context)
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .center, spacing: .spaceXS) {
                if let first = board.first {
                    ScoreColumn(score: board.score(first), alignment: .leading)
                }
                Spacer(minLength: 0)
                CenterStatus(board: board)
                Spacer(minLength: 0)
                if let second = board.second {
                    ScoreColumn(score: board.score(second), alignment: .trailing)
                }
            }
            HStack(spacing: .spaceS) {
                Capsule()
                    .fill(RaceStyle.primary)
                    .frame(width: 3, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: board.marginText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaceStyle.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: board.sourceText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RaceStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                LinearGradient(
                    colors: [board.firstPalette.primary, board.secondPalette.primary],
                    startPoint: .leading, endPoint: .trailing)
                Color.black.opacity(.opacityTint)
            }
        }
        .fontDesign(.rounded)
        .opacity(board.isStale ? 0.75 : 1)
    }
}

private struct ScoreColumn: View {
    let score: CandidateScoreText
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: .space2XS) {
            HStack(spacing: .spaceXS) {
                if alignment == .leading { badge }
                Text(verbatim: score.percent)
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: score.value))
                    .foregroundStyle(RaceStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if alignment == .trailing { badge }
            }
            Text(verbatim: score.name.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(RaceStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .opacity(score.dimmed ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: score.accessibility))
    }

    private var badge: some View {
        NumberBadge(number: score.number, palette: score.palette, elected: score.elected, side: 38)
    }
}

private struct CenterStatus: View {
    let board: RaceBoard

    var body: some View {
        VStack(spacing: .space2XS) {
            Text(verbatim: board.officeText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RaceStyle.secondary)
                .lineLimit(1)
            Text(verbatim: board.centerValue)
                .font(.headline.weight(.bold))
                .foregroundStyle(RaceStyle.primary)
                .monospacedDigit()
                .contentTransition(.numericText(value: board.state.sectionsPercent))
                .lineLimit(1)
            Text(verbatim: board.centerCaption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(RaceStyle.secondary)
                .lineLimit(1)
            Capsule()
                .fill(RaceStyle.track)
                .frame(width: 44, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(RaceStyle.primary)
                        .frame(width: 44 * min(max(board.state.sectionsPercent / 100, 0), 1))
                }
        }
        .frame(minWidth: 60)
        .accessibilityElement(children: .combine)
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
