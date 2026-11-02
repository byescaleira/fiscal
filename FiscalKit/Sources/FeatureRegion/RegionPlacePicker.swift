import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RegionPlacePicker: View {
    @Environment(RegionModel.self) private var region
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearching: Bool

    var body: some View {
        @Bindable var region = region
        NavigationStack {
            List {
                Group {
                    if region.isSearchingPlaces || region.places.isEmpty {
                        RegionPlaceResults()
                    } else {
                        RegionCitySection { isSearching = true }
                        RegionStateSection()
                    }
                    if region.hasPlace {
                        Section {
                            Button("Forget This Place", role: .destructive) {
                                region.forgetPlace()
                                dismiss()
                            }
                        } footer: {
                            Text(
                                "Your place stays only on this device. Fiscal only downloads the public data of your region."
                            )
                        }
                    }
                }
                .surfaceRows()
            }
            .listSurface()
            .searchable(text: $region.query, prompt: Text("State or city"))
            .searchFocused($isSearching)
            .navigationTitle("Your Place")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(Color.primary)
                }
            }
            .task { await region.loadPlaces() }
            .onAppear {
                isSearching = region.startsSearching
                region.startsSearching = false
            }
        }
    }
}

private struct RegionPlaceResults: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        Section {
            if let error = region.placesPhase.error, region.places.isEmpty {
                VStack(alignment: .leading, spacing: .spaceS) {
                    Label(error.message, systemImage: error.symbol)
                    Button("Try Again") { Task { await region.loadPlaces() } }
                        .buttonStyle(.borderless)
                }
            } else if region.places.isEmpty, region.placesPhase != .loaded {
                ProgressView("Loading").frame(maxWidth: .infinity)
            } else if region.placeResults.isEmpty {
                Text(
                    region.places.isEmpty
                        ? LocalizedStringKey("The list of places isn't published yet.")
                        : "No place with that name."
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(region.placeResults) { place in
                    RegionPlaceRow(place: place)
                }
            }
        } header: {
            Text(region.isSearchingPlaces ? LocalizedStringKey("States and Cities") : "States")
        } footer: {
            Text("Search runs on this device, over the official list of places from IBGE.")
        }
    }
}

private struct RegionCitySection: View {
    @Environment(RegionModel.self) private var region
    let search: () -> Void

    var body: some View {
        Section {
            Button(action: search) {
                IconRow(
                    "Find Your City",
                    detail:
                        "Type the name of any city in the search field. Every municipality in Brazil is there, with its mayor and city councilors.",
                    symbol: "magnifyingglass", color: .retroDenim)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the search field"))
            ForEach(region.capitals) { place in
                RegionPlaceRow(place: place)
            }
        } header: {
            Text("Cities")
        } footer: {
            if !region.capitals.isEmpty {
                Text("State capitals first. Search finds any other city.")
            }
        }
    }
}

private struct RegionStateSection: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        Section {
            ForEach(region.states) { place in
                RegionPlaceRow(place: place)
            }
        } header: {
            Text("States")
        } footer: {
            Text("Search runs on this device, over the official list of places from IBGE.")
        }
    }
}

struct RegionPlaceRow: View {
    @Environment(RegionModel.self) private var region
    let place: Place

    var body: some View {
        Button {
            Task { await region.choose(place) }
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
                    Text(verbatim: region.placeDetail(place))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .spaceS)
                if region.isChosen(place) {
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
