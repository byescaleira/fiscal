import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PastRoundSections: View {
    let breakdown: PastRoundBreakdown

    var body: some View {
        PastHeroSection(breakdown: breakdown)
        Section {
            CandidateBarsChart(bars: breakdown.bars)
                .padding(.vertical, .spaceXS)
        } header: {
            Text("Votes by candidate").sectionTitle()
        } footer: {
            Text(verbatim: barsFooter)
        }
        if !breakdown.tiles.isEmpty {
            Section {
                WinnerTileMap(breakdown: breakdown)
                    .padding(.vertical, .spaceXS)
            } header: {
                Text("Who won in each state").sectionTitle()
            } footer: {
                Text(
                    "Each square is a state, in the color of the party of the most voted candidate there. Votes abroad count in the national total."
                )
            }
        }
        if !breakdown.slices.isEmpty {
            Section {
                TurnoutChart(slices: breakdown.slices)
                    .padding(.vertical, .spaceXS)
            } header: {
                Text("Valid, blank, null and abstention").sectionTitle()
            } footer: {
                Text(verbatim: turnoutFooter)
            }
        }
    }

    private var barsFooter: String {
        var lines = [
            String(appLocalized: "Percentages over valid votes, as the TSE publishes them.")
        ]
        if let note = breakdown.race.note { lines.append(note) }
        if breakdown.annulled > 0 {
            lines.append(
                String(
                    appLocalized:
                        "\(RaceText.votes(breakdown.annulled)) votes for candidates whose candidacy was not valid at the count are left out."
                ))
        }
        lines.append(breakdown.sourceLine)
        return lines.joined(separator: " ")
    }

    private var turnoutFooter: String {
        let base = String(appLocalized: "Shares of the registered electorate.")
        guard let line = breakdown.electorateLine else { return base }
        return "\(base) \(line)."
    }
}

private struct PastHeroSection: View {
    let breakdown: PastRoundBreakdown

    var body: some View {
        Section {
            if let leader = breakdown.leader {
                PastHeroCard(breakdown: breakdown, leader: leader)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }
}

private struct PastHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let breakdown: PastRoundBreakdown
    let leader: PastCandidate

    var body: some View {
        let palette = PartyPalette.of(party: leader.party, fallback: 0)
        VStack(spacing: .spaceL) {
            HStack {
                Text(verbatim: breakdown.title.uppercased(with: .app))
                    .font(.caption.weight(.heavy))
                Spacer(minLength: .spaceS)
                Text(verbatim: breakdown.roundLine)
                    .font(.caption.weight(.semibold))
                    .opacity(.opacityStrong)
            }
            VStack(spacing: .spaceS) {
                PersonPortrait(
                    slug: MemoryText.slug(leader.ballotName),
                    name: MemoryText.name(leader.ballotName),
                    party: leader.party, size: .badgeXL * 2
                )
                .overlay { Circle().strokeBorder(.white, lineWidth: .space2XS) }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                Text(verbatim: breakdown.outcome)
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, .spaceM)
                    .padding(.vertical, .space2XS)
                    .background(.white.opacity(.opacityTint), in: .capsule)
                Text(verbatim: names)
                    .font(.emphasis(.title, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                HStack(spacing: .spaceS) {
                    PartyMark(leader.party)
                    Text(verbatim: MemoryText.percent(leader.share))
                        .font(.scoreboardTitle)
                        .monospacedDigit()
                }
                Text(verbatim: MemoryText.votes(leader.votes))
                    .font(.subheadline.weight(.semibold))
                    .opacity(.opacityStrong)
            }
            .frame(maxWidth: .infinity)
            ForEach(breakdown.others) { other in
                HStack(spacing: .spaceS) {
                    PersonPortrait(
                        slug: MemoryText.slug(other.ballotName),
                        name: MemoryText.name(other.ballotName),
                        party: other.party, size: .badgeM)
                    Text(verbatim: MemoryText.name(other.ballotName))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(verbatim: other.party)
                        .font(.caption.weight(.bold))
                    Spacer(minLength: .spaceS)
                    Text(verbatim: MemoryText.percent(other.share))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.spaceS)
                .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
                .opacity(.opacityStrong)
            }
            if let turnout = breakdown.turnoutHero {
                Text("Turnout: \(turnout) of the electorate")
                    .font(.caption.weight(.medium))
                    .opacity(.opacityStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .background {
            ZStack {
                LinearGradient(
                    colors: [palette.primary, palette.secondary], startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                Color.scoreboard.opacity(.opacitySoft)
            }
        }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.4)) {
                appeared = true
            }
        }
    }

    private var names: String {
        let elected = breakdown.winners.filter(\.elected)
        guard elected.count > 1 else { return MemoryText.name(leader.ballotName) }
        return elected.map { MemoryText.name($0.ballotName) }.joined(separator: " e ")
    }
}

struct RoundMenu: View {
    let rounds: [Int]
    @Binding var selection: Int?

    var body: some View {
        if rounds.count > 1 {
            Menu {
                Picker("Round", selection: $selection) {
                    ForEach(rounds, id: \.self) { round in
                        Text("Round \(round)").tag(Optional(round))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Round", systemImage: "list.number")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.primary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .tint(Color.primary)
        }
    }
}

struct PastRaceRow: View {
    let race: PastRaceSummary
    let winners: [PastPick]
    let detail: String

    var body: some View {
        HStack(spacing: .spaceM) {
            Text(verbatim: race.scope.uppercased(with: .app))
                .font(.emphasis(.subheadline, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.secondary)
                .frame(width: .badgeM, height: .badgeM)
                .background(.subtleFill, in: .rect(cornerRadius: .radiusS))
            VStack(alignment: .leading, spacing: .spaceHairline) {
                ForEach(winners) { winner in
                    HStack(spacing: .spaceS) {
                        Text(verbatim: MemoryText.name(winner.ballotName))
                            .font(.rowTitle)
                            .lineLimit(1)
                        PartyMark(winner.party)
                    }
                }
                Text(verbatim: detail)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: .spaceS)
            if let share = winners.first?.share {
                Text(verbatim: MemoryText.shortPercent(share))
                    .font(.emphasis(.headline, weight: .bold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
