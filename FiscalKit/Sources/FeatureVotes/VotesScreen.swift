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
                VotesFilterSection()
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
        .refreshable { await votes.load() }
        .task { await votes.load() }
    }
}

private struct VotesFilterSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        @Bindable var votes = votes
        Section {
        } header: {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let stance = votes.lensStance {
                    LensBadge(stance)
                }
                Picker("House", selection: $votes.house) {
                    ForEach(VotesModel.HouseFilter.allCases) { house in
                        Text(verbatim: house.title).tag(house)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                ThemeFilterBar()
            }
            .textCase(nil)
            .padding(.bottom, .spaceS)
        }
    }
}

private struct ThemeFilterBar: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .spaceS) {
                ForEach(votes.themeChoices) { theme in
                    ThemeFilterChip(
                        theme: theme, isSelected: votes.theme == theme,
                        isLens: votes.isLensTheme(theme)
                    ) {
                        votes.toggle(theme)
                    }
                }
            }
            .padding(.vertical, .spaceHairline)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

private struct ThemeFilterChip: View {
    @Environment(\.appTint) private var tint
    let theme: Theme
    let isSelected: Bool
    let isLens: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .space2XS) {
                Image(systemName: theme.symbol)
                Text(verbatim: theme.title)
                if isLens {
                    Image(systemName: "eyeglasses").accessibilityHidden(true)
                }
            }
            .font(.chipLabel)
            .foregroundStyle(isSelected ? Color.white : tint)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(isSelected ? tint : tint.opacity(.opacityTint), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isLens ? Text("One of your lens topics") : Text(verbatim: ""))
        .sensoryFeedback(.selection, trigger: isSelected)
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
