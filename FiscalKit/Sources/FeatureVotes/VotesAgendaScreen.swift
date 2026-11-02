import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct VotesAgendaScreen: View {
    @Environment(VotesModel.self) private var votes

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: votes.phase, isEmpty: votes.agendaHouses.isEmpty, retry: { await votes.load() }
        ) {
            AdaptiveList {
                VotesAgendaSection()
            }
        } empty: {
            EmptyStateView(
                title: "No agenda right now",
                description: "The agenda shows up here when the houses publish the next session."
            ) {
                EmptyView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.plainBackground)
        }
        .emphasisTitle("Agenda")
        .refreshable { await votes.load() }
        .task { await votes.load() }
    }
}

struct VotesAgendaLine: View {
    let line: AgendaLine

    var body: some View {
        Section {
            if line.itemCount > 0 {
                RouteLink(.agenda) { AgendaLineRow(line: line) }
            } else {
                AgendaLineRow(line: line)
            }
        }
    }
}

private struct AgendaLineRow: View {
    @Environment(VotesModel.self) private var votes
    @ReducesMotion private var reduceMotion
    let line: AgendaLine

    private var isInSession: Bool { line.status == .inSession }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: votes.agendaLineTitle(line))
                    .font(.rowTitle)
                Text(verbatim: votes.agendaLineDetail(line))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: isInSession ? "dot.radiowaves.left.and.right" : "calendar")
                .foregroundStyle(isInSession ? Color.retroTeal : Color.secondary)
                .symbolEffect(
                    .variableColor,
                    isActive: isInSession && !reduceMotion && !MotionBudget.isConstrained)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct VotesAgendaSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        Section {
            ForEach(votes.agendaHouses) { day in
                AgendaHouseRow(day: day)
                ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                    AgendaItemRow(item: item)
                }
            }
        } header: {
            DayHeader(
                number: votes.agendaDayNumber, title: votes.agendaTitle,
                detail: votes.agendaWeekday,
                accessibility: "\(votes.agendaTitle), \(votes.agendaWeekday)")
        } footer: {
            Text(verbatim: votes.agendaSource)
        }
    }
}

private struct AgendaHouseRow: View {
    @Environment(VotesModel.self) private var votes
    @ReducesMotion private var reduceMotion
    let day: Agenda.HouseDay

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: day.house.title)
                    .font(.headline)
                HStack(spacing: .space2XS) {
                    if day.inSession {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .symbolEffect(
                                .variableColor,
                                isActive: !reduceMotion && !MotionBudget.isConstrained)
                    }
                    Text(verbatim: votes.agendaStatus(day))
                }
                .font(.chipLabel)
                .foregroundStyle(day.inSession ? Color.retroTeal : Color.secondary)
            }
        } icon: {
            Image(systemName: "building.columns")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AgendaItemRow: View {
    @Environment(\.appTint) private var tint
    let item: AgendaItem

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(verbatim: item.proposition)
                .font(.rowTitle)
            if let status = item.status {
                Text(verbatim: status)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !item.themes.isEmpty {
                FlowLayout(spacing: .spaceS) {
                    ForEach(item.themes) { theme in
                        HStack(spacing: .space2XS) {
                            Image(systemName: theme.symbol)
                            Text(verbatim: theme.title)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .fixedSize()
                    }
                }
            }
            if let url = item.url {
                ExternalLink("Official page", destination: url)
                    .font(.footnote)
            }
        }
        .padding(.leading, .spaceL)
        .accessibilityElement(children: .combine)
    }
}
