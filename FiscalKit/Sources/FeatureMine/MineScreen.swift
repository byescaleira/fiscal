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
            if mine.hasPlace {
                MineRegionContent()
            } else {
                MineInviteSection()
            }
            MineFollowingSection()
        }
        .emphasisTitle("Region")
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
    var body: some View {
        Section {
            MineHeroCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

private struct MineHeroCard: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: mine.placeKicker)
                    .font(.chipLabel)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: mine.placeTitle)
                        .font(.amountHero)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    if let uf = mine.ufText { MineStatePlate(uf: uf) }
                }
                Text(verbatim: mine.placeDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mine.hasPlace, mine.phase == .loaded, mine.representativeCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: mine.countText)
                        .font(.scoreboardTitle)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity : .numericText(value: Double(mine.representativeCount)))
                    Text("representatives")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.spaceInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MineStatePlate: View {
    let uf: String

    var body: some View {
        Text(verbatim: uf)
            .font(.titleMedium)
            .padding(.horizontal, .spaceS)
            .overlay(
                RoundedRectangle(cornerRadius: .radiusS)
                    .strokeBorder(.secondary, lineWidth: .spaceHairline))
    }
}

private struct MineInviteSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
            Button {
                mine.choosePlace(searching: true)
            } label: {
                IconRow("State or city", symbol: "magnifyingglass", color: .secondary)
            }
            .buttonStyle(.plain)
            Button {
                mine.choosePlace(searching: false)
            } label: {
                IconRow(
                    "See All States and Cities",
                    detail: "State capitals first. Search finds any other city.",
                    symbol: "map", color: .info)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Find Your Place").sectionTitle()
        } footer: {
            Text("Your place stays only on this device. Fiscal never sends it anywhere.")
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
                mine.choosePlace(searching: false)
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
