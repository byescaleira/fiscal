import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceWinnerCard: View {
    @Environment(LiveResultsModel.self) private var results: LiveResultsModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let summary: RaceSummary
    let winner: RaceSummary.Contender
    let opensDetail: Bool

    var body: some View {
        let palette = PartyPalette.of(party: winner.candidate.party, fallback: 0)
        VStack(alignment: .leading, spacing: .spaceL) {
            RaceHeroHeader(summary: summary)
            if opensDetail, let results {
                NavigationLink {
                    RaceDetailScreen(raceID: summary.race.id).environment(results)
                } label: {
                    content.contentShape(.rect)
                }
                .buttonStyle(.plain)
            } else {
                content
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
        .overlay { CelebrationBurst(colors: [palette.primary, palette.secondary, .white]) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .fontDesign(.rounded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                verbatim: "\(summary.title), \(winner.candidate.name), \(summary.winnerText ?? "")")
        )
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.4)) {
                appeared = true
            }
        }
    }

    private var content: some View {
        VStack(spacing: .spaceL) {
            VStack(spacing: .spaceS) {
                PersonPortrait(
                    slug: winner.slug, name: winner.candidate.name,
                    party: winner.candidate.party, size: .badgeXL * 2
                )
                .overlay { Circle().strokeBorder(.white, lineWidth: .space2XS) }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.icon(.l, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.scoreboardAccent)
                        .symbolEffect(.bounce, value: appeared)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                Text("ELECTED")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, .spaceM)
                    .padding(.vertical, .space2XS)
                    .background(.white.opacity(.opacityTint), in: .capsule)
                Text(verbatim: winner.candidate.name)
                    .font(.title.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: .spaceS) {
                    PartyMark(winner.candidate.party)
                    Text(verbatim: winner.percent)
                        .font(.scoreboardNumber)
                        .monospacedDigit()
                }
                if let text = summary.winnerText {
                    Text(verbatim: text)
                        .font(.subheadline.weight(.semibold))
                        .opacity(.opacityStrong)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            ForEach(summary.others) { other in
                HStack(spacing: .spaceS) {
                    PersonPortrait(
                        slug: other.slug, name: other.candidate.name,
                        party: other.candidate.party, size: .badgeM)
                    Text(verbatim: other.candidate.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    PartyMark(other.candidate.party)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: other.percent)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.spaceS)
                .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
                .opacity(.opacityStrong)
            }
            RaceHeroBallots(summary: summary)
            Text(verbatim: summary.sourceText)
                .font(.caption.weight(.medium))
                .opacity(.opacityStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
