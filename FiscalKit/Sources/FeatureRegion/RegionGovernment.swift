import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RegionGovernSection: View {
    @Environment(RegionModel.self) private var region
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let seats = region.seats
        if !seats.isEmpty {
            Section {
                Group {
                    if dynamicTypeSize.isAccessibilitySize || seats.count == 1 {
                        VStack(spacing: .spaceL) {
                            ForEach(seats) { RegionSeatCard(seat: $0) }
                        }
                        .padding(.horizontal, .railListMargin)
                    } else {
                        EdgeToEdgeRail {
                            ForEach(seats) { seat in
                                RegionSeatCard(seat: seat)
                                    .containerRelativeFrame(.horizontal) { length, _ in
                                        min(length * .regionCardShare, .cardColumn)
                                    }
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                Text("Who Governs").sectionTitle().railHeader()
            }
            .railSection()
        }
    }
}

private struct RegionSeatCard: View {
    @Environment(RegionModel.self) private var region
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @ReducesMotion private var reduceMotion
    @State private var appeared = false
    let seat: RegionSeat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            Chip(seat.kicker, color: .white, shape: .capsule)
                .environment(\.colorScheme, .dark)
            if seat.standsAlone { Spacer(minLength: 0) }
            Button {
                open(.person(slug: seat.holder.slug), in: section)
            } label: {
                holder.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .followActions(seat.holder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: region.seatAccessibility(seat)))
            .accessibilityAddTraits(.isButton)
            Spacer(minLength: 0)
            if let vice = seat.vice { RegionSeatPerson(card: vice) }
            ForEach(seat.elected) { RegionSeatPerson(card: $0) }
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { PartyBackdrop(party: seat.holder.party) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.3)) {
                appeared = true
            }
        }
    }

    private var holder: some View {
        let card = seat.holder
        return VStack(alignment: .leading, spacing: .spaceL) {
            VStack(spacing: .spaceS) {
                PersonPortrait(
                    slug: card.slug, name: card.name, party: card.party, size: .medallion
                )
                .overlay { Circle().strokeBorder(.white, lineWidth: .space2XS) }
                .scaleEffect(appeared ? 1 : .seatPortraitEntryScale)
                .opacity(appeared ? 1 : 0)
                Text(verbatim: card.name)
                    .font(.emphasis(.title2, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: .spaceS) {
                    PartyMark(card.party)
                    Text(verbatim: card.officeTitle)
                        .font(.subheadline.weight(.semibold))
                        .opacity(.opacityStrong)
                        .lineLimit(1)
                }
                if let line = detailLine {
                    Text(verbatim: line)
                        .font(.footnote.weight(.medium))
                        .opacity(.opacityStrong)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            if let action = region.leadAction(for: card) { RegionSeatAction(item: action) }
        }
    }

    private var detailLine: String? {
        let parts = [region.mandateText(for: seat.holder), region.status(of: seat.holder)]
            .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct RegionSeatAction: View {
    @Environment(RegionModel.self) private var region
    let item: ActionItem

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Text(verbatim: region.actionKicker(item).uppercased(with: .app))
                .font(.chipLabel)
                .opacity(.opacityStrong)
                .lineLimit(1)
            Text(verbatim: item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: .spaceXS) {
                Image(systemName: "scalemass")
                    .accessibilityHidden(true)
                Text(verbatim: Relevance(weight: item.weight).title)
                if let estimate = item.coverage.uncertaintyShort {
                    Text(verbatim: "· \(estimate)")
                        .lineLimit(1)
                }
            }
            .font(.caption.weight(.semibold))
            .opacity(.opacityStrong)
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
    }
}

private struct RegionSeatPerson: View {
    @Environment(RegionModel.self) private var region
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let card: PersonCard

    var body: some View {
        Button {
            open(.person(slug: card.slug), in: section)
        } label: {
            HStack(spacing: .spaceS) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeM)
                    .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: card.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(
                        verbatim: [card.officeTitle, region.status(of: card)].compactMap(\.self)
                            .joined(separator: " · ")
                    )
                    .font(.caption)
                    .opacity(.opacityStrong)
                    .lineLimit(1)
                }
                Spacer(minLength: .spaceS)
                PartyMark(card.party)
            }
            .padding(.spaceS)
            .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .followActions(card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: region.accessibilityLabel(for: card)))
        .accessibilityAddTraits(.isButton)
    }
}
