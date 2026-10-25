import Charts
import FiscalDesignSystem
import SwiftUI

struct StateTileMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var scrubbedColumn: Double?
    @State private var scrubbedRow: Double?
    @State private var picked: String?
    let tiles: [StateTile]

    private var focused: StateTile? {
        tiles.first { $0.uf == picked } ?? tiles.max { ($0.cents ?? 0) < ($1.cents ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            if let focused {
                ChartCallout(title: focused.title, value: focused.value) {
                    Text(verbatim: focused.percent)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            chart
                .frame(maxWidth: .chartTileMapWidth)
                .frame(maxWidth: .infinity)
            StateTileScale()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var chart: some View {
        Chart(tiles) { tile in
            let box = TileBox(tile)
            RectangleMark(
                xStart: .value("Column", box.left),
                xEnd: .value("Column", box.right),
                yStart: .value("Row", box.bottom),
                yEnd: .value("Row", box.top)
            )
            .foregroundStyle(style(for: tile))
            .clipShape(.rect(cornerRadius: .radiusS))
            .annotation(position: .overlay) {
                Text(verbatim: tile.code)
                    .font(.caption2.weight(.bold))
                    .monospaced()
                    .foregroundStyle(labelStyle(for: tile))
            }
            .accessibilityLabel(tile.title)
            .accessibilityValue("\(tile.value), \(tile.percent)")
        }
        .chartXScale(domain: 0...Double(StateTile.columns))
        .chartYScale(domain: 0...Double(StateTile.rows))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: $scrubbedColumn)
        .chartYSelection(value: $scrubbedRow)
        .onChange(of: scrubbedColumn) { pick() }
        .onChange(of: scrubbedRow) { pick() }
        .sensoryFeedback(.selection, trigger: picked)
        .aspectRatio(CGFloat(StateTile.columns) / CGFloat(StateTile.rows), contentMode: .fit)
    }

    private func pick() {
        guard let scrubbedColumn, let scrubbedRow else { return }
        let column = Int(scrubbedColumn.rounded(.down))
        let row = StateTile.rows - 1 - Int(scrubbedRow.rounded(.down))
        guard let tile = tiles.first(where: { $0.column == column && $0.row == row }) else {
            return
        }
        picked = tile.uf
    }

    private func style(for tile: StateTile) -> AnyShapeStyle {
        if tile == focused { return AnyShapeStyle(Color.primary) }
        guard tile.cents != nil else { return AnyShapeStyle(Color.secondary.opacity(.opacityFill)) }
        let level = revealed ? tile.intensity : 0
        return AnyShapeStyle(Color.info.opacity(.opacityFill + (1 - .opacityFill) * level))
    }

    private func labelStyle(for tile: StateTile) -> AnyShapeStyle {
        if tile == focused { return AnyShapeStyle(.background) }
        return tile.intensity > .opacityStrong
            ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary)
    }
}

private struct TileBox {
    let left: Double
    let right: Double
    let bottom: Double
    let top: Double

    init(_ tile: StateTile) {
        let inset = Double(CGFloat.chartTileInset)
        let column = Double(tile.column)
        let row = Double(StateTile.rows - tile.row - 1)
        left = column + inset
        right = column + 1 - inset
        bottom = row + inset
        top = row + 1 - inset
    }
}

private struct StateTileScale: View {
    var body: some View {
        HStack(spacing: .spaceS) {
            Text("Less")
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.info.opacity(.opacityFill), Color.info],
                        startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: .barHeight)
            Text("More")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
