import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct WeightNotesCard: View {
    let method: WeightMethod

    var body: some View {
        WeightCard {
            note(
                "When a Signal Is Missing", symbol: "questionmark.circle.fill",
                text: method.renormalization
                    ?? String(
                        appLocalized:
                            "A missing signal doesn't count as zero: repercussion is the weighted average of only the signals measured in this load. With no signal measured, the weight is the impact alone, and the app says so."
                    ))
            Divider()
            note("Highlight of the Moment", symbol: "sparkles", text: method.decay.text)
            Divider()
            note("Lock Screen Alert", symbol: "bell.badge.fill", text: method.alertRule.summary)
        }
    }

    private func note(_ title: LocalizedStringKey, symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Label(title, systemImage: symbol).font(.rowTitle)
            Text(verbatim: text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WeightDetailsCard: View {
    let method: WeightMethod

    var body: some View {
        WeightCard {
            values("Type", method.kinds)
            values("Reach", method.scopes)
            values("Stage", method.stages)
            themes
            lines("Rules", method.rules)
            lines("Limits", method.limits)
        }
    }

    @ViewBuilder private func values(_ title: LocalizedStringKey, _ values: [WeightMethod.Value])
        -> some View
    {
        if !values.isEmpty {
            group(title) {
                ForEach(values) { value in
                    row(value.label, PublicFormat.percent(value.value), note: value.note)
                }
            }
        }
    }

    @ViewBuilder private var themes: some View {
        if !method.themes.isEmpty {
            group("Theme Reach") {
                ForEach(method.themes) { reach in
                    row(
                        Theme(rawValue: reach.key)?.title ?? reach.key,
                        PublicFormat.percent(reach.reach), note: reach.reason)
                }
            }
        }
    }

    @ViewBuilder private func lines(_ title: LocalizedStringKey, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            group(title) {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func group<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(title)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ label: String, _ value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: label).font(.footnote)
                Spacer(minLength: .spaceS)
                Text(verbatim: value)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            if let note {
                Text(verbatim: note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
