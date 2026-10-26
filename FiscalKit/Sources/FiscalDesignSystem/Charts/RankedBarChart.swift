import Charts
import SwiftUI

public struct RankedBar: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String?
    public let value: Double
    public let valueText: String
    public let details: [String]
    public let color: Color

    public init(
        id: String, title: String, symbol: String? = nil, value: Double, valueText: String,
        details: [String] = [], color: Color
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.value = value
        self.valueText = valueText
        self.details = details
        self.color = color
    }

    var spoken: String { ([valueText] + details).joined(separator: ", ") }
}

public struct RankedBarChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var labelRoom: CGFloat = .chartRowLabelRoom
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = .chartRowBarHeight
    @ScaledMetric(relativeTo: .caption) private var valueRoom: CGFloat = .chartValueRoom
    @State private var revealed = false
    @State private var picked: String?
    @State private var width: CGFloat = 0
    private let title: String
    private let bars: [RankedBar]
    private let selection: Binding<String?>?

    public init(_ title: String, bars: [RankedBar], selection: Binding<String?>? = nil) {
        self.title = title
        self.bars = bars
        self.selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            if dynamicTypeSize.isAccessibilitySize {
                RankedBarList(bars: bars, current: current, toggle: toggle)
            } else {
                if let focused {
                    RankedBarCallout(bar: focused)
                        .transition(.opacity)
                }
                chart
            }
        }
        .sensoryFeedback(.selection, trigger: current)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var current: String? {
        if let selection { return selection.wrappedValue }
        return picked
    }

    private var focused: RankedBar? {
        bars.first { $0.id == current }
    }

    private var rowHeight: CGFloat { labelRoom + .space2XS + barHeight + .spaceM }

    private var maxValue: Double {
        let top = bars.map(\.value).max() ?? 0
        return top > 0 ? top : 1
    }

    private var chart: some View {
        Chart {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                BarMark(
                    xStart: .value("Start", 0.0),
                    xEnd: .value("Amount", revealed ? bar.value : 0),
                    y: .value("Row", center(of: index)),
                    height: .fixed(barHeight)
                )
                .foregroundStyle(style(for: bar))
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomTrailingRadius: .chartBarCorner, topTrailingRadius: .chartBarCorner)
                )
                .annotation(
                    position: .top, alignment: .leading, spacing: .space2XS,
                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                ) {
                    RankedBarLabel(bar: bar, isSelected: bar.id == current)
                        .frame(width: width > 0 ? width : nil, alignment: .leading)
                }
                .annotation(position: .trailing, alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: bar.valueText)
                        .font(.caption.weight(bar.id == current ? .bold : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .accessibilityLabel(bar.title)
                .accessibilityValue(bar.spoken)
            }
        }
        .chartXScale(domain: 0...maxValue, range: .plotDimension(endPadding: valueRoom))
        .chartYScale(domain: 0...Double(max(bars.count, 1)))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartGesture { proxy in
            SpatialTapGesture().onEnded { tap in
                guard let value = proxy.value(atY: tap.location.y, as: Double.self) else {
                    return
                }
                let index = bars.count - 1 - Int(value.rounded(.down))
                guard bars.indices.contains(index) else { return }
                toggle(bars[index].id)
            }
        }
        .frame(height: rowHeight * CGFloat(max(bars.count, 1)))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
        .accessibilityChartDescriptor(RankedBarDescriptor(title: title, bars: bars))
        .accessibilityActions {
            if selection != nil {
                ForEach(bars) { bar in
                    Button {
                        toggle(bar.id)
                    } label: {
                        Text(verbatim: bar.title)
                    }
                }
            }
        }
    }

    private func center(of index: Int) -> Double {
        let base = Double(bars.count - index - 1)
        return base + Double((.spaceM + barHeight / 2) / rowHeight)
    }

    private func style(for bar: RankedBar) -> AnyShapeStyle {
        guard let current, current != bar.id else { return AnyShapeStyle(bar.color.gradient) }
        return AnyShapeStyle(bar.color.opacity(.opacitySoft))
    }

    private func toggle(_ id: String) {
        let next = current == id ? nil : id
        withAnimation(reduceMotion ? nil : .smooth) {
            if let selection {
                selection.wrappedValue = next
            } else {
                picked = next
            }
        }
    }
}

private struct RankedBarLabel: View {
    let bar: RankedBar
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
            if let symbol = bar.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(bar.color)
                    .accessibilityHidden(true)
            }
            Text(verbatim: bar.title)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
    }
}

private struct RankedBarCallout: View {
    let bar: RankedBar

    var body: some View {
        ChartCallout(title: bar.title, value: bar.valueText, stacked: true) {
            ForEach(bar.details, id: \.self) { detail in
                Text(verbatim: detail)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RankedBarList: View {
    let bars: [RankedBar]
    let current: String?
    let toggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            ForEach(bars) { bar in
                Button {
                    toggle(bar.id)
                } label: {
                    RankedBarListRow(bar: bar, isSelected: bar.id == current)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(bar.id == current ? .isSelected : [])
            }
        }
    }
}

private struct RankedBarListRow: View {
    let bar: RankedBar
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                if let symbol = bar.symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(bar.color)
                        .accessibilityHidden(true)
                }
                Text(verbatim: bar.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(bar.color)
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: bar.valueText)
                .font(.body.weight(.semibold))
                .monospacedDigit()
            ForEach(bar.details, id: \.self) { detail in
                Text(verbatim: detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

private struct RankedBarDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let bars: [RankedBar]

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = Dictionary(
            bars.map { ($0.value, $0.valueText) }, uniquingKeysWith: { first, _ in first })
        let x = AXCategoricalDataAxisDescriptor(title: title, categoryOrder: bars.map(\.title))
        let y = AXNumericDataAxisDescriptor(
            title: title, range: 0...max(bars.map(\.value).max() ?? 0, 0), gridlinePositions: []
        ) { value in
            labels[value] ?? value.formatted(.number.precision(.fractionLength(0)))
        }
        let series = AXDataSeriesDescriptor(
            name: title, isContinuous: false,
            dataPoints: bars.map { bar in
                AXDataPoint(x: bar.title, y: bar.value, label: bar.spoken)
            })
        return AXChartDescriptor(
            title: title, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
