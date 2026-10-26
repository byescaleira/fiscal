import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension VoteDetailModel {
    public var sameDayVotes: [VoteSummary.Related] { vote?.sameDayVotes ?? [] }

    public func sameDayLine(_ item: VoteSummary.Related) -> String {
        let kind =
            item.nominal
            ? String(appLocalized: "Roll-call vote") : String(appLocalized: "Voice vote")
        return [item.time, kind].compactMap(\.self).joined(separator: " · ")
    }

    public var sameDayFooter: String {
        let base = String(
            appLocalized:
                "The Chamber and the Senate often vote on the same bill several times in one day: requests, amendments, the main text and the final wording. The lists show the vote on the text."
        )
        let hidden = (vote?.sameDayCount ?? 0) - sameDayVotes.count
        guard hidden > 0 else { return base }
        return base + " " + String(appLocalized: "\(hidden) more aren't listed here.")
    }
}

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
