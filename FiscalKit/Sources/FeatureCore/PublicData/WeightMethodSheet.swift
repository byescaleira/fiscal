import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct WeightMethodButton: View {
    @State private var isPresented = false
    private let method: WeightMethod?

    public init(method: WeightMethod?) {
        self.method = method
    }

    public var body: some View {
        if let method {
            Button {
                isPresented = true
            } label: {
                Label("How We Measure", systemImage: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.borderless)
            .accessibilityHint(Text("Explains how repercussion and impact are calculated"))
            .sheet(isPresented: $isPresented) {
                WeightMethodSheet(method: method)
            }
        }
    }
}

public struct WeightChips: View {
    private let repercussion: Int?
    private let impact: Int
    private let isTest: Bool
    private let coverage: WeightCoverage?

    public init(
        repercussion: Int?, impact: Int, isTest: Bool, coverage: WeightCoverage? = nil
    ) {
        self.repercussion = repercussion
        self.impact = impact
        self.isTest = isTest
        self.coverage = coverage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            FlowLayout(spacing: .spaceXS) {
                if let repercussion, !isTest {
                    Chip("Repercussion \(repercussion)", color: .retroDenim)
                } else {
                    Chip("Repercussion not measured", color: .secondary)
                }
                Chip("Impact \(impact)", color: .retroTeal)
                if isTest {
                    Chip("Test data", color: .retroMustard)
                }
            }
            if let text = coverage?.uncertainty {
                WeightUncertaintyLine(text: text)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct WeightUncertaintyLine: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

public struct WeightMethodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    private let method: WeightMethod

    public init(method: WeightMethod) {
        self.method = method
    }

    public var body: some View {
        let count = 6
        let isLast = index == count - 1
        GuideSheet(
            index: index, count: count, back: index > 0 ? { index -= 1 } : nil,
            primary: GuideAction(isLast ? "Done" : "Continue") {
                if isLast { dismiss() } else { index += 1 }
            }
        ) {
            page
        }
    }

    @ViewBuilder private var page: some View {
        switch index {
        case 0:
            GuidePage(
                title: "How We Measure",
                message: "Repercussion and impact add up to a weight from 0 to 100."
            ) {
                EmptyView()
            } content: {
                WeightFormulaCard(method: method)
            }
        case 1:
            GuidePage(
                title: "Relevance",
                message: "On screen the weight shows as a level; the number stays in the detail."
            ) {
                EmptyView()
            } content: {
                GuideValueList(
                    Relevance.allCases.reversed().map {
                        GuideValue($0.shortTitle, value: $0.range, color: .retroTeal)
                    })
                Text("The level orders, it never says whether a measure is good or bad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case 2:
            GuidePage(verbatim: String(appLocalized: "Repercussion"), message: method.repercussion)
            {
                EmptyView()
            } content: {
                WeightScroll {
                    WeightPartChart(color: .retroDenim, parts: method.parts)
                    WeightSignalsList(signals: method.signals)
                }
            }
        case 3:
            GuidePage(verbatim: String(appLocalized: "Impact"), message: method.impact) {
                EmptyView()
            } content: {
                WeightScroll {
                    WeightPartChart(color: .retroTeal, parts: method.impactParts)
                }
            }
        case 4:
            GuidePage(
                title: "Good to Know",
                message:
                    "What happens when a signal is missing, and how highlights and alerts work."
            ) {
                EmptyView()
            } content: {
                WeightScroll { WeightNotesCard(method: method) }
            }
        default:
            GuidePage(
                title: "Technical Details",
                message: "The shares, rules and limits behind each weight, as published."
            ) {
                EmptyView()
            } content: {
                WeightScroll { WeightDetailsCard(method: method) }
            }
        }
    }
}

struct WeightCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            content
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.sheetCard, in: .rect(cornerRadius: .radiusM))
    }
}

private struct WeightScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceL) {
                content
            }
            .multilineTextAlignment(.leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .guideScrollMax)
    }
}

private struct WeightFormulaCard: View {
    let method: WeightMethod

    var body: some View {
        WeightCard {
            Text("What comes first")
                .font(.rowTitle)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: method.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: .spaceS) { terms }
                VStack(alignment: .leading, spacing: .spaceS) { terms }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: method.formula))
        }
    }

    @ViewBuilder private var terms: some View {
        WeightTerm(
            title: "Repercussion", value: share(0), symbol: "megaphone.fill",
            color: .retroDenim)
        Image(systemName: "plus").font(.headline).foregroundStyle(.secondary)
        WeightTerm(
            title: "Impact", value: share(1), symbol: "person.3.fill",
            color: .retroTeal)
        Image(systemName: "equal").font(.headline).foregroundStyle(.secondary)
        WeightTerm(title: "Weight", value: "0–100", symbol: "scalemass.fill", color: .primary)
    }

    private func share(_ index: Int) -> String {
        let shares = method.formula.matches(of: /\d+%/).map { String($0.output) }
        return shares.indices.contains(index) ? shares[index] : "—"
    }
}

private struct WeightTerm: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Image(systemName: symbol)
                .font(.icon(.s, weight: .semibold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(.scoreboardTitle)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
    }
}

private struct WeightPartChart: View {
    let color: Color
    let parts: [WeightMethod.Part]

    var body: some View {
        WeightCard {
            RankedBarChart(
                String(appLocalized: "Weight"),
                bars: parts.map { part in
                    RankedBar(
                        id: part.id, title: part.label, value: part.share,
                        valueText: PublicFormat.percent(part.share), color: color)
                })
        }
    }
}

private struct WeightSignalsList: View {
    let signals: [WeightMethod.Signal]

    var body: some View {
        if !signals.isEmpty {
            WeightCard {
                Text("Sources")
                    .font(.chipLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                ForEach(signals) { signal in
                    HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                        StatusCircle(
                            signal.isMeasured
                                ? String(appLocalized: "Measured")
                                : String(appLocalized: "Not measured"),
                            symbol: signal.isMeasured ? "checkmark" : "minus",
                            color: signal.isMeasured ? .positive : .secondary)
                        VStack(alignment: .leading, spacing: .spaceHairline) {
                            Text(verbatim: signal.name).font(.subheadline.weight(.semibold))
                            Text(verbatim: "\(signal.measures) · \(signal.window)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
