import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensSupportSection: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.appTint) private var tint

    var body: some View {
        Section {
            if lens.prefersNotToSay {
                HStack(spacing: .spaceM) {
                    SymbolBadge("hand.raised.fill", color: tint, size: .badgeL, style: .filled)
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text("Prefer not to say").font(.rowTitle)
                        Text(verbatim: lens.supportSummary)
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                ForEach(lens.supportedCards) { card in
                    RouteLink(.person(slug: card.slug)) {
                        LensSupportedRow(card: card)
                    }
                }
            }
            Button("Change Who You Support", systemImage: "person.2") { lens.edit(.support) }
        } header: {
            Text("Who you support").sectionTitle()
        } footer: {
            Text(
                "Supporting is not following: in Mine you follow anyone. The people you support are also followed, and their topics and actions come first."
            )
        }
    }
}

private struct LensSupportedRow: View {
    let card: PersonCard

    var body: some View {
        HStack(spacing: .spaceM) {
            PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeL)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: card.name).font(.rowTitle)
                HStack(spacing: .spaceS) {
                    PartyMark(card.party)
                    Text(verbatim: card.officeTitle)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct LensOtherSection: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.close) private var close
    @Environment(\.appTint) private var tint

    var body: some View {
        Section {
            Button {
                lens.previewNeutral()
                close()
            } label: {
                HStack(spacing: .spaceM) {
                    SymbolBadge("scale.3d", color: tint, size: .badgeL)
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text("Neutral order").font(.rowTitle).foregroundStyle(.primary)
                        Text("Topics in the order the data comes, no one first.")
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: .spaceS)
                    Image(systemName: lens.isPreviewingNeutral ? "eye.fill" : "eye")
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(lens.isPreviewingNeutral ? .isSelected : [])
            ForEach(lens.others) { card in
                LensOtherRow(card: card)
            }
            if lens.isPreviewing {
                Button("Back to Mine", systemImage: "arrow.uturn.backward") { lens.endPreview() }
            }
        } header: {
            Text("Another lens").sectionTitle()
        } footer: {
            Text(verbatim: lens.otherLensFooter)
        }
    }
}

private struct LensOtherRow: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.close) private var close
    @Environment(\.appTint) private var tint
    let card: PersonCard

    var body: some View {
        Button {
            Task {
                await lens.preview(card)
                close()
            }
        } label: {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeL)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text("Who supports \(card.name)")
                        .font(.rowTitle)
                        .foregroundStyle(.primary)
                    PartyMark(card.party)
                }
                Spacer(minLength: .spaceS)
                if lens.loadingOther == card.slug {
                    ProgressView()
                } else {
                    Image(systemName: lens.isPreviewing(card) ? "eye.fill" : "eye")
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(lens.loadingOther != nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(lens.isPreviewing(card) ? .isSelected : [])
    }
}

struct LensPrivacySection: View {

    var body: some View {
        Section {
            LensPrivacyCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Privacy").sectionTitle()
        } footer: {
            Text(
                "The lens is never sent in requests, logs, notifications, shared cards or Spotlight."
            )
        }
    }
}
