import SwiftUI

public struct ChartCallout<Detail: View>: View {
    private let title: String
    private let value: String
    private let detail: Detail

    public init(title: String, value: String, @ViewBuilder detail: () -> Detail) {
        self.title = title
        self.value = value
        self.detail = detail()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            detail
        }
        .lineLimit(1)
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .spaceXS)
        .background(.groupedBackground, in: .rect(cornerRadius: .radiusS))
        .accessibilityElement(children: .combine)
    }
}

extension StrokeStyle {
    public static let chartAverage = StrokeStyle(
        lineWidth: .chartRuleWidth, dash: [.space2XS, .space2XS])
}
