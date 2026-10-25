import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MineRepresentativesContent: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        if mine.hasPlace {
            if let error = mine.phase.error, mine.representatives == nil {
                MineFailureSection(error: error)
            } else if mine.representatives == nil {
                Section { ProgressView("Loading").frame(maxWidth: .infinity) }
            } else if mine.hasNoRepresentatives {
                Section {
                    IconRow(
                        "No list for this place yet",
                        detail:
                            "The official list of representatives for this place isn't published yet.",
                        symbol: "list.bullet.rectangle", color: .retroDenim)
                }
            } else {
                ForEach(mine.groups) { group in
                    MineGroupSection(group: group, isLast: group.id == mine.groups.last?.id)
                }
            }
        }
    }
}

private struct MineGroupSection: View {
    @Environment(MineModel.self) private var mine
    let group: MineModel.OfficeGroup
    let isLast: Bool

    var body: some View {
        Section {
            ForEach(group.people) { card in
                RepresentativeRow(
                    card: card, detail: group.showsOffice ? card.office.title : nil,
                    status: mine.status(of: card), prominent: group.isProminent,
                    accessibility: mine.accessibilityLabel(for: card))
            }
        } header: {
            Text(verbatim: group.header).sectionTitle()
        } footer: {
            if isLast {
                VStack(alignment: .leading, spacing: .space2XS) {
                    if let note = mine.cityNote { Text(verbatim: note) }
                    Text("In alphabetical order inside each office. Nobody is ranked.")
                    if let source = mine.sourceText { Text(verbatim: source) }
                }
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

    var body: some View {
        Section {
            if mine.isEmpty {
                IconRow(
                    "Nobody followed yet",
                    detail:
                        "Tap Follow on any profile and that person shows up here, on this device.",
                    symbol: "person.crop.circle.badge.plus", color: .retroTeal)
            } else {
                ForEach(mine.followed) { person in
                    RepresentativeRow(
                        card: person.card, detail: mine.detail(for: person),
                        status: mine.status(of: person.card), prominent: false,
                        accessibility: mine.accessibilityLabel(for: person.card))
                }
            }
        } header: {
            Text("Following").sectionTitle()
        } footer: {
            Text("Who you follow stays on this device.")
        }
    }
}

struct RepresentativeRow: View {
    let card: PersonCard
    let detail: String?
    let status: String?
    let prominent: Bool
    let accessibility: String

    var body: some View {
        RouteLink(.person(slug: card.slug)) {
            HStack(spacing: .spaceM) {
                PersonPortrait(
                    slug: card.slug, name: card.name, party: card.party,
                    size: prominent ? .badgeXL : .badgeL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: card.name)
                        .font(prominent ? .titleMedium : .rowTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: .spaceXS) {
                        PartyMark(card.party)
                        if let detail {
                            Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        if let status {
                            Label(status, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, prominent ? .spaceXS : .space2XS)
        }
        .accessibilityLabel(Text(verbatim: accessibility))
    }
}
