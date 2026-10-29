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
                .widgetURL(IntegrationLink.races)
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
            .widgetURL(IntegrationLink.races)
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
                    .minimumScaleFactor(.widgetLabelShrink)
            }
            HStack(alignment: .center, spacing: .spaceS) {
                if let first = board.first {
                    SideColumn(row: first, score: board.score(first), alignment: .leading)
                }
                Spacer(minLength: 0)
                VStack(spacing: .space2XS) {
                    Text(verbatim: board.centerValue)
                        .font(.emphasis(.subheadline, weight: .heavy))
                        .foregroundStyle(RaceStyle.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: board.state.sectionsPercent))
                    Text(verbatim: board.centerCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RaceStyle.secondary)
                    ProgressBar(value: board.countedFraction, color: RaceStyle.primary)
                        .frame(width: .badgeL)
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
                    .minimumScaleFactor(.widgetScoreShrink)
                if alignment == .trailing { CandidatePhoto(row: row, side: .badgeM) }
            }
            HStack(spacing: .space2XS) {
                if alignment == .trailing { PartyMark(row.party) }
                Text(verbatim: score.name.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(.widgetScoreShrink)
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
                    .font(.electedSeal(side))
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
                    .font(size == .lockScreen ? .candidatePercentLarge : .candidatePercentCompact)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: row.value))
                    .foregroundStyle(RaceStyle.primary)
                    .minimumScaleFactor(.widgetScoreShrink)
                    .lineLimit(1)
                Text(verbatim: row.name)
                    .font(
                        size == .lockScreen
                            ? .subheadline.weight(.semibold) : .caption2.weight(.semibold)
                    )
                    .foregroundStyle(RaceStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(.widgetNameShrink)
            }
            if alignment == .trailing { badge }
        }
        .opacity(row.dimmed ? .widgetDimmed : 1)
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
            .clipShape(.rect(cornerRadius: side * .ballotCornerScale, style: .continuous))
            .frame(width: side, height: side)
            .overlay {
                Text(verbatim: number)
                    .font(.ballotNumber(side))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(.widgetScoreShrink)
            }
            .overlay(alignment: .topTrailing) {
                if elected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.ballotSeal(side))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, RaceStyle.accent)
                        .offset(
                            x: side * .ballotSealOffsetScale, y: -side * .ballotSealOffsetScale)
                }
            }
    }
}

private struct ShareBar: View {
    let board: RaceBoard
    let height: CGFloat

    var body: some View {
        let shares = board.splitShares
        TallyBar(
            segments: [
                .init(id: "first", value: shares.first, color: RaceStyle.primary),
                .init(
                    id: "second", value: shares.second,
                    color: RaceStyle.secondary.opacity(.opacitySoft)),
            ], height: height)
    }
}

private struct BoardFooter: View {
    let board: RaceBoard

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: board.countText)
                .font(.boardCount)
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

private struct IslandWidthReader<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        if #available(iOS 27, *) {
            LimitedIslandWidth(content: content)
        } else {
            content(false)
        }
    }
}

@available(iOS 27, *)
private struct LimitedIslandWidth<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    let content: (Bool) -> Content

    var body: some View {
        content(limited)
    }
}

private struct CompactLeading: View {
    let board: RaceBoard

    var body: some View {
        IslandWidthReader { limited in
            CompactLeadingContent(board: board, limited: limited)
        }
    }
}

private struct CompactLeadingContent: View {
    let board: RaceBoard
    let limited: Bool

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
    let board: RaceBoard

    var body: some View {
        IslandWidthReader { limited in
            if !limited, let second = board.second {
                CompactStanding(score: board.score(second))
                    .accessibilityLabel(Text(verbatim: board.score(second).accessibility))
            }
        }
    }
}

private struct CompactStanding: View {
    let score: CandidateScoreText

    var body: some View {
        HStack(spacing: .space2XS) {
            NumberBadge(
                number: score.number, palette: score.palette, elected: false, side: .islandBadge)
            Text(verbatim: score.shortPercent)
                .font(.islandScore)
                .foregroundStyle(RaceStyle.primary)
                .contentTransition(.numericText())
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(.widgetNameShrink)
    }
}
