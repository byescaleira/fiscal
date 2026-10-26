import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayHighlightHero: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            header
            Button {
                if let route = today.route(for: highlight) { open(route, in: section) }
            } label: {
                content.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(today.route(for: highlight) == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: today.highlightAccessibility(highlight)))
            .accessibilityAddTraits(.isButton)
            if let person = highlight.person {
                TodayHighlightAuthor(person: person)
            }
            footer
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { backdrop }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .fontDesign(.rounded)
        .contextMenu {
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(today.shareSubject(for: highlight)), in: section)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) {
                appeared = true
            }
        }
    }

    @ViewBuilder private var backdrop: some View {
        if let party = highlight.person?.party, !party.isEmpty {
            PartyBackdrop(party: party)
        } else {
            TodayHighlightBackdrop(slot: today.highlightThemeSlot(highlight))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: today.highlightHeroKicker(highlight).uppercased(with: .app))
                .font(.caption.weight(.heavy))
                .tracking(.spaceHairline / 4)
                .opacity(.opacityStrong)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .spaceS)
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(today.shareSubject(for: highlight)), in: section)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .tint(.white)
            .font(.body.weight(.semibold))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Text(verbatim: highlight.plainSummary ?? highlight.title)
                .font(.title2.weight(.bold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
            if highlight.plainSummary != nil {
                Text(verbatim: highlight.title)
                    .font(.footnote)
                    .opacity(.opacityStrong)
                    .lineLimit(2)
            }
            if let tally = highlight.tally {
                TodayHighlightScore(tally: tally, large: false)
            }
            if let reference = today.highlightReference(highlight) {
                Text(verbatim: reference)
                    .font(.footnote.weight(.semibold))
                    .opacity(.opacityStrong)
            }
        }
    }

    private var footer: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .spaceS))
            : AnyLayout(HStackLayout(alignment: .center, spacing: .spaceS))
        return layout {
            TodayHighlightRelevance(weight: highlight.weight, filled: appeared)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: .spaceS) }
            WeightMethodButton(method: today.highlightMethod)
                .tint(.white)
        }
    }
}

private struct TodayHighlightAuthor: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let person: PersonCard

    var body: some View {
        Button {
            open(.person(slug: person.slug), in: section)
        } label: {
            HStack(alignment: .center, spacing: .spaceS) {
                details
                Spacer(minLength: .spaceS)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .opacity(.opacityStrong)
            }
            .padding(.vertical, .spaceS)
            .padding(.horizontal, .spaceM)
            .background(.white.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: today.highlightAuthorAccessibility(person)))
        .accessibilityHint(Text("Opens the profile"))
        .accessibilityAddTraits(.isButton)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            HStack(alignment: .center, spacing: .spaceS) {
                Text(verbatim: person.name)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                PartyMark(person.party)
                    .fixedSize()
                    .overlay {
                        Capsule().strokeBorder(
                            .white.opacity(.opacitySoft), lineWidth: .spaceHairline / 2)
                    }
            }
            Text(verbatim: "\(person.officeTitle) · \(person.uf.uppercased())")
                .font(.footnote)
                .opacity(.opacityStrong)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayHighlightRelevance: View {
    let weight: Int
    let filled: Bool

    var body: some View {
        let relevance = Relevance(weight: weight)
        HStack(spacing: .spaceXS) {
            StatusCircle(relevance.title, symbol: relevance.symbol, color: .white)
            Text(verbatim: relevance.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
            HStack(spacing: .spaceHairline) {
                ForEach(0..<Relevance.segments, id: \.self) { index in
                    Capsule()
                        .fill(
                            .white.opacity(
                                filled && Double(index) < relevance.filledSegments
                                    ? 1 : .opacityTint)
                        )
                        .frame(width: .spaceM, height: .space2XS)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension Relevance {
    fileprivate var symbol: String {
        switch self {
        case .high: "gauge.with.dots.needle.100percent"
        case .medium: "gauge.with.dots.needle.50percent"
        case .low: "gauge.with.dots.needle.0percent"
        }
    }
}

private struct TodayHighlightScore: View {
    let tally: HighlightTally
    let large: Bool

    var body: some View {
        VStack(alignment: large ? .center : .leading, spacing: .spaceXS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
                side("YES", tally.yes)
                Text(verbatim: "×")
                    .font(large ? .title.weight(.heavy) : .headline.weight(.heavy))
                    .opacity(.opacityStrong)
                side("NO", tally.no)
            }
            .frame(maxWidth: large ? .infinity : nil)
            TallyChart(
                segments: [
                    .init(
                        id: "yes", title: String(appLocalized: "Yes"), value: Double(tally.yes),
                        color: .white),
                    .init(
                        id: "no", title: String(appLocalized: "No"), value: Double(tally.no),
                        color: .white.opacity(.opacitySoft)),
                    .init(
                        id: "others", title: String(appLocalized: "Others"),
                        value: Double(tally.others), color: .white.opacity(.opacityTint)),
                ], height: .spaceXS
            )
            .accessibilityHidden(true)
            if tally.others > 0 {
                Text("\(tally.others) other votes")
                    .font(.caption.weight(.semibold))
                    .opacity(.opacityStrong)
            }
        }
    }

    private func side(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: "\(value)")
                .font(large ? .scoreboardHero : .scoreboardNumber)
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.heavy))
                .opacity(.opacityStrong)
        }
    }
}

private struct TodayHighlightBackdrop: View {
    let slot: Int?

    var body: some View {
        let color =
            slot.map { ChartPalette.color(at: $0 % ChartPalette.categorical.count) }
            ?? ChartPalette.color(at: ChartPalette.categorical.count - 1)
        ZStack {
            Color.scoreboard
            LinearGradient(
                colors: [color, color.opacity(.opacitySoft)], startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Color.scoreboard.opacity(.opacitySoft)
        }
    }
}
