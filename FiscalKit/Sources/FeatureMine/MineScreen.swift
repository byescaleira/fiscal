import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MineScreen: View {
    @Environment(MineModel.self) private var mine
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var mine = mine
        AdaptiveList {
            MineHeroSection()
            MineRepresentativesContent()
            MineFollowingSection()
        }
        .fontDesign(.rounded)
        .navigationTitle("Mine")
        .toolbar { MineToolbar() }
        .sheet(isPresented: $mine.isChoosingPlace) {
            MinePlacePicker().environment(mine)
        }
        .refreshable { await mine.load() }
        .task(id: session.generation) { await mine.load() }
        .errorAlert($mine.error)
    }
}

private struct MineHeroSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            if !mine.hasPlace {
                Button("Choose Your State or City") { mine.isChoosingPlace = true }
                    .primaryButton()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        } header: {
            MineHero()
        }
    }
}

private struct MineHero: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: mine.placeKicker)
                .font(.chipLabel)
                .foregroundStyle(.secondary)
            AdaptiveStack(alignment: .bottom, spacing: .spaceL) {
                VStack(alignment: .leading, spacing: .spaceXS) {
                    HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                        Text(verbatim: mine.placeTitle)
                            .font(.amountHero)
                            .minimumScaleFactor(0.6)
                        if let uf = mine.ufText { MineStatePlate(uf: uf) }
                    }
                    Text(verbatim: mine.placeDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if mine.hasPlace, mine.phase == .loaded {
                    MineCount()
                }
            }
        }
        .foregroundStyle(.primary)
        .textCase(nil)
        .padding(.vertical, .spaceL)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MineStatePlate: View {
    let uf: String

    var body: some View {
        Text(verbatim: uf)
            .font(.titleMedium)
            .fontWidth(.condensed)
            .padding(.horizontal, .spaceS)
            .overlay(
                RoundedRectangle(cornerRadius: .radiusS)
                    .strokeBorder(.secondary, lineWidth: .spaceHairline))
    }
}

private struct MineCount: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: .space2XS) {
            Text(verbatim: mine.countText)
                .font(.scoreboardNumber)
                .monospacedDigit()
                .contentTransition(
                    reduceMotion ? .identity : .numericText(value: Double(mine.representativeCount))
                )
            Text("representatives")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MineToolbar: ToolbarContent {
    @Environment(MineModel.self) private var mine
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                mine.isChoosingPlace = true
            } label: {
                Label("Change Place", systemImage: "mappin.and.ellipse")
            }
        }
        if let route = mine.shareRoute {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    open(route, in: section)
                } label: {
                    Label("Share My Representatives", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}
