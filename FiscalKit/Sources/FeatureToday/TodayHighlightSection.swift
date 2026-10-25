import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayHighlightSection: View {
    @Environment(TodayModel.self) private var today

    var body: some View {
        if let lead = today.highlightLead {
            TodaySection("Highlight of the Moment", source: today.highlightSource) {
                VStack(alignment: .leading, spacing: .spaceM) {
                    TodayHighlightLead(highlight: lead)
                    if !today.highlightOthers.isEmpty {
                        TodayHighlightList(items: today.highlightOthers)
                    }
                    HStack {
                        Text("Weight orders what is happening; it never rates it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: .spaceS)
                        WeightMethodButton(method: today.highlightMethod)
                    }
                    .padding(.horizontal, .spaceXS)
                }
            }
        }
    }
}

private struct TodayHighlightLead: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false
    let highlight: Highlight

    var body: some View {
        Button {
            if let route = today.route(for: highlight) { open(route, in: section) }
        } label: {
            VStack(alignment: .leading, spacing: .spaceM) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: today.highlightKicker(highlight).uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: "\(highlight.weight)")
                        .font(.scoreboardNumber)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(highlight.weight)))
                }
                Text(verbatim: highlight.title)
                    .font(.titleMedium)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressBar(value: filled ? Double(highlight.weight) / 100 : 0, color: .retroTeal)
                    .animation(reduceMotion ? nil : .smooth(duration: 1), value: filled)
                    .onAppear { filled = true }
                TodayHighlightWho(highlight: highlight)
                WeightChips(
                    repercussion: highlight.repercussion, impact: highlight.impact,
                    isTest: highlight.signals.isTest)
            }
            .padding(.spaceInset)
            .todayCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(today.route(for: highlight) == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: today.highlightAccessibility(highlight)))
        .accessibilityAddTraits(.isButton)
    }
}

private struct TodayHighlightWho: View {
    let highlight: Highlight

    var body: some View {
        if let person = highlight.person {
            HStack(spacing: .spaceM) {
                PersonPortrait(
                    slug: person.slug, name: person.name, party: person.party, size: .badgeM)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: person.name).font(.rowTitle)
                    Text(verbatim: highlight.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: .spaceS)
                PartyMark(person.party)
            }
        } else {
            Text(verbatim: highlight.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TodayHighlightList: View {
    let items: [Highlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, .spaceL) }
                TodayHighlightRow(highlight: item)
            }
        }
        .todayCard()
    }
}

private struct TodayHighlightRow: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let highlight: Highlight

    var body: some View {
        Button {
            if let route = today.route(for: highlight) { open(route, in: section) }
        } label: {
            HStack(alignment: .top, spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: today.highlightKicker(highlight).uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(verbatim: highlight.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(verbatim: highlight.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "\(highlight.weight)")
                    .font(.amountRow)
                    .monospacedDigit()
            }
            .padding(.spaceL)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(today.route(for: highlight) == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: today.highlightAccessibility(highlight)))
        .accessibilityAddTraits(.isButton)
    }
}
