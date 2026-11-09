import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct RegionScreen: View {
    @Environment(RegionModel.self) private var region
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var region = region
        AdaptiveList {
            RegionHeroSection()
            if region.hasPlace {
                RegionContent()
            } else {
                RegionInviteSection()
            }
        }
        .emphasisTitle("Region")
        .toolbar { RegionToolbar() }
        .sheet(isPresented: $region.isChoosingPlace) {
            RegionPlacePicker().environment(region)
        }
        .refreshable { await region.load() }
        .task(id: session.generation) { await region.load() }
        .errorAlert($region.error)
    }
}

private struct RegionHeroSection: View {
    var body: some View {
        Section {
            RegionHeroCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Your Region").sectionTitle()
        }
    }
}

private struct RegionHeroCard: View {
    @Environment(RegionModel.self) private var region
    @ReducesMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: region.placeKicker)
                    .font(.chipLabel)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: region.placeTitle)
                        .font(.amountHero)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    if let uf = region.ufText { RegionStatePlate(uf: uf) }
                }
                Text(verbatim: region.placeDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if region.hasPlace, region.phase == .loaded, region.representativeCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: region.countText)
                        .font(.scoreboardTitle)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity
                                : .numericText(value: Double(region.representativeCount)))
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

private struct RegionStatePlate: View {
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

private struct RegionInviteSection: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        Section {
            Button {
                region.choosePlace(searching: true)
            } label: {
                IconRow("State or city", symbol: "magnifyingglass", color: .secondary)
            }
            .buttonStyle(.plain)
            Button {
                region.choosePlace(searching: false)
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
            Text(
                "Your place stays only on this device. Fiscal only downloads the public data of your region."
            )
        }
    }
}

private struct RegionToolbar: ToolbarContent {
    @Environment(RegionModel.self) private var region
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                region.choosePlace(searching: false)
            } label: {
                Label("Change Place", systemImage: "mappin.and.ellipse")
            }
            .tint(Color.primary)
        }
        if let route = region.shareRoute {
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
