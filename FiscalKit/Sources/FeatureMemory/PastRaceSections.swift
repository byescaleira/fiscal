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
    let breakdown: PastRoundBreakdown
    let leader: PastCandidate

    var body: some View {
        VStack(spacing: .spaceL) {
            HStack {
                Text(verbatim: breakdown.title.uppercased(with: .app))
                    .font(.chipLabel)
                Spacer(minLength: .spaceS)
                Text(verbatim: breakdown.roundLine)
                    .font(.caption.weight(.semibold))
                    .opacity(.opacityStrong)
            }
            PastHeroLeader(breakdown: breakdown, leader: leader)
            ForEach(breakdown.others) { other in
                PastOtherRow(
                    name: other.displayName, party: other.party, share: other.shareText,
                    portraitSlug: other.portraitSlug)
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
        .background { PartyCardBackground(party: leader.party) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
    }
}

private struct PastHeroLeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let breakdown: PastRoundBreakdown
    let leader: PastCandidate

    var body: some View {
        VStack(spacing: .spaceS) {
            PersonPortrait(
                slug: leader.portraitSlug, name: leader.displayName, party: leader.party,
                size: .medallion
            )
            .overlay { Circle().strokeBorder(.white, lineWidth: .space2XS) }
            .scaleEffect(appeared ? 1 : .heroPortraitEntryScale)
            .opacity(appeared ? 1 : 0)
            Chip(breakdown.outcome, color: .white, shape: .capsule)
                .environment(\.colorScheme, .dark)
            Text(verbatim: breakdown.leaderNames)
                .font(.emphasis(.title, weight: .heavy))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            HStack(spacing: .spaceS) {
                PartyMark(leader.party)
                Text(verbatim: leader.shareText)
                    .font(.scoreboardTitle)
                    .monospacedDigit()
            }
            Text(verbatim: leader.votesText)
                .font(.subheadline.weight(.semibold))
                .opacity(.opacityStrong)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.4)) {
                appeared = true
            }
        }
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
                        Text(verbatim: winner.displayName)
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
            if let share = winners.first?.shortShareText {
                Text(verbatim: share)
                    .font(.emphasis(.headline, weight: .bold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
