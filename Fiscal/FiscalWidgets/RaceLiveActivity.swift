import ActivityKit
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import UIKit
import WidgetKit

struct RaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RaceActivityAttributes.self) { context in
            RaceLockScreen(context: context)
                .activityBackgroundTint(nil)
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
                        ShareBar(board: board, height: .spaceS)
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
        if let winner = board.winner {
            WinnerLockScreen(board: board, winner: winner)
        } else {
            live(board)
        }
    }

    private func live(_ board: RaceBoard) -> some View {
        VStack(spacing: .spaceS) {
            HStack(alignment: .center, spacing: .spaceS) {
                Label {
                    Text(board.state.final ? "FINAL" : "LIVE")
                } icon: {
                    Image(
                        systemName: board.state.final
                            ? "checkmark.seal" : "dot.radiowaves.left.and.right")
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(RaceStyle.primary)
                .padding(.horizontal, .spaceS)
                .padding(.vertical, .space2XS)
                .background(RaceStyle.track, in: .capsule)
                Text(verbatim: board.officeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaceStyle.primary)
                    .lineLimit(1)
                Spacer(minLength: .spaceS)
                Text(verbatim: board.sourceText)
                    .font(.caption2)
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack(alignment: .center, spacing: .spaceS) {
                if let first = board.first {
                    SideColumn(row: first, score: board.score(first), alignment: .leading)
                }
                Spacer(minLength: 0)
                VStack(spacing: .space2XS) {
                    Text(verbatim: board.centerValue)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(RaceStyle.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: board.state.sectionsPercent))
                    Text(verbatim: board.centerCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RaceStyle.secondary)
                    Capsule()
                        .fill(RaceStyle.track)
                        .frame(width: .badgeL, height: .space2XS)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(RaceStyle.primary)
                                .frame(
                                    width: .badgeL
                                        * min(max(board.state.sectionsPercent / 100, 0), 1))
                        }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                if let second = board.second {
                    SideColumn(row: second, score: board.score(second), alignment: .trailing)
                }
            }
            ShareBar(board: board, height: .spaceS)
        }
        .padding(.horizontal, .spaceXL)
        .padding(.vertical, .spaceL)
        .frame(maxWidth: .infinity)
        .fontDesign(.rounded)
        .partyMarksStill()
        .opacity(board.isStale ? .opacityStrong : 1)
    }
}

private struct SideColumn: View {
    let row: RaceActivityRow
    let score: CandidateScoreText
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: .space2XS) {
            HStack(spacing: .spaceXS) {
                if alignment == .leading { CandidatePhoto(row: row, side: .badgeM) }
                Text(verbatim: score.percent)
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: score.value))
                    .foregroundStyle(RaceStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if alignment == .trailing { CandidatePhoto(row: row, side: .badgeM) }
            }
            HStack(spacing: .space2XS) {
                if alignment == .trailing { PartyMark(row.party) }
                Text(verbatim: score.name.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if alignment == .leading { PartyMark(row.party) }
            }
        }
        .opacity(score.dimmed ? .opacitySoft : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: score.accessibility))
    }
}

struct CandidatePhoto: View {
    let row: RaceActivityRow
    let side: CGFloat

    var body: some View {
        Group {
            if let url = PortraitShelf.url(for: PortraitShelf.slug(row.name)),
                let image = UIImage(contentsOfFile: url.path(percentEncoded: false))
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(.circle)
            } else {
                PersonPortrait(slug: "", name: row.name, party: row.party, size: side)
            }
        }
        .overlay(alignment: .topTrailing) {
            if row.elected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: side * 0.32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, RaceStyle.accent)
            }
        }
        .accessibilityHidden(true)
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
            side: size == .lockScreen ? .badgeXL : .badgeM)
    }
}

private struct NumberBadge: View {
    let number: String
    let palette: PartyPalette
    let elected: Bool
    let side: CGFloat

    var body: some View {
        PartyStripes(palette: palette)
            .clipShape(.rect(cornerRadius: side * 0.28, style: .continuous))
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
                    .fill(RaceStyle.primary)
                    .frame(width: max(height, (proxy.size.width - .spaceHairline) * share))
                Capsule()
                    .fill(RaceStyle.secondary.opacity(.opacitySoft))
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
