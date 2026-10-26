import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MineGovernSection: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let seats = mine.seats
        if !seats.isEmpty {
            Section {
                Group {
                    if dynamicTypeSize.isAccessibilitySize || seats.count == 1 {
                        VStack(spacing: .spaceL) {
                            ForEach(seats) { MineSeatCard(seat: $0) }
                        }
                    } else {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: .spaceM) {
                                ForEach(seats) { seat in
                                    MineSeatCard(seat: seat)
                                        .containerRelativeFrame(.horizontal) { length, _ in
                                            min(length * .regionCardShare, .cardColumn)
                                        }
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollIndicators(.hidden)
                        .scrollClipDisabled()
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Who Governs").sectionTitle()
            }
        }
    }
}

private struct MineSeatCard: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let seat: MineSeat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            Text(verbatim: seat.kicker)
                .font(.caption.weight(.heavy))
                .lineLimit(2)
                .padding(.horizontal, .spaceM)
                .padding(.vertical, .space2XS)
                .background(.white.opacity(.opacityTint), in: .capsule)
            Button {
                open(.person(slug: seat.holder.slug), in: section)
            } label: {
                holder.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: mine.seatAccessibility(seat)))
            .accessibilityAddTraits(.isButton)
            Spacer(minLength: 0)
            if let vice = seat.vice { MineSeatPerson(card: vice) }
            ForEach(seat.elected) { MineSeatPerson(card: $0) }
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
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                Text(verbatim: card.name)
                    .font(.title2.weight(.heavy))
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
            if let action = mine.leadAction(for: card) { MineSeatAction(item: action) }
        }
    }

    private var detailLine: String? {
        let parts = [mine.mandateText(for: seat.holder), mine.status(of: seat.holder)]
            .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct MineSeatAction: View {
    @Environment(MineModel.self) private var mine
    let item: ActionItem

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Text(verbatim: mine.actionKicker(item).uppercased(with: .app))
                .font(.caption2.weight(.heavy))
                .opacity(.opacityStrong)
                .lineLimit(1)
            Text(verbatim: item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: .spaceXS) {
                Image(systemName: "scalemass")
                    .accessibilityHidden(true)
                Text(verbatim: MineRelevance(weight: item.weight).title)
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

private struct MineSeatPerson: View {
    @Environment(MineModel.self) private var mine
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
                        verbatim: [card.officeTitle, mine.status(of: card)].compactMap(\.self)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: mine.accessibilityLabel(for: card)))
        .accessibilityAddTraits(.isButton)
    }
}
