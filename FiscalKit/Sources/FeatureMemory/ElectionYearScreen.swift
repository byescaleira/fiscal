import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ElectionYearScreen: View {
    @Environment(ElectionYearModel.self) private var model

    public init() {}

    public var body: some View {
        @Bindable var model = model
        PublicDataContent(phase: model.phase, isEmpty: model.isEmpty, retry: { await model.load() })
        {
            AdaptiveList {
                if let breakdown = model.breakdown {
                    PastRoundSections(breakdown: breakdown)
                }
                if !model.governors.isEmpty {
                    StateRacesSection(title: "Governors", races: model.governors)
                }
                if !model.senators.isEmpty {
                    StateRacesSection(title: "Senate", races: model.senators)
                }
                YearNotesSection()
            }
        } empty: {
            ContentUnavailableView(
                "No results for this year", systemImage: "archivebox",
                description: Text("The TSE results for this year aren't published by Fiscal yet."))
        }
        .emphasisTitle(Text(verbatim: model.title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RoundMenu(
                    rounds: model.president?.rounds.map(\.round) ?? [], selection: $model.round)
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

private struct StateRacesSection: View {
    @Environment(ElectionYearModel.self) private var model
    let title: LocalizedStringKey
    let races: [PastRaceSummary]

    var body: some View {
        Section {
            ForEach(races) { race in
                RouteLink(.pastRace(id: race.id)) {
                    PastRaceRow(race: race, winners: model.winner(race), detail: model.detail(race))
                }
            }
        } header: {
            Text(title).sectionTitle()
        } footer: {
            Text("States in alphabetical order. Percentage over valid votes in the deciding round.")
        }
    }
}

private struct YearNotesSection: View {
    @Environment(ElectionYearModel.self) private var model

    var body: some View {
        Section {
            ForEach(model.gaps, id: \.reason) { gap in
                IconRow(verbatim: gap.reason, symbol: "info.circle", color: .retroDenim)
            }
            ForEach(model.history?.method ?? [], id: \.self) { line in
                Text(verbatim: line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("How we count").sectionTitle()
        } footer: {
            Text(verbatim: model.sourceLine)
        }
    }
}
