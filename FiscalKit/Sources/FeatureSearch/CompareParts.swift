import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct CompareHero: View {
    let columns: [CompareTable.Column]

    var body: some View {
        HStack(alignment: .top, spacing: .spaceS) {
            ForEach(columns) { column in
                CompareHeroColumn(column: column)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, .spaceXL)
        .padding(.horizontal, .spaceS)
        .background {
            HStack(spacing: .zero) {
                ForEach(columns) { column in
                    LinearGradient(
                        colors: [column.color, .scoreboard], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .background(Color.scoreboard)
        .clipShape(.rect(cornerRadius: .radiusGroup))
    }
}

private struct CompareHeroColumn: View {
    let column: CompareTable.Column

    var body: some View {
        VStack(spacing: .spaceS) {
            PersonPortrait(
                slug: column.slug, name: column.name, party: column.party, size: .badgeXL
            )
            .overlay { Circle().stroke(.white, lineWidth: .spaceHairline) }
            Text(verbatim: column.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            PartyMark(column.party)
                .overlay { Capsule().stroke(.white.opacity(.opacitySoft)) }
            Text(verbatim: column.detail)
                .font(.caption)
                .multilineTextAlignment(.center)
                .opacity(.opacityStrong)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, .space2XS)
        .accessibilityElement(children: .combine)
    }
}

struct CompareMetricRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false
    let metric: CompareTable.Metric
    let columns: [CompareTable.Column]

    var body: some View {
        VStack(spacing: .spaceS) {
            Text(verbatim: metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: .spaceXS) {
                    ForEach(Array(zip(columns, metric.values)), id: \.0.id) { column, value in
                        LabeledContent {
                            Text(verbatim: value.text).font(.amountRow).monospacedDigit()
                        } label: {
                            Text(verbatim: column.name)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: .spaceL) {
                    ForEach(Array(zip(columns, metric.values).enumerated()), id: \.element.0.id) {
                        index, pair in
                        CompareCell(
                            value: pair.1, color: pair.0.color,
                            alignment: alignment(at: index), isShown: isShown)
                    }
                }
            }
        }
        .padding(.vertical, .spaceXS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: metric.title))
        .accessibilityValue(Text(verbatim: metric.spoken(by: columns)))
        .animation(reduceMotion ? nil : .smooth, value: isShown)
        .onAppear { isShown = true }
    }

    private func alignment(at index: Int) -> HorizontalAlignment {
        guard columns.count == 2 else { return .center }
        return index == 0 ? .leading : .trailing
    }
}

private struct CompareCell: View {
    let value: CompareTable.Value
    let color: Color
    let alignment: HorizontalAlignment
    let isShown: Bool

    var body: some View {
        VStack(alignment: alignment, spacing: .space2XS) {
            Text(verbatim: value.text)
                .font(.amountRow)
                .monospacedDigit()
                .amountLine()
            if let detail = value.detail {
                Text(verbatim: detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let fraction = value.fraction {
                ProgressBar(value: isShown ? fraction : 0, color: color)
                    .environment(
                        \.layoutDirection, alignment == .leading ? .rightToLeft : .leftToRight)
            } else {
                Capsule()
                    .strokeBorder(
                        .tertiary,
                        style: StrokeStyle(lineWidth: .spaceHairline, dash: [.space2XS])
                    )
                    .frame(height: .spaceXS)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }
}

extension CompareTable.Column {
    var color: Color {
        let palette = PartyPalette.of(party: party)
        return usesSecondaryColor ? palette.secondary : palette.primary
    }
}
