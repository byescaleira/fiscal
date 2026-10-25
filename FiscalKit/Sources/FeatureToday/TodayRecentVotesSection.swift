import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayRecentVotesSection: View {
    @Environment(TodayModel.self) private var today
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?

    var body: some View {
        let votes = today.recent
        TodaySection(
            "Recent Votes", source: today.recentSource,
            action: ("See All", { navigation?.selectedSection = .votes })
        ) {
            if votes.isEmpty {
                HStack(alignment: .top, spacing: .spaceM) {
                    ThemeTile(symbol: "checkmark.square")
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text("No floor votes yet").font(.headline)
                        Text(
                            "The latest votes of the Chamber and the Senate show up here, with the full count."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.spaceL)
                .todayCard()
                .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 0) {
                    ForEach(votes) { vote in
                        RecentVoteRow(vote: vote)
                        if vote.id != votes.last?.id {
                            Divider().padding(.leading, .spaceL)
                        }
                    }
                }
                .todayCard()
            }
        }
    }
}

private struct RecentVoteRow: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let vote: VoteSummary

    var body: some View {
        RouteButton(route: .vote(id: vote.id)) {
            VStack(alignment: .leading, spacing: .spaceS) {
                AdaptiveStack(alignment: .center, spacing: .spaceS) {
                    if let theme = vote.themes.first { ThemeTag(theme: theme) }
                    Text(verbatim: TodayText.voteLine(vote))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(verbatim: vote.plainSummary ?? vote.summary)
                    .font(.headline)
                    .lineLimit(3)
                HStack(alignment: .bottom) {
                    TallyLine(tally: vote.tally, font: .amountRow.width(.condensed))
                    Spacer(minLength: .spaceS)
                    if let approved = vote.approved { ResultChip(approved: approved) }
                }
                TallyBar(tally: vote.tally)
            }
            .padding(.spaceL)
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(.vote(id: vote.id)), in: section)
            }
        }
    }
}
