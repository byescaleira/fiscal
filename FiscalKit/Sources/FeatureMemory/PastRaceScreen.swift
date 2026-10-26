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
            ContentUnavailableView(
                "No result", systemImage: "archivebox",
                description: Text("This race isn't published by Fiscal yet."))
        }
        .fontDesign(.rounded)
        .navigationTitle(Text(verbatim: model.title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RoundMenu(rounds: model.race?.rounds.map(\.round) ?? [], selection: $model.round)
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}
