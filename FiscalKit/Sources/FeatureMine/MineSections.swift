import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MineRegionContent: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        if let error = mine.phase.error, mine.representatives == nil {
            MineFailureSection(error: error)
        } else if mine.representatives == nil {
            Section {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spaceXL)
            }
        } else if mine.hasNoRepresentatives {
            Section {
                IconRow(
                    "No list for this place yet",
                    detail:
                        "The official list of representatives for this place isn't published yet.",
                    symbol: "list.bullet.rectangle", color: .retroDenim)
            }
        } else {
            if mine.isOfflineWithData { MineOfflineNotice() }
            MineGovernSection()
            ForEach(mine.benches) { MineBenchSection(bench: $0) }
            if let senate = mine.senate { MineSenateSection(bench: senate) }
            MineNowSection()
            MineSourceSection()
        }
    }
}

private struct MineOfflineNotice: View {
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

private struct MineSourceSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        Section {
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let note = mine.cityNote { Text(verbatim: note) }
                Text("In alphabetical order inside each office. Nobody is ranked.")
                if let source = mine.sourceText { Text(verbatim: source) }
            }
        }
    }
}

private struct MineFailureSection: View {
    @Environment(MineModel.self) private var mine
    let error: PublicDataError

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                Label {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text("Couldn't load the data").font(.rowTitle)
                        Text(verbatim: error.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: error.symbol).foregroundStyle(Color.retroRust)
                }
                Button("Try Again") { Task { await mine.loadPlace() } }
                    .buttonStyle(.borderless)
            }
            .padding(.vertical, .spaceXS)
        }
    }
}

struct MineFollowingSection: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            if mine.isEmpty {
                IconRow(
                    "Nobody followed yet",
                    detail:
                        "Tap Follow on any profile and that person shows up here, on this device.",
                    symbol: "person.crop.circle.badge.plus", color: .retroTeal)
            } else if dynamicTypeSize.isAccessibilitySize {
                ForEach(mine.followedCards) { MineRosterRow(card: $0, showsPlace: true) }
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: .spaceL) {
                        ForEach(mine.followedCards) { MineFace(card: $0) }
                    }
                    .padding(.vertical, .spaceXS)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        } header: {
            Text("Following").sectionTitle()
        } footer: {
            Text("Who you follow stays on this device.")
        }
    }
}

struct MineFace: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let card: PersonCard

    var body: some View {
        Button {
            open(.person(slug: card.slug), in: section)
        } label: {
            VStack(spacing: .spaceXS) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeXL)
                Text(verbatim: MineModel.shortName(card.name))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                PartyMark(card.party)
            }
            .frame(width: .regionMiniCard)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(card.name), \(card.party), \(card.officeTitle)"))
        .accessibilityAddTraits(.isButton)
    }
}

struct MineRosterRow: View {
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
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, .space2XS)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(card.name), \(card.party), \(detail)"))
        .accessibilityAddTraits(.isButton)
    }

    private var detail: String {
        let place = showsPlace && card.uf != "br" ? " · \(card.uf.uppercased())" : ""
        let status = card.status == .inOffice ? "" : " · \(card.status.title)"
        return "\(card.officeTitle)\(place)\(status)"
    }
}
