import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct VotesScreen: View {
    @Environment(VotesModel.self) private var votes

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: votes.phase, isEmpty: votes.isEmpty, retry: { await votes.load() }
        ) {
            AdaptiveList {
                VotesAgendaSection()
                VotesHighlightsSection()
                if votes.days.isEmpty {
                    VotesNoMatchSection()
                }
                ForEach(votes.days) { day in
                    VotesDaySection(day: day)
                }
            }
            .animation(.smooth, value: votes.days)
        } empty: {
            VotesEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle("Votes")
        #if !os(visionOS)
            .navigationSubtitle(votes.filterSummary)
        #endif
        .toolbar { VotesToolbar() }
        .sensoryFeedback(.selection, trigger: votes.house)
        .sensoryFeedback(.selection, trigger: votes.theme)
        .refreshable { await votes.load() }
        .task { await votes.load() }
    }
}

private struct VotesHighlightsSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        if let stance = votes.lensStance, !votes.highlights.isEmpty {
            Section {
                ForEach(votes.highlights) { vote in
                    RouteLink(.vote(id: vote.id)) { VoteHighlightRow(vote: vote) }
                }
            } header: {
                AdaptiveRow(spacing: .spaceS) {
                    Text("In Your Topics").sectionTitle()
                    Spacer(minLength: .spaceS)
                    LensBadge(stance)
                }
                .textCase(nil)
            } footer: {
                Text(
                    "Your lens picks which votes come first. The numbers are the same for everyone."
                )
            }
        }
    }
}

private struct VotesDaySection: View {
    @Environment(VotesModel.self) private var votes
    let day: VotesModel.Day

    var body: some View {
        Section {
            ForEach(day.votes) { vote in
                RouteLink(.vote(id: vote.id)) { VoteScoreRow(vote: vote) }
            }
        } header: {
            DayHeader(
                number: votes.dayNumber(day), title: votes.dayTitle(day),
                detail: votes.dayMonth(day), accessibility: votes.dayAccessibility(day))
        } footer: {
            Text(verbatim: votes.sourceText(day))
        }
    }
}

struct DayHeader: View {
    let number: String
    let title: String
    let detail: String
    let accessibility: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: number)
                .font(.titleLarge)
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(verbatim: title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibility))
        .accessibilityAddTraits(.isHeader)
    }
}

private struct VotesNoMatchSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                Label {
                    Text(verbatim: votes.emptyFilterText)
                } icon: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .foregroundStyle(.secondary)
                if votes.hasFilter {
                    Button("Clear Filters") { votes.clearFilters() }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, .spaceXS)
        }
    }
}

private struct VotesEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No votes yet",
            description:
                "The latest floor votes of the Chamber and the Senate show up here, with who voted how."
        ) {
            IconRow("Yes", symbol: BallotChoice.yes.symbol, color: BallotChoice.yes.color)
            IconRow("No", symbol: BallotChoice.no.symbol, color: BallotChoice.no.color)
            IconRow(
                "Absent", symbol: BallotChoice.absent.symbol, color: BallotChoice.absent.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
