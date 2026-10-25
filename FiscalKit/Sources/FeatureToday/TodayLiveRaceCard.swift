import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayLiveRaceCard: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let board: TodayRaceBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            RaceCardHeader(board: board) { open(.share(.race(id: board.race.id)), in: section) }
            Button {
                open(.races, in: section)
            } label: {
                VStack(alignment: .leading, spacing: .spaceL) {
                    if dynamicTypeSize.isAccessibilitySize {
                        RaceStackedScore(board: board)
                    } else {
                        RaceScoreboard(board: board)
                    }
                    RaceShareBar(board: board)
                    RaceLastPlay(board: board)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: board.accessibilityLabel))
            .accessibilityHint(Text("Opens the live count"))
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .background { RaceBackground(board: board) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .fontDesign(.rounded)
        .opacity(board.isStale ? .opacityStrong : 1)
    }
}

private struct RaceBackground: View {
    let board: TodayRaceBoard

    var body: some View {
        let sides = board.sides
        let first = PartyPalette.of(party: sides.first?.candidate.party ?? "", fallback: 0)
        let second = PartyPalette.of(party: sides.last?.candidate.party ?? "", fallback: 1)
        ZStack {
            LinearGradient(
                colors: [first.primary, second.primary], startPoint: .leading,
                endPoint: .trailing)
            Color.scoreboard.opacity(.opacitySoft)
        }
    }
}

private struct RaceCardHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let board: TodayRaceBoard
    let share: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: .spaceS) {
            Label {
                Text(verbatim: board.statusText.uppercased())
            } icon: {
                Image(
                    systemName: board.race.final
                        ? "checkmark.seal" : "dot.radiowaves.left.and.right"
                )
                .symbolEffect(.pulse, isActive: !reduceMotion && !board.race.final)
            }
            .font(.caption.weight(.heavy))
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(.white.opacity(.opacityTint), in: .capsule)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: board.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(verbatim: board.roundText)
                    .font(.caption.weight(.medium))
                    .opacity(.opacityStrong)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: .spaceS)
            Button("Share", systemImage: "square.and.arrow.up", action: share)
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .buttonStyle(.plain)
                .frame(width: .badgeL, height: .badgeL)
                .background(.white.opacity(.opacityTint), in: .circle)
        }
    }
}

private struct RaceScoreboard: View {
    let board: TodayRaceBoard

    var body: some View {
        HStack(alignment: .center, spacing: .spaceS) {
            if let first = board.sides.first {
                RaceSideColumn(side: first, alignment: .leading, race: board.race)
            }
            Spacer(minLength: 0)
            RaceCenterStatus(board: board)
            Spacer(minLength: 0)
            if board.sides.count > 1, let second = board.sides.last {
                RaceSideColumn(side: second, alignment: .trailing, race: board.race)
            }
        }
    }
}

private struct RaceSideColumn: View {
    let side: TodayRaceBoard.Side
    let alignment: HorizontalAlignment
    let race: Race

    var body: some View {
        VStack(alignment: alignment, spacing: .spaceXS) {
            RacePortrait(side: side)
            Text(verbatim: side.percent)
                .font(.scoreboardNumber)
                .monospacedDigit()
                .contentTransition(.numericText(value: side.candidate.percent))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(verbatim: side.candidate.name.uppercased())
                .font(.caption2.weight(.heavy))
                .opacity(.opacityStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            PartyMark(side.candidate.party)
        }
        .opacity(side.dimmed ? .opacitySoft + .opacityTint : 1)
    }
}

private struct RacePortrait: View {
    let side: TodayRaceBoard.Side

    var body: some View {
        PersonPortrait(
            slug: side.slug, name: side.candidate.name, party: side.candidate.party,
            size: .badgeXL
        )
        .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
        .overlay(alignment: .topTrailing) {
            if side.candidate.elected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.icon(.s, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.scoreboardAccent)
            }
        }
    }
}

private struct RaceCenterStatus: View {
    let board: TodayRaceBoard

    var body: some View {
        VStack(spacing: .space2XS) {
            Text(verbatim: board.centerValue)
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText(value: board.race.sections.percent))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: board.centerCaption)
                .font(.caption2.weight(.semibold))
                .opacity(.opacityStrong)
            ProgressBar(value: board.countedFraction, color: .white)
                .frame(width: .badgeXL)
        }
        .frame(minWidth: .badgeXL + .spaceL)
    }
}

private struct RaceStackedScore: View {
    let board: TodayRaceBoard

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ForEach(board.sides) { side in
                HStack(spacing: .spaceM) {
                    RacePortrait(side: side)
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: side.percent)
                            .font(.amountTitle)
                            .monospacedDigit()
                        Text(verbatim: side.candidate.name)
                            .font(.headline)
                        PartyMark(side.candidate.party)
                    }
                }
                .opacity(side.dimmed ? .opacitySoft + .opacityTint : 1)
            }
            Text(verbatim: "\(board.centerValue) \(board.centerCaption)")
                .font(.headline)
        }
    }
}

private struct RaceShareBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let board: TodayRaceBoard

    var body: some View {
        let sides = board.sides
        let first = sides.first?.candidate.percent ?? 0
        let second = sides.dropFirst().first?.candidate.percent ?? 0
        let total = first + second
        let share = total > 0 ? first / total : 0.5
        GeometryReader { proxy in
            HStack(spacing: .spaceHairline) {
                Capsule()
                    .fill(.white)
                    .frame(width: max(.spaceS, (proxy.size.width - .spaceHairline) * share))
                Capsule()
                    .fill(.white.opacity(.opacitySoft))
            }
        }
        .frame(height: .spaceS)
        .animation(reduceMotion ? nil : .smooth(duration: 1), value: share)
        .accessibilityHidden(true)
    }
}

private struct RaceLastPlay: View {
    let board: TodayRaceBoard

    var body: some View {
        HStack(spacing: .spaceS) {
            Capsule()
                .fill(.white)
                .frame(width: .space2XS)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: board.marginText)
                    .font(.subheadline.weight(.bold))
                Text(verbatim: board.sourceText)
                    .font(.caption.weight(.medium))
                    .opacity(.opacityStrong)
                if let others = board.othersText {
                    Text(verbatim: others)
                        .font(.caption.weight(.medium))
                        .opacity(.opacityStrong)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.bold))
                .opacity(.opacityStrong)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
