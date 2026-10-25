import SwiftUI

public struct FigureHeader<Detail: View>: View {
    private let title: LocalizedStringKey
    private let value: String
    private let numeric: Double
    private let color: Color
    private let detail: Detail

    public init(
        title: LocalizedStringKey, value: String, numeric: Double, color: Color = .primary,
        @ViewBuilder detail: () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.numeric = numeric
        self.color = color
        self.detail = detail()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(title).sectionTitle().frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: .spaceXS) {
                FigureValue(value, numeric: numeric, color: color)
                detail
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spaceXL)
        }
    }
}

public struct FigureBlock: View {
    private let caption: String
    private let value: String
    private let numeric: Double
    private let color: Color
    private let detail: String?

    public init(
        caption: String, value: String, numeric: Double, color: Color = .primary,
        detail: String? = nil
    ) {
        self.caption = caption
        self.value = value
        self.numeric = numeric
        self.color = color
        self.detail = detail
    }

    public var body: some View {
        VStack(spacing: .space2XS) {
            Text(caption).font(.subheadline).foregroundStyle(.secondary)
            FigureValue(value, numeric: numeric, color: color)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spaceS)
    }
}

public struct FigureValue: View {
    private let value: String
    private let numeric: Double
    private let color: Color

    public init(_ value: String, numeric: Double, color: Color = .primary) {
        self.value = value
        self.numeric = numeric
        self.color = color
    }

    public var body: some View {
        Text(value)
            .font(.amountHero)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: numeric))
            .amountLine()
    }
}
