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
            List {
                Section {
                    Text(verbatim: method.summary)
                    Text(verbatim: method.formula)
                        .font(.headline)
                } header: {
                    Text("Weight").sectionTitle()
                }
                WeightPartsSection(
                    title: "Repercussion", text: method.repercussion, parts: method.parts)
                WeightCoverageSection(method: method)
                WeightSignalsSection(signals: method.signals)
                WeightPartsSection(
                    title: "Impact", text: method.impact, parts: method.impactParts)
                WeightValuesSection(title: "Type", values: method.kinds)
                WeightValuesSection(title: "Reach", values: method.scopes)
                WeightValuesSection(title: "Stage", values: method.stages)
                WeightThemesSection(themes: method.themes)
                Section {
                    Text(verbatim: method.decay.text)
                } header: {
                    Text("Highlight of the Moment").sectionTitle()
                }
                Section {
                    Text(verbatim: method.alertRule.summary)
                } header: {
                    Text("Lock Screen Alert").sectionTitle()
                }
                WeightListSection(title: "Rules", lines: method.rules)
                WeightListSection(title: "Limits", lines: method.limits)
            }
            .scrollContentBackground(.hidden)
            .background(.sheetBackground)
            .navigationTitle("How We Measure")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color.primary)
                }
            }
        }
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
    }
}

private struct WeightPartsSection: View {
    let title: LocalizedStringKey
    let text: String
    let parts: [WeightMethod.Part]

    var body: some View {
        Section {
            Text(verbatim: text).font(.subheadline)
            ForEach(parts) { part in
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack {
                        Text(verbatim: part.label).font(.subheadline)
                        Spacer(minLength: .spaceS)
                        Text(verbatim: PublicFormat.percent(part.share))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    ProgressBar(value: part.share, color: .retroDenim)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(title).sectionTitle()
        }
    }
}

private struct WeightCoverageSection: View {
    let method: WeightMethod

    var body: some View {
        Section {
            Text(verbatim: method.renormalization ?? Self.fallback)
                .font(.subheadline)
            ForEach(method.confidence ?? []) { level in
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: level.label).font(.rowTitle)
                    Text(verbatim: level.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Missing Signals").sectionTitle()
        }
    }

    private static var fallback: String {
        String(
            appLocalized:
                "A missing signal doesn't count as zero: repercussion is the weighted average of only the signals measured in this load. With no signal measured, the weight is the impact alone, and the app says so."
        )
    }
}

private struct WeightSignalsSection: View {
    let signals: [WeightMethod.Signal]

    var body: some View {
        Section {
            ForEach(signals) { signal in
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack {
                        Text(verbatim: signal.name).font(.rowTitle)
                        Spacer(minLength: .spaceS)
                        if !signal.isMeasured {
                            Chip("Not measured", color: .secondary)
                        }
                    }
                    Text(verbatim: "\(signal.measures) · \(signal.window)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let note = signal.note {
                        Text(verbatim: note).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Sources").sectionTitle()
        }
    }
}

private struct WeightValuesSection: View {
    let title: LocalizedStringKey
    let values: [WeightMethod.Value]

    var body: some View {
        Section {
            ForEach(values) { value in
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: value.label).font(.subheadline)
                        Spacer(minLength: .spaceS)
                        Text(verbatim: PublicFormat.percent(value.value))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    if let note = value.note {
                        Text(verbatim: note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(title).sectionTitle()
        }
    }
}

private struct WeightThemesSection: View {
    let themes: [WeightMethod.Reach]

    var body: some View {
        Section {
            ForEach(themes) { reach in
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: Theme(rawValue: reach.key)?.title ?? reach.key)
                            .font(.subheadline)
                        Spacer(minLength: .spaceS)
                        Text(verbatim: PublicFormat.percent(reach.reach))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(verbatim: reach.reason).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Theme Reach").sectionTitle()
        } footer: {
            Text("Each theme counts only by how many people it reaches, never by political side.")
        }
    }
}

private struct WeightListSection: View {
    let title: LocalizedStringKey
    let lines: [String]

    var body: some View {
        if !lines.isEmpty {
            Section {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line).font(.subheadline)
                }
            } header: {
                Text(title).sectionTitle()
            }
        }
    }
}
