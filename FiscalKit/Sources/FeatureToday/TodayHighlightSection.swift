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
                    TodayHighlightHero(highlight: lead)
                    if !today.highlightOthers.isEmpty {
                        TodayHighlightList(items: today.highlightOthers)
                    }
                    Text("Weight orders what is happening; it never rates it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, .spaceXS)
                }
            }
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
                    if let short = highlight.coverage.uncertaintyShort {
                        Text(verbatim: short)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .contextMenu {
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(today.shareSubject(for: highlight)), in: section)
            }
        }
    }
}
