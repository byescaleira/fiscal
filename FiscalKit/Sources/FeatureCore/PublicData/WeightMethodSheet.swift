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
    private let method: WeightMethod

    public init(method: WeightMethod) {
        self.method = method
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spaceL) {
                    WeightFormulaCard(method: method)
                    WeightLevelsCard()
                    WeightPartCard(
                        title: "Repercussion", symbol: "megaphone.fill", color: .retroDenim,
                        text: method.repercussion, parts: method.parts
                    ) {
                        WeightSignalsList(signals: method.signals)
                    }
                    WeightPartCard(
                        title: "Impact", symbol: "person.3.fill", color: .retroTeal,
                        text: method.impact, parts: method.impactParts
                    ) {
                        EmptyView()
                    }
                    WeightNotesCard(method: method)
                    WeightDetailsCard(method: method)
                }
                .padding(.horizontal, .spaceL)
                .padding(.bottom, .space2XL)
            }
            .background(.sheetBackground)
            .navigationTitle("How We Measure")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .foregroundStyle(Color.primary)
        .tint(Color.primary)
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
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
        .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
    }
}

private struct WeightFormulaCard: View {
    let method: WeightMethod

    var body: some View {
        WeightCard {
            Text("What comes first")
                .font(.titleMedium)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: method.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                .font(.scoreboardNumber)
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

private struct WeightLevelsCard: View {
    var body: some View {
        WeightCard {
            Label("Relevance", systemImage: "chart.bar.fill")
                .font(.rowTitle)
            HStack(spacing: .spaceHairline) {
                ForEach(Relevance.allCases.reversed(), id: \.self) { level in
                    VStack(alignment: .leading, spacing: .spaceXS) {
                        Capsule()
                            .fill(Color.retroTeal.opacity(opacity(level)))
                            .frame(height: .spaceS)
                        Text(verbatim: level.shortTitle)
                            .font(.subheadline.weight(.bold))
                        Text(verbatim: level.range)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            Text(
                "On screen the weight shows as a level; the number stays in the detail. The level orders, it never says whether a measure is good or bad."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func opacity(_ level: Relevance) -> Double {
        switch level {
        case .low: .opacitySoft
        case .medium: .opacityStrong - .opacityTint
        case .high: 1
        }
    }
}

private struct WeightPartCard<Extra: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color
    let text: String
    let parts: [WeightMethod.Part]
    let extra: Extra

    init(
        title: LocalizedStringKey, symbol: String, color: Color, text: String,
        parts: [WeightMethod.Part], @ViewBuilder extra: () -> Extra
    ) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.text = text
        self.parts = parts
        self.extra = extra()
    }

    var body: some View {
        WeightCard {
            Label(title, systemImage: symbol)
                .font(.rowTitle)
                .foregroundStyle(color)
            Text(verbatim: text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: .spaceS) {
                ForEach(parts) { part in
                    HStack(spacing: .spaceM) {
                        Text(verbatim: part.label)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ProgressBar(value: part.share, color: color)
                            .frame(maxWidth: .infinity)
                        Text(verbatim: PublicFormat.percent(part.share))
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            extra
        }
    }
}

private struct WeightSignalsList: View {
    let signals: [WeightMethod.Signal]

    var body: some View {
        if !signals.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: .spaceS) {
                Text("Sources")
                    .font(.caption.weight(.heavy))
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
