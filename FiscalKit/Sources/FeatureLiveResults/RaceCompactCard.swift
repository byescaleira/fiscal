import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceCompactCard: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race

    var body: some View {
        let summary = RaceSummary(race: race)
        NavigationLink {
            RaceDetailScreen(raceID: race.id).environment(results)
        } label: {
            VStack(alignment: .leading, spacing: .spaceM) {
                RaceCompactHeader(summary: summary)
                if summary.isDuel {
                    RaceDuel(summary: summary)
                } else {
                    RaceStandings(
                        contenders: summary.compactContenders, cut: summary.majorityCut,
                        showsVotes: false)
                    if let hidden = summary.hiddenText {
                        Text(verbatim: hidden)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                RaceCompactFooter(summary: summary)
            }
            .padding(.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
            .contentShape(.rect(cornerRadius: .radiusGroup))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: "\(summary.accessibilityLabel), \(summary.ballotAccessibility)")
        )
        .accessibilityHint(Text("Shows every candidate and the blank and null votes"))
        .contextMenu {
            if results.showsFollow(race) {
                Button {
                    Task { await results.toggle(race) }
                } label: {
                    Label(
                        results.isFollowing(race) ? "Stop Following" : "Follow on Lock Screen",
                        systemImage: results.isFollowing(race) ? "lock.slash" : "lock.iphone")
                }
            }
        }
    }
}

private struct RaceCompactHeader: View {
    @Environment(LiveResultsModel.self) private var results
    let summary: RaceSummary

    var body: some View {
        HStack(alignment: .center, spacing: .spaceM) {
            Text(verbatim: summary.race.uf.uppercased())
                .font(.subheadline.weight(.heavy).width(.condensed))
                .foregroundStyle(.secondary)
                .frame(width: .badgeM, height: .badgeM)
                .background(.subtleFill, in: .rect(cornerRadius: .radiusS))
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: summary.scope)
                    .font(.headline)
                    .lineLimit(1)
                Text(verbatim: "\(summary.office) · \(summary.roundText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: .spaceS)
            if results.isFollowing(summary.race) {
                Image(systemName: "lock.iphone")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            RaceStatusBadge(summary: summary)
        }
    }
}

struct RaceStatusBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        if summary.race.final {
            Label("Final", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.retroTeal)
                .labelStyle(.titleAndIcon)
        } else if summary.hasStarted {
            VStack(alignment: .trailing, spacing: .space2XS) {
                Text(verbatim: summary.countedText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(
                        reduceMotion
                            ? .identity : .numericText(value: summary.race.sections.percent))
                ProgressBar(value: summary.countedFraction, color: .retroTeal)
                    .frame(width: .badgeL)
            }
        } else {
            Image(systemName: "clock")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RaceDuel: View {
    let summary: RaceSummary

    var body: some View {
        VStack(spacing: .spaceS) {
            HStack(alignment: .center, spacing: .spaceS) {
                if let first = summary.sides.first {
                    RaceDuelSide(contender: first, trailing: false)
                }
                Spacer(minLength: .spaceS)
                if summary.sides.count > 1, let second = summary.sides.last {
                    RaceDuelSide(contender: second, trailing: true)
                }
            }
            RaceDuelSplit(summary: summary)
        }
    }
}

private struct RaceDuelSide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let contender: RaceSummary.Contender
    let trailing: Bool

    var body: some View {
        HStack(spacing: .spaceS) {
            if !trailing { portrait }
            VStack(alignment: trailing ? .trailing : .leading, spacing: .spaceHairline) {
                Text(verbatim: contender.percent)
                    .font(.amountTitle.width(.condensed))
                    .monospacedDigit()
                    .contentTransition(
                        reduceMotion ? .identity : .numericText(value: contender.candidate.percent)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(verbatim: contender.candidate.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                PartyMark(contender.candidate.party)
            }
            if trailing { portrait }
        }
        .opacity(contender.dimmed ? .opacitySoft + .opacityTint : 1)
    }

    private var portrait: some View {
        RaceCandidatePortrait(contender: contender, size: .badgeL)
    }
}

struct RaceCandidatePortrait: View {
    let contender: RaceSummary.Contender
    let size: CGFloat

    var body: some View {
        PersonPortrait(
            slug: contender.slug, name: contender.candidate.name,
            party: contender.candidate.party, size: size
        )
        .overlay {
            Circle().strokeBorder(
                PartyPalette.of(party: contender.candidate.party, fallback: contender.rank)
                    .primary,
                lineWidth: .spaceHairline)
        }
        .overlay(alignment: .topTrailing) {
            if contender.candidate.elected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.icon(.xs, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.retroTeal)
                    .symbolEffect(.bounce, value: contender.candidate.elected)
            }
        }
    }
}

private struct RaceDuelSplit: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        let share = summary.splitShare
        let first = PartyPalette.of(party: summary.sides.first?.candidate.party ?? "", fallback: 0)
        let second = PartyPalette.of(party: summary.sides.last?.candidate.party ?? "", fallback: 1)
        GeometryReader { proxy in
            HStack(spacing: .spaceHairline) {
                Capsule()
                    .fill(
                        summary.hasStarted ? first.primary : Color.secondary.opacity(.opacityFill)
                    )
                    .frame(width: max(.spaceS, (proxy.size.width - .spaceHairline) * share))
                Capsule()
                    .fill(
                        summary.hasStarted ? second.primary : Color.secondary.opacity(.opacityFill))
            }
        }
        .frame(height: .spaceXS)
        .animation(reduceMotion ? nil : .smooth(duration: 1), value: share)
        .accessibilityHidden(true)
    }
}

private struct RaceCompactFooter: View {
    let summary: RaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Image(
                    systemName: summary.race.elected == nil ? "chart.bar.xaxis" : "checkmark.seal"
                )
                .foregroundStyle(summary.race.elected == nil ? Color.secondary : Color.retroTeal)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: summary.marginText)
                        .font(.subheadline.weight(.semibold))
                    Text(verbatim: summary.ballotLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
