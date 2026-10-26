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
            MineHeroCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            if !mine.hasPlace {
                Button("Choose Your State or City") { mine.isChoosingPlace = true }
                    .primaryButton()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct MineHeroCard: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            HStack(spacing: .spaceS) {
                Label {
                    Text(verbatim: mine.placeKicker)
                } icon: {
                    Image(systemName: mine.place?.isState == true ? "map" : "building.2")
                }
                .font(.chipLabel)
                .padding(.horizontal, .spaceS)
                .padding(.vertical, .space2XS)
                .background(.fill.tertiary, in: .capsule)
                Spacer(minLength: .spaceS)
            }
            VStack(alignment: .leading, spacing: .space2XS) {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: mine.placeTitle)
                        .font(.amountHero)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    if let uf = mine.ufText { MineStatePlate(uf: uf) }
                }
                Text(verbatim: mine.placeDetail)
                    .font(.subheadline)
                    .opacity(.opacityStrong)
            }
            if mine.hasPlace, mine.phase == .loaded {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: mine.countText)
                        .font(.scoreboardNumber)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity : .numericText(value: Double(mine.representativeCount)))
                    Text("representatives")
                        .font(.subheadline.weight(.semibold))
                        .opacity(.opacityStrong)
                }
                MineLevelStrip()
            }
        }
        .foregroundStyle(.primary)
        .padding(.spaceInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MineLevelStrip: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .spaceS) {
                ForEach(mine.groups) { group in
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: PublicFormat.number(group.people.count))
                            .font(.title3.weight(.heavy))
                            .monospacedDigit()
                        Text(verbatim: group.title)
                            .font(.caption2.weight(.semibold))
                            .opacity(.opacityStrong)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, .spaceM)
                    .padding(.vertical, .spaceS)
                    .background(.fill.tertiary, in: .rect(cornerRadius: .radiusS))
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
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
            .tint(Color.primary)
        }
        if let route = mine.shareRoute {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    open(route, in: section)
                } label: {
                    Label("Share My Representatives", systemImage: "square.and.arrow.up")
                }
                .tint(Color.primary)
            }
        }
    }
}
