import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayHighlightHero: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            WeightMethodButton(method: today.highlightMethod)
                .tint(.white)
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TodayHighlightBackdrop(slot: today.highlightThemeSlot(highlight)) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .fontDesign(.rounded)
        .contextMenu {
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(today.shareSubject(for: highlight)), in: section)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.3)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: .spaceS) {
            Text(verbatim: today.highlightKicker(highlight).uppercased(with: .app))
                .font(.caption.weight(.heavy))
                .padding(.horizontal, .spaceM)
                .padding(.vertical, .space2XS)
                .background(.white.opacity(.opacityTint), in: .capsule)
            if today.isSupportPick(highlight) { LensPickMark() }
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
        VStack(alignment: .leading, spacing: .spaceL) {
            if let person = highlight.person {
                protagonist(person)
            } else if let tally = highlight.tally {
                TodayHighlightScore(tally: tally, large: true)
            }
            Text(verbatim: highlight.title)
                .font(.title2.weight(.bold))
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
            if highlight.person != nil, let tally = highlight.tally {
                TodayHighlightScore(tally: tally, large: false)
            }
            if highlight.person == nil {
                Text(verbatim: today.highlightPlace(highlight) ?? highlight.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .opacity(.opacityStrong)
            }
            weight
        }
    }

    private func protagonist(_ person: PersonCard) -> some View {
        VStack(spacing: .spaceS) {
            PersonPortrait(
                slug: person.slug, name: person.name, party: person.party, size: .badgeXL * 2
            )
            .overlay { Circle().strokeBorder(.white, lineWidth: .space2XS) }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            Text(verbatim: person.name)
                .font(.title.weight(.heavy))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(spacing: .spaceS) {
                PartyMark(person.party)
                if let place = today.highlightPlace(highlight) {
                    Text(verbatim: place)
                        .font(.subheadline.weight(.semibold))
                        .opacity(.opacityStrong)
                }
            }
            Text(verbatim: highlight.subtitle)
                .font(.footnote)
                .opacity(.opacityStrong)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var weight: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: "\(highlight.weight)")
                    .font(.scoreboardHero)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(highlight.weight)))
                Text("weight of 100")
                    .font(.subheadline.weight(.semibold))
                    .opacity(.opacityStrong)
                Spacer(minLength: 0)
            }
            ProgressBar(value: appeared ? Double(highlight.weight) / 100 : 0, color: .white)
                .animation(reduceMotion ? nil : .smooth(duration: 1), value: appeared)
            if let text = highlight.coverage.uncertainty {
                Label {
                    Text(verbatim: text)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.footnote.weight(.medium))
            }
            Text(verbatim: parts)
                .font(.caption.weight(.semibold))
                .opacity(.opacityStrong)
        }
    }

    private var parts: String {
        if let repercussion = highlight.repercussion, !highlight.signals.isTest {
            return String(
                appLocalized: "Repercussion \(repercussion) · impact \(highlight.impact)")
        }
        return String(
            appLocalized: "Impact \(highlight.impact) · repercussion not measured")
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
            FiscalDesignSystem.TallyBar(
                segments: [
                    .init(id: "yes", value: Double(tally.yes), color: .white),
                    .init(id: "no", value: Double(tally.no), color: .white.opacity(.opacitySoft)),
                    .init(
                        id: "others", value: Double(tally.others),
                        color: .white.opacity(.opacityTint)),
                ], height: .spaceXS)
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
