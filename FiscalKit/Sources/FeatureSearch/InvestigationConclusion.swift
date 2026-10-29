import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ConclusionSection: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        if let conclusion = board.conclusion {
            Section {
            } header: {
                ReadingPanel(conclusion: conclusion)
                    .textCase(nil)
            }
            if !conclusion.compared.isEmpty {
                Section {
                    ForEach(conclusion.compared, id: \.self) { item in
                        Label(item, systemImage: "arrow.left.arrow.right")
                            .font(.subheadline)
                    }
                } header: {
                    Text("What was compared").sectionTitle()
                }
            }
            if !conclusion.uncertainty.isEmpty {
                Section {
                    ForEach(conclusion.uncertainty, id: \.self) { item in
                        Label {
                            Text(verbatim: item).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "questionmark.circle").foregroundStyle(
                                Color.retroMustard)
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("Uncertainty").sectionTitle()
                } footer: {
                    Text("Fiscal shows what is estimated or missing next to each number.")
                }
            }
            if !conclusion.sources.isEmpty {
                Section {
                    ForEach(conclusion.sources) { source in
                        SourceRow(source: source)
                    }
                } header: {
                    Text("Sources").sectionTitle()
                }
            }
        }
    }
}

private struct ReadingPanel: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let conclusion: InvestigationConclusion

    private var reduceMotion: Bool { systemReduceMotion || liteMode.reducesMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            Label("READING", systemImage: "text.magnifyingglass")
                .font(.chipLabel)
                .foregroundStyle(Color.scoreboardAccent)
            if !conclusion.numbers.isEmpty {
                let layout =
                    dynamicTypeSize.isAccessibilitySize || conclusion.numbers.count > 2
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: .spaceM))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: .spaceL))
                layout {
                    ForEach(conclusion.numbers) { number in
                        VStack(alignment: .leading, spacing: .zero) {
                            Text(verbatim: number.value)
                                .font(.caseNumber)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(.shareTextShrink)
                            Text(verbatim: number.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(.opacityStrong))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if let reading = board.reading {
                VStack(alignment: .leading, spacing: .spaceS) {
                    Text(verbatim: reading.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                    if reading.origin == .model {
                        ExplainerBadge()
                            .environment(\.colorScheme, .dark)
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .smooth, value: reading)
            }
        }
        .foregroundStyle(.white)
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.scoreboard.mix(with: .white, by: .opacityFill), .scoreboard],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: .radiusGroup)
        )
        .padding(.vertical, .spaceS)
    }
}

private struct SourceRow: View {
    let source: Source

    var body: some View {
        let detail = source.updatedAt.map {
            String(appLocalized: "Updated \(PublicFormat.updated($0))")
        }
        if let url = source.url {
            Link(destination: url) {
                IconRow(
                    verbatim: source.name, detail: detail, symbol: "building.columns",
                    color: .retroDenim)
            }
            .foregroundStyle(Color.primary)
        } else {
            IconRow(
                verbatim: source.name, detail: detail, symbol: "building.columns",
                color: .retroDenim)
        }
    }
}
