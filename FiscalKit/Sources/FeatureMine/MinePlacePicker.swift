import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MinePlacePicker: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var mine = mine
        NavigationStack {
            List {
                MinePlaceResults()
                if mine.hasPlace {
                    Section {
                        Button("Forget This Place", role: .destructive) {
                            mine.forgetPlace()
                            dismiss()
                        }
                    } footer: {
                        Text(
                            "Your place stays only on this device. Fiscal never sends it anywhere.")
                    }
                }
            }
            .searchable(text: $mine.query, prompt: Text("State or city"))
            .fontDesign(.rounded)
            .navigationTitle("Your Place")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await mine.loadPlaces() }
        }
    }
}

private struct MinePlaceResults: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            if let error = mine.placesPhase.error, mine.places.isEmpty {
                VStack(alignment: .leading, spacing: .spaceS) {
                    Label(error.message, systemImage: error.symbol)
                    Button("Try Again") { Task { await mine.loadPlaces() } }
                        .buttonStyle(.borderless)
                }
            } else if mine.places.isEmpty, mine.placesPhase != .loaded {
                ProgressView("Loading").frame(maxWidth: .infinity)
            } else if mine.placeResults.isEmpty {
                Text(
                    mine.places.isEmpty
                        ? LocalizedStringKey("The list of places isn't published yet.")
                        : "No place with that name."
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(mine.placeResults) { place in
                    MinePlaceRow(place: place)
                }
            }
        } header: {
            Text(mine.isSearchingPlaces ? LocalizedStringKey("States and Cities") : "States")
        } footer: {
            Text("Search runs on this device, over the official list of places from IBGE.")
        }
    }
}

private struct MinePlaceRow: View {
    @Environment(MineModel.self) private var mine
    let place: Place

    var body: some View {
        Button {
            Task { await mine.choose(place) }
        } label: {
            HStack(spacing: .spaceM) {
                Image(systemName: place.isState ? "map" : "building.2")
                    .font(.icon(.s, weight: .medium))
                    .foregroundStyle(Color.retroDenim)
                    .frame(width: .badgeM, height: .badgeM)
                    .background(
                        Color.retroDenim.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: place.name).font(.rowTitle).foregroundStyle(.primary)
                    Text(verbatim: mine.placeDetail(place))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .spaceS)
                if mine.isChosen(place) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityLabel(Text("Chosen"))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
