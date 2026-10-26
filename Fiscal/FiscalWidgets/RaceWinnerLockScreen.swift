import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct WinnerLockScreen: View {
    let board: RaceBoard
    let winner: RaceActivityRow

    var body: some View {
        let score = board.score(winner)
        VStack(spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                Label("ELECTED", systemImage: "checkmark.seal.fill")
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
            HStack(spacing: .spaceM) {
                CandidatePhoto(row: winner, side: .badgeXL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: winner.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(RaceStyle.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    PartyMark(winner.party)
                }
                Spacer(minLength: .spaceS)
                Text(verbatim: score.percent)
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .foregroundStyle(RaceStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ForEach(board.rows.filter { $0.number != winner.number }.prefix(1)) { other in
                HStack(spacing: .spaceS) {
                    Text(verbatim: other.name)
                        .lineLimit(1)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: board.score(other).percent)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaceStyle.secondary)
            }
        }
        .padding(.horizontal, .spaceXL)
        .padding(.vertical, .spaceL)
        .frame(maxWidth: .infinity)
        .fontDesign(.rounded)
        .partyMarksStill()
        .accessibilityElement(children: .combine)
    }
}
