import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct PastRaceScreen: View {
    @Environment(PastRaceModel.self) private var model

    public init() {}

    public var body: some View {
        @Bindable var model = model
        PublicDataContent(
            phase: model.phase, isEmpty: model.race == nil, retry: { await model.load() }
        ) {
            AdaptiveList {
                if let breakdown = model.breakdown {
                    PastRoundSections(breakdown: breakdown)
                    if let coalition = breakdown.leader?.members ?? breakdown.leader?.coalition {
                        Section {
                            Text(verbatim: coalition)
                                .font(.subheadline)
                        } header: {
                            Text("Coalition of the most voted").sectionTitle()
                        } footer: {
                            Text(verbatim: breakdown.sourceLine)
                        }
                    }
                }
            }
        } empty: {
            EmptyStateView(
                title: "No result",
                description: "This race isn't published by Fiscal yet."
            ) {
                IconRow("Votes by candidate", symbol: "chart.bar.xaxis", color: .retroDenim)
                IconRow("Who won in each state", symbol: "map", color: .retroTeal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.plainBackground)
        }
        .emphasisTitle(Text(verbatim: model.title))
        #if !os(visionOS)
            .navigationSubtitle(model.roundSubtitle)
        #endif
        .sensoryFeedback(.selection, trigger: model.round)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RoundMenu(rounds: model.race?.rounds.map(\.round) ?? [], selection: $model.round)
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}
