import SwiftUI

public struct ChartCallout<Detail: View>: View {
    private let title: String
    private let value: String
    private let stacked: Bool
    private let detail: Detail

    public init(
        title: String, value: String, stacked: Bool = false, @ViewBuilder detail: () -> Detail
    ) {
        self.title = title
        self.value = value
        self.stacked = stacked
        self.detail = detail()
    }

    public var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: .space2XS) {
                    titleText
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                        valueText
                        detail
                    }
                    .lineLimit(1)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    titleText
                    valueText
                    detail
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .spaceXS)
        .background(.groupedBackground, in: .rect(cornerRadius: .radiusS))
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var valueText: some View {
        Text(verbatim: value)
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.primary)
    }
}

extension StrokeStyle {
    public static let chartAverage = StrokeStyle(
        lineWidth: .chartRuleWidth, dash: [.space2XS, .space2XS])
}
