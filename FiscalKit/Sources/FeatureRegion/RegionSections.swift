import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RegionContent: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        if let error = region.phase.error, region.representatives == nil {
            RegionFailureSection(error: error)
        } else if region.representatives == nil {
            Section {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spaceXL)
            }
        } else if region.hasNoRepresentatives {
            Section {
                IconRow(
                    "No list for this place yet",
                    detail:
                        "The official list of representatives for this place isn't published yet.",
                    symbol: "list.bullet.rectangle", color: .retroDenim)
            }
        } else {
            if region.isOfflineWithData { RegionOfflineNotice() }
            RegionGovernSection()
            ForEach(region.benches) { RegionBenchSection(bench: $0) }
            if let senate = region.senate { RegionSenateSection(bench: senate) }
            RegionNowSection()
            RegionSourceSection()
        }
    }
}

private struct RegionOfflineNotice: View {
    var body: some View {
        Section {
            Label {
                Text("No connection. Showing the last data received.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "wifi.slash")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }
}

private struct RegionSourceSection: View {
    @Environment(RegionModel.self) private var region

    var body: some View {
        Section {
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let note = region.cityNote { Text(verbatim: note) }
                Text("In alphabetical order inside each office. Nobody is ranked.")
                if let source = region.sourceText { Text(verbatim: source) }
            }
        }
    }
}

private struct RegionFailureSection: View {
    @Environment(RegionModel.self) private var region
    let error: PublicDataError

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                Label {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: error.title).font(.rowTitle)
                        Text(verbatim: error.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: error.symbol).foregroundStyle(Color.retroRust)
                }
                Button("Try Again") { Task { await region.loadPlace() } }
                    .buttonStyle(.borderless)
            }
            .padding(.vertical, .spaceXS)
        }
    }
}

struct RegionRosterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let card: PersonCard
    let showsPlace: Bool

    init(card: PersonCard, showsPlace: Bool = false) {
        self.card = card
        self.showsPlace = showsPlace
    }

    var body: some View {
        RouteLink(.person(slug: card.slug)) {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: card.name)
                        .font(.rowTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    AdaptiveStack(spacing: .spaceXS) {
                        PartyMark(card.party)
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                }
            }
            .padding(.vertical, .space2XS)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(card.name), \(card.party), \(detail)"))
        .accessibilityAddTraits(.isButton)
        .followActions(card)
    }

    private var detail: String {
        let place = showsPlace && card.uf != "br" ? " · \(card.uf.uppercased())" : ""
        let status = card.status == .inOffice ? "" : " · \(card.status.title)"
        return "\(card.officeTitle)\(place)\(status)"
    }
}
