import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VotesAgendaSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        if !votes.agendaHouses.isEmpty {
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
}

private struct AgendaHouseRow: View {
    @Environment(VotesModel.self) private var votes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: Agenda.HouseDay

    var body: some View {
        AdaptiveRow(spacing: .spaceS) {
            Label(day.house.title, systemImage: "building.columns")
                .font(.headline)
            Spacer(minLength: .spaceS)
            Label(
                votes.agendaStatus(day),
                systemImage: day.inSession ? "dot.radiowaves.left.and.right" : "calendar"
            )
            .font(.chipLabel)
            .foregroundStyle(day.inSession ? Color.retroTeal : Color.secondary)
            .symbolEffect(.variableColor, isActive: day.inSession && !reduceMotion)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AgendaItemRow: View {
    @Environment(\.appTint) private var tint
    let item: AgendaItem

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: item.proposition).font(.rowTitle)
                Spacer(minLength: .spaceS)
                if let status = item.status {
                    Chip(status, color: .secondary)
                }
            }
            Text(verbatim: item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !item.themes.isEmpty {
                HStack(spacing: .spaceS) {
                    ForEach(item.themes) { theme in
                        Label(theme.title, systemImage: theme.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }
                .lineLimit(1)
            }
            if let url = item.url {
                Link(destination: url) {
                    Label("Official page", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
            }
        }
        .padding(.leading, .spaceL)
        .accessibilityElement(children: .combine)
    }
}
