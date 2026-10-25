import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceHeroCard: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race
    let opensDetail: Bool

    var body: some View {
        let summary = RaceSummary(race: race)
        VStack(alignment: .leading, spacing: .spaceL) {
            RaceHeroHeader(summary: summary)
            if opensDetail {
                NavigationLink {
                    RaceDetailScreen(raceID: race.id).environment(results)
                } label: {
                    RaceHeroBody(summary: summary, showsChevron: true)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: summary.accessibilityLabel))
                .accessibilityHint(Text("Shows every candidate and the blank and null votes"))
            } else {
                RaceHeroBody(summary: summary, showsChevron: false)
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .background { RaceHeroBackground(summary: summary) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .fontDesign(.rounded)
        .opacity(results.isOffline ? .opacityStrong : 1)
    }
}

private struct RaceHeroBody: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: RaceSummary
    let showsChevron: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            if dynamicTypeSize.isAccessibilitySize {
                RaceHeroStacked(summary: summary)
            } else {
                RaceHeroScoreboard(summary: summary)
            }
            RaceHeroSplit(summary: summary)
            if let trailing = summary.trailingText {
                Text(verbatim: trailing)
                    .font(.caption.weight(.semibold))
                    .opacity(.opacityStrong)
                    .lineLimit(2)
            }
            RaceHeroBallots(summary: summary)
            RaceHeroLastPlay(summary: summary, showsChevron: showsChevron)
        }
    }
}

private struct RaceHeroBackground: View {
    let summary: RaceSummary

    var body: some View {
        let sides = summary.sides
        let first = PartyPalette.of(party: sides.first?.candidate.party ?? "", fallback: 0)
        let second = PartyPalette.of(party: sides.last?.candidate.party ?? "", fallback: 1)
        ZStack {
            LinearGradient(
                colors: [first.primary, second.primary], startPoint: .leading,
                endPoint: .trailing)
            Color.scoreboard.opacity(.opacitySoft)
        }
        .accessibilityHidden(true)
    }
}

private struct RaceHeroHeader: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let summary: RaceSummary

    var body: some View {
        HStack(alignment: .center, spacing: .spaceS) {
            Label {
                Text(verbatim: summary.statusText.uppercased())
            } icon: {
                Image(
                    systemName: summary.race.final
                        ? "checkmark.seal" : "dot.radiowaves.left.and.right"
                )
                .symbolEffect(
                    .pulse, isActive: !reduceMotion && summary.hasStarted && !summary.race.final)
            }
            .font(.caption.weight(.heavy))
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(.white.opacity(.opacityTint), in: .capsule)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: summary.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(verbatim: summary.roundText)
                    .font(.caption.weight(.medium))
                    .opacity(.opacityStrong)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: .spaceS)
            if results.showsFollow(summary.race) {
                RaceHeroFollow(race: summary.race)
            }
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(.race(id: summary.race.id)), in: section)
            }
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .buttonStyle(.plain)
            .frame(width: .badgeL, height: .badgeL)
            .background(.white.opacity(.opacityTint), in: .circle)
        }
    }
}

private struct RaceHeroFollow: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race

    var body: some View {
        let following = results.isFollowing(race)
        Button {
            Task { await results.toggle(race) }
        } label: {
            Label(
                following ? "Stop Following" : "Follow on Lock Screen",
                systemImage: following ? "lock.slash" : "lock.iphone"
            )
            .labelStyle(.iconOnly)
            .contentTransition(.symbolEffect(.replace))
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.plain)
        .frame(width: .badgeL, height: .badgeL)
        .background(.white.opacity(following ? .opacitySoft : .opacityTint), in: .circle)
        .disabled(!results.canToggle(race))
        .sensoryFeedback(.selection, trigger: following)
        .accessibilityLabel(Text(verbatim: results.followLabel(race)))
        .accessibilityHint("Shows the count on the Lock Screen and in the Dynamic Island.")
    }
}

private struct RaceHeroScoreboard: View {
    let summary: RaceSummary

    var body: some View {
        HStack(alignment: .center, spacing: .spaceS) {
            if let first = summary.sides.first {
                RaceHeroSide(contender: first, alignment: .leading)
            }
            Spacer(minLength: 0)
            RaceHeroCenter(summary: summary)
            Spacer(minLength: 0)
            if summary.sides.count > 1, let second = summary.sides.last {
                RaceHeroSide(contender: second, alignment: .trailing)
            }
        }
    }
}

private struct RaceHeroSide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let contender: RaceSummary.Contender
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: .spaceXS) {
            RaceHeroPortrait(contender: contender)
            Text(verbatim: contender.percent)
                .font(.scoreboardNumber)
                .monospacedDigit()
                .contentTransition(
                    reduceMotion ? .identity : .numericText(value: contender.candidate.percent)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(verbatim: contender.candidate.name.uppercased())
                .font(.caption2.weight(.heavy))
                .opacity(.opacityStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            PartyMark(contender.candidate.party)
        }
        .opacity(contender.dimmed ? .opacitySoft + .opacityTint : 1)
    }
}

private struct RaceHeroPortrait: View {
    let contender: RaceSummary.Contender

    var body: some View {
        PersonPortrait(
            slug: contender.slug, name: contender.candidate.name,
            party: contender.candidate.party, size: .badgeXL
        )
        .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
        .overlay(alignment: .topTrailing) {
            if contender.candidate.elected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.icon(.s, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.scoreboardAccent)
                    .symbolEffect(.bounce, value: contender.candidate.elected)
            }
        }
    }
}

private struct RaceHeroCenter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        VStack(spacing: .space2XS) {
            Text(verbatim: summary.race.final ? String(appLocalized: "Final") : summary.countedText)
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .contentTransition(
                    reduceMotion ? .identity : .numericText(value: summary.race.sections.percent)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(summary.race.final ? "TSE" : "counted")
                .font(.caption2.weight(.semibold))
                .opacity(.opacityStrong)
            ProgressBar(value: summary.countedFraction, color: .white)
                .frame(width: .badgeXL)
        }
        .frame(minWidth: .badgeXL + .spaceL)
    }
}

private struct RaceHeroStacked: View {
    let summary: RaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ForEach(summary.sides) { contender in
                HStack(spacing: .spaceM) {
                    RaceHeroPortrait(contender: contender)
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: contender.percent)
                            .font(.amountTitle)
                            .monospacedDigit()
                        Text(verbatim: contender.candidate.name)
                            .font(.headline)
                        PartyMark(contender.candidate.party)
                    }
                }
                .opacity(contender.dimmed ? .opacitySoft + .opacityTint : 1)
            }
            Text(
                verbatim: summary.race.final
                    ? summary.statusText
                    : String(appLocalized: "\(summary.countedText) counted")
            )
            .font(.headline)
        }
    }
}

private struct RaceHeroSplit: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        let share = summary.splitShare
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

private struct RaceHeroBallots: View {
    let summary: RaceSummary

    var body: some View {
        let ballots = summary.ballots
        if !ballots.isEmpty {
            VStack(alignment: .leading, spacing: .spaceXS) {
                TallyBar(
                    segments: ballots.map { ballot in
                        TallyBar.Segment(
                            id: ballot.id, value: Double(ballot.count),
                            color: .white.opacity(Self.opacity(ballot.kind)))
                    }, height: .space2XS)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: .spaceM) { items(ballots) }
                    Grid(
                        alignment: .leading, horizontalSpacing: .spaceM, verticalSpacing: .space2XS
                    ) {
                        GridRow { items(Array(ballots.prefix(2))) }
                        GridRow { items(Array(ballots.dropFirst(2))) }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: summary.ballotAccessibility))
        }
    }

    @ViewBuilder private func items(_ ballots: [RaceSummary.Ballot]) -> some View {
        ForEach(ballots) { ballot in
            HStack(spacing: .space2XS) {
                Circle()
                    .fill(.white.opacity(Self.opacity(ballot.kind)))
                    .frame(width: .spaceXS, height: .spaceXS)
                Text(verbatim: ballot.title)
                    .opacity(.opacityStrong)
                Text(verbatim: ballot.percentText)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
        }
    }

    static func opacity(_ kind: RaceSummary.Ballot.Kind) -> Double {
        switch kind {
        case .valid: 1
        case .blank: .opacityStrong - .opacityTint
        case .null: .opacitySoft
        case .abstention: .opacityTint
        }
    }
}

private struct RaceHeroLastPlay: View {
    let summary: RaceSummary
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: .spaceS) {
            Capsule()
                .fill(.white)
                .frame(width: .space2XS)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: summary.marginText)
                    .font(.subheadline.weight(.bold))
                Text(verbatim: summary.sourceText)
                    .font(.caption.weight(.medium))
                    .opacity(.opacityStrong)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .opacity(.opacityStrong)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
