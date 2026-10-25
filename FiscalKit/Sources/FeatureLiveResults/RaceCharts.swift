import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceStandings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    let contenders: [RaceSummary.Contender]
    let cut: Double?
    let showsVotes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ForEach(Array(contenders.enumerated()), id: \.element.id) { index, contender in
                RaceStandingRow(
                    contender: contender, cut: cut, showsVotes: showsVotes, revealed: revealed
                )
                .animation(reduceMotion ? nil : .chartReveal(index), value: revealed)
                .animation(reduceMotion ? nil : .smooth, value: contender.share)
            }
        }
        .onAppear { revealed = true }
    }
}

private struct RaceStandingRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let contender: RaceSummary.Contender
    let cut: Double?
    let showsVotes: Bool
    let revealed: Bool

    var body: some View {
        HStack(alignment: .center, spacing: .spaceM) {
            RaceCandidatePortrait(contender: contender, size: showsVotes ? .badgeL : .badgeM)
            VStack(alignment: .leading, spacing: .spaceXS) {
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: contender.candidate.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    PartyMark(contender.candidate.party)
                    Spacer(minLength: .spaceXS)
                    Text(verbatim: contender.percent)
                        .font(.headline.width(.condensed))
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity : .numericText(value: contender.candidate.percent))
                }
                RaceShareChart(contender: contender, cut: cut, revealed: revealed)
                if showsVotes {
                    Text(verbatim: contender.votes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity
                                : .numericText(value: Double(contender.candidate.votes)))
                }
            }
        }
        .opacity(contender.dimmed ? .opacityStrong : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: contender.accessibility))
    }
}

private struct RaceShareChart: View {
    let contender: RaceSummary.Contender
    let cut: Double?
    let revealed: Bool

    var body: some View {
        let color = PartyPalette.of(party: contender.candidate.party, fallback: contender.rank)
            .primary
        Chart {
            BarMark(
                xStart: .value("Start", 0), xEnd: .value("End", 100),
                y: .value("Candidate", contender.id), height: .fixed(.spaceS)
            )
            .foregroundStyle(Color.secondary.opacity(.opacityFill))
            .clipShape(.capsule)
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Share", revealed ? contender.share : 0),
                y: .value("Candidate", contender.id), height: .fixed(.spaceS)
            )
            .foregroundStyle(color.gradient)
            .clipShape(.capsule)
            if let cut {
                RuleMark(x: .value("Half", cut))
                    .foregroundStyle(.secondary)
                    .lineStyle(.chartAverage)
            }
        }
        .chartXScale(domain: 0...100, range: .plotDimension(endPadding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: .barHeight)
        .accessibilityHidden(true)
    }
}

struct RaceBallotChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var selected: RaceSummary.Ballot.Kind?
    let summary: RaceSummary

    var body: some View {
        let ballots = summary.ballots
        VStack(alignment: .leading, spacing: .spaceL) {
            Chart(ballots) { ballot in
                BarMark(
                    x: .value("Voters", revealed ? ballot.count : 0),
                    y: .value("Total", "total"), height: .fixed(.spaceL)
                )
                .foregroundStyle(Self.color(ballot.kind, selected: selected))
                .accessibilityLabel(ballot.title)
                .accessibilityValue("\(ballot.countText), \(ballot.percentText)")
            }
            .chartXScale(
                domain: 0...max(summary.ballotBase, 1), range: .plotDimension(endPadding: 0)
            )
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .clipShape(.capsule)
            .frame(height: .spaceL)
            Grid(alignment: .leading, horizontalSpacing: .spaceL, verticalSpacing: .spaceM) {
                ForEach(Self.rows(ballots), id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { ballot in
                            RaceBallotLegend(
                                ballot: ballot, color: Self.color(ballot.kind, selected: nil),
                                isSelected: selected == ballot.kind
                            ) {
                                selected = selected == ballot.kind ? nil : ballot.kind
                            }
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    static func rows(_ ballots: [RaceSummary.Ballot]) -> [[RaceSummary.Ballot]] {
        stride(from: 0, to: ballots.count, by: 2).map {
            Array(ballots[$0..<min($0 + 2, ballots.count)])
        }
    }

    static func color(_ kind: RaceSummary.Ballot.Kind, selected: RaceSummary.Ballot.Kind?)
        -> Color
    {
        let base: Color =
            switch kind {
            case .valid: Color.primary.opacity(.opacityStrong)
            case .blank: Color.secondary
            case .null: Color.primary.opacity(.opacitySoft)
            case .abstention: Color.primary.opacity(.opacityFill)
            }
        guard let selected, selected != kind else { return base }
        return base.opacity(.opacitySoft)
    }
}

private struct RaceBallotLegend: View {
    let ballot: RaceSummary.Ballot
    let color: Color
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: .spaceS) {
                RoundedRectangle(cornerRadius: .space2XS)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: .space2XS)
                            .strokeBorder(
                                Color.secondary.opacity(.opacitySoft), lineWidth: .chartRuleWidth)
                    }
                    .frame(width: .spaceM, height: .spaceM)
                    .padding(.top, .space2XS)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Label(ballot.title, systemImage: ballot.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(verbatim: ballot.percentText)
                        .font(.amountRow.width(.condensed))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: ballot.share))
                    Text(verbatim: ballot.countText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spaceS)
            .background(
                isSelected ? Color.secondary.opacity(.opacityFill) : .clear,
                in: .rect(cornerRadius: .radiusS)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ballot.title))
        .accessibilityValue(Text(verbatim: "\(ballot.countText), \(ballot.percentText)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
