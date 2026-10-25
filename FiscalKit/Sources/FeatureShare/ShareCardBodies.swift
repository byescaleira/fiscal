import FiscalDesignSystem
import SwiftUI

struct ShareBodyView: View {
    let content: ShareCardContent
    let dense: Bool

    var body: some View {
        switch content.body {
        case .person(let metrics): ShareMetricsGrid(metrics: metrics, dense: dense)
        case .vote(let tally): ShareTallyView(tally: tally, dense: dense)
        case .expenses(let spending): ShareSpendingView(spending: spending, dense: dense)
        case .race(let race): ShareRaceView(race: race, dense: dense)
        case .compare(let rows): ShareCompareView(faces: content.faces, rows: rows, dense: dense)
        case .representatives(let groups): ShareGroupsView(groups: groups, dense: dense)
        }
    }
}

private struct ShareMetricsGrid: View {
    let metrics: [ShareMetric]
    let dense: Bool

    var body: some View {
        Grid(horizontalSpacing: .spaceS, verticalSpacing: .spaceS) {
            ForEach(Array(stride(from: 0, to: metrics.count, by: 2)), id: \.self) { start in
                GridRow {
                    ForEach(metrics[start..<min(start + 2, metrics.count)]) { metric in
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(verbatim: metric.label.uppercased())
                                .font(.shareLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(.shareTextShrink)
                            Text(verbatim: metric.value)
                                .font(dense ? .shareName : .shareNumber)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(.shareTextShrink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.spaceS)
                        .background(.subtleFill, in: .rect(cornerRadius: .radiusS))
                    }
                }
            }
        }
    }
}

private struct ShareTallyView: View {
    let tally: ShareTally
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let official = tally.official, !dense {
                Text(verbatim: official)
                    .font(.shareBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Text(verbatim: tally.proposition)
                .font(.shareLabel)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .lastTextBaseline) {
                ShareTallyColumn(
                    title: "YES", value: tally.yes, symbol: "checkmark", color: .positive,
                    dense: dense)
                Spacer(minLength: .spaceS)
                ShareTallyColumn(
                    title: "NO", value: tally.no, symbol: "xmark", color: .negative, dense: dense)
                Spacer(minLength: .spaceS)
                ShareTallyColumn(
                    title: "OTHERS", value: tally.others, symbol: "minus", color: .warning,
                    dense: dense)
            }
            ShareStackedBar(segments: [
                ShareSegment(share: tally.yesShare, color: .positive),
                ShareSegment(share: tally.noShare, color: .negative),
                ShareSegment(share: tally.othersShare, color: .warning),
            ])
            HStack {
                if let result = tally.result {
                    Label(result, systemImage: resultSymbol)
                        .font(.shareLabel)
                        .foregroundStyle(resultColor)
                        .padding(.horizontal, .spaceS)
                        .padding(.vertical, .space2XS)
                        .background(resultColor.opacity(.opacityTint), in: .capsule)
                }
                Spacer(minLength: .zero)
                if let quorum = tally.quorum {
                    Text(verbatim: quorum)
                        .font(.shareLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultSymbol: String {
        switch tally.approved {
        case .some(true): "checkmark.seal.fill"
        case .some(false): "xmark.seal.fill"
        case .none: "info.circle"
        }
    }

    private var resultColor: Color {
        switch tally.approved {
        case .some(true): .positive
        case .some(false): .negative
        case .none: .secondary
        }
    }
}

private struct ShareTallyColumn: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let color: Color
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Label(title, systemImage: symbol)
                .font(.shareLabel)
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(dense ? .shareNumber : .shareHero)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
        }
    }
}

private struct ShareSpendingView: View {
    let spending: ShareSpending
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            VStack(alignment: .leading, spacing: .zero) {
                Text(verbatim: spending.total)
                    .font(dense ? .shareNumber : .shareHero)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                Text(verbatim: "\(spending.caption) · \(spending.receipts)")
                    .font(.shareBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            ForEach(spending.categories) { category in
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: category.name)
                            .font(.shareBody)
                            .lineLimit(1)
                            .minimumScaleFactor(.shareTextShrink)
                        Spacer(minLength: .spaceS)
                        Text(verbatim: category.value)
                            .font(.shareBody.weight(.bold))
                            .monospacedDigit()
                    }
                    if !dense {
                        ShareStackedBar(segments: [
                            ShareSegment(share: category.share, color: .secondary)
                        ])
                    }
                }
            }
        }
    }
}
