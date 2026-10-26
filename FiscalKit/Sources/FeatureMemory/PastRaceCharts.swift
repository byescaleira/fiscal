import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct CandidateBarsChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = .badgeL
    @State private var revealed = false
    @State private var scrubbed: String?
    let bars: [PastRoundBreakdown.Bar]

    private var focused: PastRoundBreakdown.Bar? {
        bars.first { $0.label == scrubbed } ?? bars.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            if let focused {
                ChartCallout(title: focused.label, value: MemoryText.percent(focused.share)) {
                    Text(verbatim: MemoryText.votes(focused.votes))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Chart(bars) { bar in
                BarMark(
                    x: .value("Votes", revealed ? bar.votes : 0),
                    y: .value("Candidate", bar.label),
                    height: .fixed(.barHeight * 2)
                )
                .foregroundStyle(bar.color.gradient)
                .opacity(scrubbed == nil || bar.label == scrubbed ? 1 : .opacitySoft)
                .clipShape(.capsule)
                .annotation(position: .trailing, spacing: .spaceXS) {
                    HStack(spacing: .space2XS) {
                        if bar.elected {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.retroTeal)
                        }
                        Text(verbatim: MemoryText.shortPercent(bar.share))
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.bold))
                }
                .accessibilityLabel(bar.label)
                .accessibilityValue(
                    "\(MemoryText.percent(bar.share)), \(MemoryText.votes(bar.votes))")
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .chartXScale(range: .plotDimension(endPadding: .space2XL * 2))
            .chartYSelection(value: $scrubbed)
            .sensoryFeedback(.selection, trigger: scrubbed)
            .frame(height: rowHeight * CGFloat(max(bars.count, 1)))
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}

struct WinnerTileMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var scrubbedColumn: Double?
    @State private var scrubbedRow: Double?
    @State private var picked: String?
    let breakdown: PastRoundBreakdown

    var body: some View {
        let tiles = breakdown.tiles
        let focused = tiles.first { $0.uf == picked }
        VStack(alignment: .leading, spacing: .spaceM) {
            if let focused, let winner = breakdown.candidate(number: focused.winner) {
                ChartCallout(
                    title: focused.name, value: MemoryText.name(winner.ballotName)
                ) {
                    Text(verbatim: MemoryText.shortPercent(focused.share))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Touch a state to see who won there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart(tiles) { tile in
                let box = TileBox(tile)
                RectangleMark(
                    xStart: .value("Column", box.left), xEnd: .value("Column", box.right),
                    yStart: .value("Row", box.bottom), yEnd: .value("Row", box.top)
                )
                .foregroundStyle(tile.color.opacity(revealed ? 1 : .opacityFill))
                .opacity(picked == nil || picked == tile.uf ? 1 : .opacitySoft)
                .clipShape(.rect(cornerRadius: .radiusS))
                .annotation(position: .overlay) {
                    Text(verbatim: tile.code)
                        .font(.caption2.weight(.bold))
                        .monospaced()
                        .foregroundStyle(tile.winner == nil ? Color.secondary : Color.white)
                }
                .accessibilityLabel(tile.name)
                .accessibilityValue(accessibilityValue(tile))
            }
            .chartXScale(domain: 0...Double(MemoryTiles.columns))
            .chartYScale(domain: 0...Double(MemoryTiles.rows))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXSelection(value: $scrubbedColumn)
            .chartYSelection(value: $scrubbedRow)
            .onChange(of: scrubbedColumn) { pick(tiles) }
            .onChange(of: scrubbedRow) { pick(tiles) }
            .sensoryFeedback(.selection, trigger: picked)
            .aspectRatio(
                CGFloat(MemoryTiles.columns) / CGFloat(MemoryTiles.rows), contentMode: .fit
            )
            .frame(maxWidth: .chartTileMapWidth)
            .frame(maxWidth: .infinity)
            FlowLayout(spacing: .spaceS) {
                ForEach(breakdown.legend) { item in
                    HStack(spacing: .space2XS) {
                        Circle().fill(item.color).frame(width: .spaceS, height: .spaceS)
                        Text(verbatim: item.name).fontWeight(.semibold)
                        Text("\(item.states) states").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, .spaceS)
                    .padding(.vertical, .space2XS)
                    .background(.groupedBackground, in: .capsule)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func accessibilityValue(_ tile: PastRoundBreakdown.Tile) -> String {
        guard let winner = breakdown.candidate(number: tile.winner) else {
            return PublicFormat.missing
        }
        return "\(MemoryText.name(winner.ballotName)), \(MemoryText.shortPercent(tile.share))"
    }

    private func pick(_ tiles: [PastRoundBreakdown.Tile]) {
        guard let scrubbedColumn, let scrubbedRow else { return }
        let column = Int(scrubbedColumn.rounded(.down))
        let row = MemoryTiles.rows - 1 - Int(scrubbedRow.rounded(.down))
        picked = tiles.first { $0.column == column && $0.row == row }?.uf ?? picked
    }
}

private struct TileBox {
    let left: Double
    let right: Double
    let bottom: Double
    let top: Double

    init(_ tile: PastRoundBreakdown.Tile) {
        let inset = Double(CGFloat.chartTileInset)
        let column = Double(tile.column)
        let row = Double(MemoryTiles.rows - tile.row - 1)
        left = column + inset
        right = column + 1 - inset
        bottom = row + inset
        top = row + 1 - inset
    }
}

struct TurnoutChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    let slices: [PastRoundBreakdown.Slice]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Chart(slices) { slice in
                BarMark(
                    x: .value("Share", revealed ? slice.fraction : 0),
                    y: .value("Electorate", "all"),
                    height: .fixed(.barHeight * 2)
                )
                .foregroundStyle(by: .value("Kind", slice.title))
            }
            .chartForegroundStyleScale(
                domain: slices.map(\.title), range: slices.map(\.color)
            )
            .chartXScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .clipShape(.capsule)
            .frame(height: .barHeight * 2)
            .accessibilityHidden(true)
            ForEach(slices) { slice in
                HStack(spacing: .spaceS) {
                    Circle().fill(slice.color).frame(width: .spaceS, height: .spaceS)
                    Text(verbatim: slice.title)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: RaceText.votes(slice.value))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(verbatim: PublicFormat.percent(slice.fraction))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(minWidth: .badgeXL, alignment: .trailing)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}
