import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SourcesScreen: View {
    @Environment(SourcesModel.self) private var sources

    var body: some View {
        SettingsPage("Official Sources") {
            SourcesHeroSection()
            if sources.sources.isEmpty {
                Section {
                    if sources.hasLoaded {
                        Text("The list of sources isn't published yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
            } else {
                SourcesListSection()
            }
            SourcesCoverageSection()
        }
        .task { await sources.load() }
    }
}

private struct SourcesHeroSection: View {
    @Environment(SourcesModel.self) private var sources
    @Environment(\.appTint) private var tint

    var body: some View {
        Section {
            EmptyView()
        } header: {
            VStack(spacing: .spaceS) {
                Chip("Public data", color: tint, shape: .capsule).textCase(.uppercase)
                Text(sources.sources.count, format: .number)
                    .font(.amountHero)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(sources.sources.count)))
                Text("official sources, the same for everyone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let updated = sources.updatedText {
                    Text(verbatim: updated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spaceL)
            .textCase(nil)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct SourcesListSection: View {
    @Environment(SourcesModel.self) private var sources
    @Environment(\.appTint) private var tint

    var body: some View {
        Section {
            ForEach(Array(sources.sources.enumerated()), id: \.element.id) { index, source in
                let color = index.isMultiple(of: 2) ? tint : Color.companion
                if let url = source.url {
                    Link(destination: url) {
                        HStack(spacing: .spaceS) {
                            SourceLabel(source: source, color: color)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                } else {
                    SourceLabel(source: source, color: color)
                }
            }
        } header: {
            Text("Where the Data Comes From").sectionTitle()
        } footer: {
            Text(
                "Fiscal shows only what these bodies publish. When a piece of data is missing, you see a dash, never a zero."
            )
        }
    }
}

private struct SourceLabel: View {
    let source: Source
    let color: Color

    var body: some View {
        SettingsLabel(
            verbatim: source.name, detail: source.updatedText, symbol: "building.columns",
            color: color)
    }
}

private struct SourcesCoverageSection: View {
    @Environment(SourcesModel.self) private var sources

    var body: some View {
        if let counts = sources.meta?.counts {
            Section {
                HStack(alignment: .top, spacing: .spaceL) {
                    SourcesCount(value: counts.people, label: "Politicians")
                    SourcesCount(value: counts.places, label: "Places")
                }
                .padding(.vertical, .spaceXS)
            } header: {
                Text("What Fiscal Covers").sectionTitle()
            } footer: {
                Text("The same rule for every politician, of every party.")
            }
        }
    }
}

private struct SourcesCount: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Text(label)
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(verbatim: PublicFormat.number(value))
                .font(.scoreboardNumber)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
