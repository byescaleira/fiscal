import SwiftUI

public struct IconRow: View {
    private let title: Text
    private let detail: Text?
    private let symbol: String
    private let color: Color
    private let value: String?
    private let titleColor: Color

    public init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, symbol: String,
        color: Color, value: String? = nil, titleColor: Color = .primary
    ) {
        self.title = Text(title)
        self.detail = detail.map { Text($0) }
        self.symbol = symbol
        self.color = color
        self.value = value
        self.titleColor = titleColor
    }

    public init(
        verbatim title: String, detail: String? = nil, symbol: String, color: Color,
        value: String? = nil, titleColor: Color = .primary
    ) {
        self.title = Text(verbatim: title)
        self.detail = detail.map { Text(verbatim: $0) }
        self.symbol = symbol
        self.color = color
        self.value = value
        self.titleColor = titleColor
    }

    public var body: some View {
        HStack(spacing: .spaceM) {
            Image(systemName: symbol)
                .font(.icon(.s, weight: .medium))
                .foregroundStyle(color)
                .frame(width: .badgeS + .space2XS, height: .badgeS + .space2XS)
                .background(color.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                title.foregroundStyle(titleColor)
                if let detail {
                    detail.font(.footnote).foregroundStyle(Color.secondary)
                }
            }
            Spacer(minLength: .spaceS)
            if let value {
                Text(value).foregroundStyle(Color.secondary).lineLimit(1)
            }
        }
        .contentShape(.rect)
    }
}
