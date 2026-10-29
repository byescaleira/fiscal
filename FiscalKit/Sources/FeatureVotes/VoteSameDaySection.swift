import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteSameDaySection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        if !vote.sameDayVotes.isEmpty {
            Section {
                ForEach(vote.sameDayVotes) { item in
                    RouteLink(.vote(id: item.id)) { SameDayVoteRow(item: item) }
                }
            } header: {
                Label {
                    Text("Other Votes on This Bill That Day")
                } icon: {
                    Image(systemName: SameDayVotes.symbol)
                }
                .sectionTitle()
                .textCase(nil)
            } footer: {
                Text(verbatim: vote.sameDayFooter)
            }
        }
    }
}

private struct SameDayVoteRow: View {
    @Environment(VoteDetailModel.self) private var vote
    let item: VoteSummary.Related

    var body: some View {
        let outcome = VoteOutcome(approved: item.approved, nominal: item.nominal)
        AdaptiveRow(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: item.summary)
                    .font(.headline)
                Text(verbatim: vote.sameDayLine(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: .spaceS)
            Label(outcome.title, systemImage: outcome.symbol)
                .font(.chipLabel)
                .foregroundStyle(outcome.color)
                .lineLimit(1)
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .combine)
    }
}
