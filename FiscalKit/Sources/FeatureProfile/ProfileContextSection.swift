import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileContextSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.hasContext, let item = profile.selectedContext {
            Section {
                ProfileContextSummary(item: item)
                ProfileContextChart(item: item)
                    .id(item.id)
                ForEach(profile.contextItems.filter { $0.id != item.id }) { other in
                    ProfileContextRow(item: other)
                }
            } header: {
                AdaptiveStack(spacing: .spaceS) {
                    Text("Before and During the Term").sectionTitle()
                    Spacer(minLength: 0)
                    ProfileContextMenu()
                }
                .textCase(nil)
            } footer: {
                ProfileFooter(lines: [profile.contextFootnote, profile.contextSourceText])
            }
        }
    }
}

private struct ProfileContextMenu: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        Menu {
            Picker(
                "Indicator",
                selection: Binding(
                    get: { profile.selectedContext?.id },
                    set: { profile.selectedIndicatorID = $0 })
            ) {
                ForEach(profile.contextItems) { item in
                    Label(item.name, systemImage: IndicatorFormat.symbol(id: item.id))
                        .tag(Optional(item.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Indicator", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .accessibilityValue(Text(verbatim: profile.selectedContext?.name ?? ""))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .sensoryFeedback(.selection, trigger: profile.selectedIndicatorID)
    }
}

private struct ProfileContextSummary: View {
    @Environment(ProfileModel.self) private var profile
    let item: PersonContext.Item

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Label(item.name, systemImage: IndicatorFormat.symbol(id: item.id))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(verbatim: profile.contextSentence(item))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: .spaceXS) {
                Chip(
                    String(appLocalized: "Before · \(IndicatorFormat.change(item.changeBefore))"),
                    color: .secondary)
                Chip(
                    String(
                        appLocalized:
                            "During the term · \(IndicatorFormat.change(item.changeDuring))"),
                    color: ChartPalette.color(at: 0))
            }
            .textCase(.uppercase)
            Text(verbatim: profile.contextAreaLine(item))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileContextChart: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartHeight
    @State private var revealed = false
    @State private var scrubbed: Date?
    let item: PersonContext.Item

    private var points: [ProfileModel.ContextPoint] { profile.contextPoints(item) }

    private var domain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let low = values.min(), let high = values.max(), high > low else { return 0...1 }
        let pad = (high - low) / 10
        return (low - pad)...(high + pad)
    }

    private var selected: ProfileModel.ContextPoint? {
        guard let scrubbed else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(scrubbed)) < abs($1.date.timeIntervalSince(scrubbed))
        }
    }

    var body: some View {
        Chart {
            if let first = points.first?.date, let start = profile.mandateStartDate,
                let last = points.last?.date
            {
                RectangleMark(xStart: .value("Start", first), xEnd: .value("Took office", start))
                    .foregroundStyle(Color.secondary.opacity(.opacityFill))
                    .annotation(position: .overlay, alignment: .topLeading, spacing: .space2XS) {
                        BandLabel(text: String(appLocalized: "Before"), color: .secondary)
                    }
                RectangleMark(xStart: .value("Took office", start), xEnd: .value("Latest", last))
                    .foregroundStyle(ChartPalette.color(at: 0).opacity(.opacityFill))
                    .annotation(position: .overlay, alignment: .topTrailing, spacing: .space2XS) {
                        BandLabel(
                            text: String(appLocalized: "During the term"),
                            color: ChartPalette.color(at: 0))
                    }
                RuleMark(x: .value("Took office", start))
                    .foregroundStyle(.secondary)
                    .lineStyle(.chartAverage)
                    .annotation(
                        position: .bottom, alignment: .center, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        Text(verbatim: profile.mandateStartLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Month", point.date, unit: .month),
                    y: .value("Value", revealed ? point.value : domain.lowerBound),
                    series: .value("Period", point.period.rawValue)
                )
                .foregroundStyle(
                    point.period == .during ? ChartPalette.color(at: 0) : Color.secondary
                )
                .lineStyle(StrokeStyle(lineWidth: .chartLineWidth, lineCap: .round))
                .interpolationMethod(.monotone)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date, unit: .month))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartCallout(
                            title: IndicatorFormat.month(selected.day, calendar: profile.calendar),
                            value: profile.contextValue(selected, item: item)
                        ) {
                            EmptyView()
                        }
                    }
                PointMark(
                    x: .value("Selected", selected.date, unit: .month),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(
                    selected.period == .during ? ChartPalette.color(at: 0) : Color.secondary)
            }
        }
        .chartYScale(domain: domain)
        .chartXSelection(value: $scrubbed)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.year())
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.day)
        .frame(height: height)
        .padding(.vertical, .spaceS)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: item.name))
        .accessibilityValue(Text(verbatim: profile.contextSentence(item)))
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}

private struct BandLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.spaceXS)
    }
}

private struct ProfileContextRow: View {
    @Environment(ProfileModel.self) private var profile
    let item: PersonContext.Item

    var body: some View {
        Button {
            profile.selectedIndicatorID = item.id
        } label: {
            HStack(spacing: .spaceM) {
                Image(systemName: IndicatorFormat.symbol(id: item.id))
                    .font(.icon(.s, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: .badgeM, height: .badgeM)
                    .background(
                        Color.secondary.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: item.name).font(.rowTitle).foregroundStyle(.primary)
                    Text(verbatim: profile.contextAreaLine(item))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .spaceS)
                VStack(alignment: .trailing, spacing: .spaceHairline) {
                    Text(verbatim: IndicatorFormat.change(item.changeDuring))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(
                        verbatim: String(
                            appLocalized: "before \(IndicatorFormat.change(item.changeBefore))")
                    )
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows this indicator in the chart"))
    }
}
