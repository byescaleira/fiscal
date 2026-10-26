import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensWelcomeStep: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(spacing: .spaceXL) {
            PosterCarousel(works: setup.welcomeWorks)
                .padding(.horizontal, -.spaceInset)
            VStack(spacing: .spaceM) {
                Text("Welcome to Fiscal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("What your representatives do with your vote")
                    .font(.largeTitle.weight(.black))
                    .accessibilityAddTraits(.isHeader)
                Text("The same facts for everyone, in the order that matters to you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LensSupportStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            LensStepHeader(
                "Who do you support?",
                message: Text(
                    "Up to 5 politicians, from city councilor to president. Fiscal puts first what they do. The facts are the same for everyone."
                ))
            LensSupportChosen()
            LensPreferNotToSayCard()
            LensSupportSearch()
            LensPrivacyCard()
        }
    }
}

private struct LensSupportChosen: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceS) {
                Text("You support")
                    .font(.chipLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer(minLength: .zero)
                Text(verbatim: setup.supportCountText)
                    .font(.chipLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: .spaceM) {
                    ForEach(setup.chosen) { card in
                        LensChosenSlot(card: card)
                            .transition(.scale.combined(with: .opacity))
                    }
                    ForEach(0..<setup.openSlots, id: \.self) { _ in
                        LensEmptySlot()
                    }
                }
                .padding(.vertical, .spaceXS)
            }
            .scrollIndicators(.hidden)
            .animation(reduceMotion ? nil : .smooth, value: setup.draft.supported)
        }
        .padding(.spaceL)
        .surface(in: .rect(cornerRadius: .radiusL))
    }
}

private struct LensChosenSlot: View {
    @Environment(LensSetupModel.self) private var setup
    let card: PersonCard

    var body: some View {
        Button {
            Task { await setup.toggle(card) }
        } label: {
            VStack(spacing: .spaceXS) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeXL)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .secondary)
                            .font(.icon(.m))
                            .accessibilityHidden(true)
                    }
                Text(verbatim: card.name)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(Color.primary)
                PartyMark(card.party)
            }
            .frame(width: .choiceTile)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Removes this person from who you support"))
    }
}

private struct LensEmptySlot: View {
    var body: some View {
        VStack(spacing: .spaceXS) {
            Circle()
                .strokeBorder(
                    .tertiary, style: StrokeStyle(lineWidth: .spaceHairline, dash: [.space2XS])
                )
                .frame(width: .badgeXL, height: .badgeXL)
                .overlay {
                    Image(systemName: "plus").font(.headline).foregroundStyle(.secondary)
                }
            Text("Add person")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: .choiceTile)
        .accessibilityHidden(true)
    }
}

private struct LensPreferNotToSayCard: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint

    var body: some View {
        let isSelected = setup.draft.prefersNotToSay
        Button {
            Task { await setup.choosePrefersNotToSay() }
        } label: {
            HStack(spacing: .spaceM) {
                SymbolBadge("hand.raised.fill", color: tint, size: .badgeXL, style: .filled)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text("Prefer not to say")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Fiscal stays neutral: topics in the order the data comes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: .zero)
                SelectionMark(isSelected: isSelected)
            }
            .padding(.spaceL)
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .lensChoice(isSelected: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LensSupportSearch: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        @Bindable var setup = setup
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Name, party, office or state", text: $setup.query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if setup.isSearching {
                    Button("Clear", systemImage: "xmark.circle.fill") { setup.query = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body)
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceM)
            .surface(in: .capsule)
            LensSupportResults()
        }
    }
}

private struct LensSupportResults: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        let results = setup.results
        Group {
            if setup.isLoadingPeople && results.isEmpty {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity)
                    .padding(.spaceXL)
            } else if results.isEmpty {
                Label("No one with that name", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.spaceXL)
            } else {
                LazyVStack(spacing: .zero) {
                    ForEach(results) { card in
                        LensSupportRow(card: card)
                        if card.id != results.last?.id {
                            Divider().padding(.leading, .badgeXL + .spaceL + .spaceM)
                        }
                    }
                }
            }
        }
        .surface(in: .rect(cornerRadius: .radiusL))
    }
}

private struct LensSupportRow: View {
    @Environment(LensSetupModel.self) private var setup
    let card: PersonCard

    var body: some View {
        let isSupported = setup.isSupported(card)
        Button {
            Task { await setup.toggle(card) }
        } label: {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeXL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: card.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                    Text(verbatim: setup.detail(for: card))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    PartyMark(card.party)
                }
                Spacer(minLength: .spaceS)
                SelectionMark(isSelected: isSupported)
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceM)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!setup.canToggle(card))
        .opacity(setup.canToggle(card) ? 1 : .opacitySoft)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSupported ? .isSelected : [])
    }
}

struct LensPrivacyCard: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            Image(systemName: "lock.fill")
                .font(.icon(.m, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: .badgeL, height: .badgeL)
                .background(tint.opacity(.opacityTint), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text("Only on this iPhone").font(.headline)
                Text(
                    "Who you support stays only on this iPhone. It does not go to any server, it is not in iCloud, backups, notifications or shared images, and Fiscal does not know who it is."
                )
                .font(.subheadline)
                Text("A new iPhone or a reinstall asks for it again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spaceL)
        .background(Color.primary.opacity(.opacityFill), in: .rect(cornerRadius: .radiusL))
        .accessibilityElement(children: .combine)
    }
}
