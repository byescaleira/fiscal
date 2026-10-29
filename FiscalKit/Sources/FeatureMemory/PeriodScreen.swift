import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct PeriodScreen: View {
    @Environment(PeriodModel.self) private var model

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: model.phase, isEmpty: model.period == nil, retry: { await model.load() }
        ) {
            if let period = model.period {
                AdaptiveList {
                    PeriodHeroSection(period: period)
                    PresidentsSection(period: period)
                    MilestonesSection(period: period)
                    if !period.indicators.isEmpty {
                        IndicatorsSection(period: period)
                    }
                    RecordSection(
                        title: "Recorded advances", symbol: "plus.circle", items: period.advances)
                    RecordSection(
                        title: "Recorded criticism", symbol: "minus.circle", items: period.critiques
                    )
                    ForEach(period.divergences) { DivergenceSection(divergence: $0) }
                    NeighborsSection()
                    PeriodSourcesSection(period: period)
                }
            }
        } empty: {
            EmptyStateView(
                title: "Period not found",
                description: "The timeline isn't published by Fiscal yet."
            ) {
                IconRow("Milestones", symbol: "flag", color: .retroDenim)
                IconRow("Official indicators", symbol: "chart.line.uptrend.xyaxis", color: .retroTeal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.plainBackground)
        }
        .emphasisTitle(Text(verbatim: model.period?.name ?? ""))
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

private struct PeriodHeroSection: View {
    @Environment(PeriodModel.self) private var model
    let period: PoliticalPeriod

    var body: some View {
        Section {
        } header: {
            VStack(spacing: .spaceS) {
                Chip(
                    period.eraTitle, color: PeriodPalette.color(for: period.era),
                    shape: .capsule)
                Text(verbatim: model.years)
                    .font(.amountHero)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(verbatim: period.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .textCase(nil)
            .padding(.vertical, .spaceL)
        }
    }
}

private struct PresidentsSection: View {
    @Environment(PeriodModel.self) private var model
    let period: PoliticalPeriod

    var body: some View {
        Section {
            ForEach(period.presidents) { president in
                HStack(alignment: .top, spacing: .spaceM) {
                    PersonPortrait(
                        slug: president.portraitSlug, name: president.name, party: "",
                        size: .badgeL)
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text(verbatim: president.name).font(.rowTitle)
                        Text(verbatim: model.term(president))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(verbatim: president.how)
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(verbatim: model.presidentsLine).sectionTitle()
        } footer: {
            Text(verbatim: period.presidentsSourceLine)
        }
    }
}

private struct MilestonesSection: View {
    let period: PoliticalPeriod

    var body: some View {
        Section {
            ForEach(Array(period.milestones.enumerated()), id: \.element.id) { index, milestone in
                MilestoneRow(milestone: milestone, isLast: index == period.milestones.count - 1)
            }
        } header: {
            Text("Milestones").sectionTitle()
        }
    }
}

private struct MilestoneRow: View {
    let milestone: PeriodMilestone
    let isLast: Bool

    var body: some View {
        TimelineRow(isLast: isLast) {
            SymbolBadge(milestone.symbol, color: .retroDenim, size: .badgeS)
                .accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: milestone.dateLine)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                Text(verbatim: milestone.title).font(.rowTitle)
                Text(verbatim: milestone.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                SourceLinks(refs: milestone.sources)
            }
            .padding(.bottom, .spaceXS)
        }
    }
}

struct SourceLinks: View {
    let refs: [HistoryRef]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            ForEach(refs) { ref in
                if let url = ref.url {
                    Link(destination: url) {
                        Label {
                            Text(verbatim: ref.name).multilineTextAlignment(.leading)
                        } icon: {
                            Image(systemName: "link")
                        }
                    }
                    .font(.caption)
                    .accessibilityHint(Text("Opens the source"))
                } else {
                    Label {
                        Text(verbatim: ref.name)
                    } icon: {
                        Image(systemName: "book.closed")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .labelStyle(SourceLabelStyle())
    }
}

private struct SourceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

private struct IndicatorsSection: View {
    @Environment(PeriodModel.self) private var model
    let period: PoliticalPeriod

    var body: some View {
        Section {
            ForEach(Array(period.indicators.enumerated()), id: \.element.id) { index, indicator in
                VStack(alignment: .leading, spacing: .spaceS) {
                    Text(verbatim: indicator.name).font(.rowTitle)
                    Text(verbatim: model.summary(indicator))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    PeriodIndicatorChart(
                        indicator: indicator, color: ChartPalette.color(at: index),
                        logScale: model.usesLogScale(indicator))
                    Text(verbatim: model.footnote(indicator))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, .spaceXS)
            }
        } header: {
            Text("Official indicators").sectionTitle()
        } footer: {
            Text("Full years of the period only. Values as published, without causes attributed.")
        }
    }
}

private struct RecordSection: View {
    let title: LocalizedStringKey
    let symbol: String
    let items: [HistoryItem]

    var body: some View {
        if !items.isEmpty {
            Section {
                ForEach(items, id: \.text) { item in
                    HStack(alignment: .top, spacing: .spaceM) {
                        Image(systemName: symbol)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(verbatim: item.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            SourceLinks(refs: item.sources)
                        }
                    }
                }
            } header: {
                Text(title).sectionTitle()
            } footer: {
                Text("What the cited sources record, in their order. Fiscal doesn't rank or judge.")
            }
        }
    }
}

private struct DivergenceSection: View {
    let divergence: PeriodDivergence

    var body: some View {
        Section {
            ForEach(Array(divergence.positions.enumerated()), id: \.offset) { index, position in
                HStack(alignment: .top, spacing: .spaceM) {
                    Text(verbatim: divergence.positionText(index))
                        .font(.chipLabel)
                        .foregroundStyle(.secondary)
                        .frame(width: .badgeS, height: .badgeS)
                        .background(.subtleFill, in: .circle)
                        .accessibilityLabel(Text("Position \(index + 1)"))
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: position.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        SourceLinks(refs: position.sources)
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("There is disagreement").sectionTitle()
                Text(verbatim: divergence.topic)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
        } footer: {
            Text(
                "Historians differ on this point. The positions appear side by side, each with its source."
            )
        }
    }
}

private struct NeighborsSection: View {
    @Environment(PeriodModel.self) private var model

    var body: some View {
        if model.previous != nil || model.next != nil {
            Section {
                if let previous = model.previous {
                    RouteLink(.period(id: previous.id)) {
                        Label {
                            Text(verbatim: previous.name)
                        } icon: {
                            Image(systemName: "arrow.backward")
                        }
                    }
                }
                if let next = model.next {
                    RouteLink(.period(id: next.id)) {
                        Label {
                            Text(verbatim: next.name)
                        } icon: {
                            Image(systemName: "arrow.forward")
                        }
                    }
                }
            } header: {
                Text("Before and after").sectionTitle()
            }
        }
    }
}

private struct PeriodSourcesSection: View {
    let period: PoliticalPeriod

    var body: some View {
        Section {
            SourceLinks(refs: period.sources)
        } header: {
            Text("Sources of this period").sectionTitle()
        }
    }
}
